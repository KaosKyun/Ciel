#!/bin/bash
# Ciel — PreCompact hook
# Trigger: before context compaction
# Purpose: write .claude/session-progress.md + invoke learnings-capture skill
# Never blocks (exit 0 always)

INPUT=$(cat 2>/dev/null || echo "{}")
CWD=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('cwd', ''))" 2>/dev/null || pwd)

MSG="CIEL PRE-COMPACT — Invoke memoire skill NOW to persist any user corrections + failure modes from this session to .ciel/memory/episodes/. Then write .claude/session-progress.md with: current status, completed tasks, **failed approaches + why they failed**, known limitations, next steps. Failed approaches field is critical — prevents dead-end loops in next session."

# PreCompact has no documented context-injection field. Use top-level
# systemMessage — valid for every hook, surfaces the reminder to the user.
python3 -c "
import json, sys
print(json.dumps({'systemMessage': sys.argv[1]}))
" "$MSG"
exit 0
