#!/bin/bash
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
if echo "$CMD" | grep -qiE '(\bnpm (run )?test|\byarn (run )?test|\bpnpm (run )?test|\bbun test|\bvitest|\bjest|\bmocha|node --test|tsx --test|\bpytest|python[0-9.]* -m pytest|\bgo test|\bcargo test|\bphpunit|\brspec|\bmvn test|gradle.*test|\bctest|dotnet test)'; then
  mkdir -p "$CLAUDE_PROJECT_DIR/.ciel" 2>/dev/null || true
  date -u +%Y-%m-%dT%H:%M:%SZ > "$CLAUDE_PROJECT_DIR/.ciel/last-verification" 2>/dev/null || true
fi

exit 0
