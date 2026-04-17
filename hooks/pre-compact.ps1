# Ciel — PreCompact hook (PowerShell)
# Trigger: before context compaction
# Purpose: invoke learnings-capture skill + write session-progress

$msg = "CIEL PRE-COMPACT — Invoke learnings-capture skill NOW to persist any user corrections + failure modes from this session. Then write .claude/session-progress.md with: current status, completed tasks, **failed approaches + why they failed**, known limitations, next steps. Failed approaches field is critical — prevents dead-end loops in next session."

@{
    hookSpecificOutput = @{
        hookEventName = "PreCompact"
        additionalContext = $msg
    }
} | ConvertTo-Json -Compress
exit 0
