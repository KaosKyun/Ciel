# Ciel — Stop hook (PowerShell)
# Trigger: Claude finishes responding
# Purpose: inject meta-critiquer instruction

$msg = "CIEL STOP — 30s META-CRITIQUER obligatoire avant de declarer fini: (1) depth match? (2) new failure mode → Guard? (3) user correction → overlay/learnings? (4) stale branches? (5) uncovered issues? (6) context health? (7) session-progress.md written? (8) dead code sweep (ruff/knip/Detekt)? Invoke meta-critiquer skill then learnings-capture if corrections detected."

@{
    hookSpecificOutput = @{
        hookEventName = "Stop"
        additionalContext = $msg
    }
} | ConvertTo-Json -Compress
exit 0
