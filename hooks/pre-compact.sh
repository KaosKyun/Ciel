#!/bin/bash
# Ciel — PreCompact hook
# Trigger: before context compaction
# Purpose: write .claude/session-progress.md + invoke learnings-capture skill
# Never blocks (exit 0 always)

INPUT=$(cat 2>/dev/null || echo "{}")
CWD=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('cwd', ''))" 2>/dev/null || pwd)

MSG="CIEL PRE-COMPACT — Invoke learnings-capture skill NOW to persist any user corrections + failure modes from this session. Then write .claude/session-progress.md with: current status, completed tasks, **failed approaches + why they failed**, known limitations, next steps. Failed approaches field is critical — prevents dead-end loops in next session."

echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreCompact\", \"additionalContext\": \"$MSG\"}}"
exit 0
