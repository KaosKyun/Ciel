#!/bin/bash

# CIEL-DEFER-GUARD — a global plugin instance no-ops when the project ships AND
# wires its own copy of this hook. Paths are canonicalized (pwd -P) on BOTH sides
# so a symlinked or trailing-slash CLAUDE_PROJECT_DIR cannot make the project's
# own instance wrongly defer (which would disable Ciel entirely in the project).
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  _ciel_name="$(basename "${BASH_SOURCE[0]}")"
  _ciel_self="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
  _ciel_proj="$(cd "$CLAUDE_PROJECT_DIR/.claude/hooks" 2>/dev/null && pwd -P)"
  if [ -n "$_ciel_proj" ] && [ -f "$_ciel_proj/$_ciel_name" ] && [ "$_ciel_self" != "$_ciel_proj" ]; then
    exit 0
  fi
fi
# Ciel v9 — PreToolUse hook for Write/Edit
# Gate DISPATCH: blocks source code writes until researcher+explorer dispatched
# Escape hatch: [CIEL_GATE_BYPASS] in tool input bypasses the gate

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

# ── Bypass check ──────────────────────────────────────────────────────────
if echo "$INPUT" | grep -q '\[CIEL_GATE_BYPASS\]'; then
  echo "[CIEL] Gate bypassed — allowing write to $(basename "$FILE_PATH")" >&2
  exit 0
fi

# ── File classification ───────────────────────────────────────────────────
IS_SOURCE=0
if echo "$FILE_PATH" | grep -qE '\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte)$'; then
  IS_SOURCE=1
fi

IS_TEST=0
if echo "$FILE_PATH" | grep -qE '\.(test|spec)\.|_test\.|_spec\.|/test/|/tests/|/__tests__/'; then
  IS_TEST=1
fi

# ── Dispatch gate — the core enforcement ──────────────────────────────────
# Marker is .ciel/dispatched (written by pre-agent-gate.sh on a ciel-researcher/
# explorer dispatch, cleared by session-start.sh). Session- and project-scoped.
DISPATCHED=0
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.ciel/dispatched" ]; then
  DISPATCHED=1
fi

TASK_DEPTH="Standard"
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.ciel/last-depth" ]; then
  TASK_DEPTH=$(cat "$PROJECT_DIR/.ciel/last-depth" 2>/dev/null || echo "Standard")
fi

if [ "$IS_SOURCE" -eq 1 ] && [ "$IS_TEST" -eq 0 ] && [ "$DISPATCHED" -eq 0 ] && [ "$TASK_DEPTH" != "Trivial" ]; then
  echo "[CIEL DISPATCH GATE] Write blocked: $(basename "$FILE_PATH") — no researcher+explorer dispatched yet." >&2
  echo "  Dispatch them in parallel via Agent tool, then retry." >&2
  echo "  Trivial task? Use [CIEL_GATE_BYPASS] in tool input." >&2
  exit 2
fi

# ── RELIRE gate reminder (soft, after 3+ edits in session) ────────────────
COUNT=0
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.ciel/tracked-files.json" ]; then
  COUNT=$(python3 -c "
import json
try:
    with open('$PROJECT_DIR/.ciel/tracked-files.json') as f:
        print(len(json.load(f)))
except: print(0)
" 2>/dev/null || echo "0")
fi

if [ "${COUNT:-0}" -ge 2 ] 2>/dev/null; then
  echo "[CIEL REVIEW GATE] ${COUNT} files edited — dispatch ciel-critic MODE=RELIRE before commit." >&2
fi

exit 0
