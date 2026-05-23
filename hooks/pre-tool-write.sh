#!/bin/bash
# Ciel — PreToolUse hook for Write/Edit
# Trigger: PreToolUse on Write|Edit
# Purpose: inject faire-gatekeeper + dispatch gate + pipeline reminders before code write
# Critical files get additional stride-analyzer hint
# Always exits 0 (never blocks), outputs reminders via stderr (reliable channel)
# Dispatch counter: /tmp/ciel_dispatched set by SubagentStart hooks (ciel-researcher/explorer)

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    tip = d.get('tool_input', {})
    print(tip.get('file_path', tip.get('path', '')))
except:
    print('')
" 2>/dev/null || echo "")

[ -z "$FILE_PATH" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"

# === DISPATCH GATE CHECK ===
# /tmp/ciel_dispatched is created by SubagentStart hooks when ciel-researcher/explorer dispatch
DISPATCHED=0
DISPATCH_FLAG="/tmp/ciel_dispatched"
if [ -f "$DISPATCH_FLAG" ]; then
  DISPATCHED=1
fi

# === FILE TRACK COUNT (RELIRE GATE) ===
COUNT=0
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.ciel/tracked-files.json" ]; then
  COUNT=$(CIEL_PATH="$PROJECT_DIR/.ciel/tracked-files.json" python3 -c "
import json, os
try: print(len(json.load(open(os.environ['CIEL_PATH']))))
except: print(0)
" 2>/dev/null || echo "0")
fi

# Build warnings
WARNINGS=""

# Dispatch gate warning (no dispatched agents on non-trivial write)
if [ "$DISPATCHED" -eq 0 ] && [ "$COUNT" -ge 1 ]; then
  WARNINGS="${WARNINGS}[DISPATCH GATE] WARNING: Writing file ${FILE_PATH} without prior agent dispatch (ciel-researcher + ciel-explorer with domain skills). Was this classified as Trivial? If Standard+, dispatch both agents BEFORE writing code."
fi

# RELIRE gate warning
if [ "${COUNT:-0}" -ge 2 ] 2>/dev/null; then
  PIPELINE_WARN=" | CIEL PIPELINE: ${COUNT} file(s) edited. Have researcher+explorer been dispatched with domain skills? If 3+ files: ciel-critic MODE=RELIRE required before merge."
  WARNINGS="${WARNINGS}${PIPELINE_WARN}"
fi

# If only dispatch gate fires, prefix to std err
if [ -n "$WARNINGS" ]; then
  echo "[CIEL PRE-WRITE]" >&2
  echo "$WARNINGS" | while IFS= read -r line; do
    echo "  $line" >&2
  done
fi

# === FAIRE GATE REMINDER ===
# Skip non-code files
if ! echo "$FILE_PATH" | grep -qE '\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql|sh|json|yaml|yml|toml)$'; then
  exit 0
fi

# Check if file is critical path
CRITICAL=false
if echo "$FILE_PATH" | grep -qiE '(auth|Auth|security|Security|Token|Session|Password|Secret)'; then
  CRITICAL=true
fi

if $CRITICAL; then
  echo "  [CIEL] Critical path: invoke faire-gatekeeper, stride-analyzer must have run, test-first (RED)." >&2
else
  echo "  [CIEL] Standard path: invoke faire-gatekeeper (alternatives, idiomatic, quality, removal, test-first)." >&2
fi

exit 0
