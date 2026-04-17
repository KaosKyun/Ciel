#!/bin/bash
# Ciel — Stop hook
# Trigger: Claude finishes responding (end of task)
# Purpose: inject meta-critiquer instruction before letting the model stop.
#
# Claude Code Stop-hook schema rejects hookSpecificOutput.additionalContext
# (it is only valid for UserPromptSubmit/PostToolUse). The documented way to
# steer the model at Stop is {"decision":"block","reason":"..."} — the reason
# is surfaced as an instruction the model must address.
#
# To avoid an infinite Stop→block→Stop loop, the hook inspects
# `stop_hook_active` from stdin: when true, we are re-entering after a prior
# block, so we exit silently and allow the stop.

INPUT=$(cat 2>/dev/null || echo "{}")

ACTIVE=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    print('true' if d.get('stop_hook_active', False) else 'false')
except Exception:
    print('false')
" "$INPUT" 2>/dev/null || echo "false")

if [ "$ACTIVE" = "true" ]; then
  exit 0
fi

MSG="CIEL STOP — 30s META-CRITIQUER obligatoire avant de declarer fini: (1) depth match? (2) new failure mode → Guard? (3) user correction → overlay/learnings? (4) stale branches? (5) uncovered issues? (6) context health? (7) session-progress.md written? (8) dead code sweep (ruff/knip/Detekt)? Invoke meta-critiquer skill then learnings-capture if corrections detected."

python3 -c "
import json, sys
print(json.dumps({'decision': 'block', 'reason': sys.argv[1]}))
" "$MSG"

exit 0
