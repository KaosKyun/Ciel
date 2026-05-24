#!/bin/bash
# Ciel — PreToolUse hook for Write/Edit
# Trigger: PreToolUse on Write|Edit
# Purpose: BLOCK source code writes until dispatch gate passes (v8 — enforcement)
# Test files and non-code files pass through (always allowed).
# Escape hatch: [CIEL_GATE_BYPASS] anywhere in the tool input bypasses the gate.
# Dispatch tracker: /tmp/ciel_dispatched.* (created by SubagentStart hooks)

INPUT=$(cat 2>/dev/null || echo "{}")

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

# === BYPASS CHECK ===
# [CIEL_GATE_BYPASS] anywhere in the input is an intentional override
if echo "$INPUT" | grep -q '\[CIEL_GATE_BYPASS\]'; then
  echo "[CIEL] Gate bypassed via [CIEL_GATE_BYPASS] — allowing write to $(basename "$FILE_PATH")" >&2
  exit 0
fi

# === FILE CLASSIFICATION ===
# Source code files that require dispatch before editing
IS_SOURCE=0
if echo "$FILE_PATH" | grep -qE '\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte)$'; then
  IS_SOURCE=1
fi

# Test files always pass (test-first RED)
IS_TEST=0
if echo "$FILE_PATH" | grep -qE '\.(test|spec)\.|_test\.|_spec\.|/test/|/tests/|/__tests__/'; then
  IS_TEST=1
fi

# === DISPATCH GATE CHECK ===
# /tmp/ciel_dispatched.* files created by SubagentStart hooks when Ciel agents dispatch
DISPATCHED=0
if ls /tmp/ciel_dispatched.* >/dev/null 2>&1; then
  DISPATCHED=1
fi

# === DISPATCH GATE — BLOCK (v8 enforcement) ===
# Block source code edits when no Ciel agent has been dispatched.
# Skip non-code files (docs, config, JSON, YAML, etc.) — those are safe to edit inline.
# Skip test files — test-first RED means tests must be written before source.
if [ "$IS_SOURCE" -eq 1 ] && [ "$IS_TEST" -eq 0 ] && [ "$DISPATCHED" -eq 0 ]; then
  echo "[CIEL DISPATCH GATE] BLOCKED: Write to $(basename "$FILE_PATH")" >&2
  echo "" >&2
  echo "  No Ciel agent dispatched yet. On Standard/Critical tasks you MUST:" >&2
  echo "  1. Dispatch ciel-researcher + ciel-explorer in parallel (Agent tool)" >&2
  echo "  2. Include relevant domain skill names in the dispatch prompt" >&2
  echo "  3. Then retry the edit." >&2
  echo "" >&2
  echo "  Trivial task? Add [CIEL_GATE_BYPASS] to bypass this gate." >&2
  exit 2
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

# RELIRE gate warning (3+ files → critic required)
if [ "${COUNT:-0}" -ge 2 ] 2>/dev/null; then
  echo "[CIEL RELIRE GATE] ${COUNT} file(s) edited — dispatch ciel-critic MODE=RELIRE when done." >&2
fi

# === FAIRE GATE REMINDER ===
# Skip non-code files for faire gate
if [ "$IS_SOURCE" -eq 0 ] && [ "$IS_TEST" -eq 0 ]; then
  exit 0
fi

# Check if file is critical path
CRITICAL=false
if echo "$FILE_PATH" | grep -qiE '(auth|Auth|security|Security|Token|Session|Password|Secret)'; then
  CRITICAL=true
fi

if $CRITICAL; then
  echo "  [CIEL] Critical path: invoke faire-gatekeeper, stride-analyzer must have run, test-first (RED). After FAIRE: TESTER (run test suite)." >&2
else
  echo "  [CIEL] Standard path: invoke faire-gatekeeper (alternatives, idiomatic, quality, removal, test-first). After FAIRE: TESTER (run test suite)." >&2
fi

exit 0
