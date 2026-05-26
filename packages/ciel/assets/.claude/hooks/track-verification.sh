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
# Ciel v9 — PostToolUse hook for Bash
# Records a verification timestamp when a test/verification runner is observed.
# Pairs with stop.sh: if code was edited after the last verification, Stop blocks.
#
# NOTE: records on test-command RUN, not on PASS. Deterministic exit-code capture
# across ecosystems is unreliable, so the gate enforces "tests were run after the
# edit"; Rule dure #4 (observe a positive signal) covers the pass requirement.
# Never blocks (exit 0 always).

INPUT=$(cat 2>/dev/null || echo "{}")
[ -z "${CLAUDE_PROJECT_DIR:-}" ] && exit 0

CMD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null || echo "")

[ -z "$CMD" ] && exit 0

# Test/verification runners across ecosystems. Generous on purpose: any of these
# running after a code edit clears the Stop verification gate for this session.
if echo "$CMD" | grep -qiE '(\bnpm (run )?test|\byarn (run )?test|\bpnpm (run )?test|\bbun test|\bvitest|\bjest|\bmocha|node --test|tsx --test|\bpytest|python[0-9.]* -m pytest|\bgo test|\bcargo test|\bphpunit|\brspec|\bmvn test|gradle.*test|\bctest|dotnet test|make (test|check|verify)|npm run (check|verify|ci|typecheck)|bash [^&|;]*test[^&|;]*\.sh|scripts/test-|tsx [^&|;]*test|\.sh --check)'; then
  mkdir -p "$CLAUDE_PROJECT_DIR/.ciel" 2>/dev/null || true
  date -u +%Y-%m-%dT%H:%M:%SZ > "$CLAUDE_PROJECT_DIR/.ciel/last-verification" 2>/dev/null || true
fi

exit 0
