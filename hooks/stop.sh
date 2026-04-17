#!/bin/bash
# Ciel — Stop hook
# Trigger: Claude finishes responding (end of task)
# Purpose: inject meta-critiquer instruction + trigger learnings-capture
# Never blocks (exit 0 always)

MSG="CIEL STOP — 30s META-CRITIQUER obligatoire avant de declarer fini: (1) depth match? (2) new failure mode → Guard? (3) user correction → overlay/learnings? (4) stale branches? (5) uncovered issues? (6) context health? (7) session-progress.md written? (8) dead code sweep (ruff/knip/Detekt)? Invoke meta-critiquer skill then learnings-capture if corrections detected."

echo "{\"hookSpecificOutput\": {\"hookEventName\": \"Stop\", \"additionalContext\": \"$MSG\"}}"
exit 0
