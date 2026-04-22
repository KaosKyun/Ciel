#!/bin/bash
# Ciel — PreToolUse hook for Write/Edit
# Trigger: before Write/Edit tool execution
# Purpose: inject FAIRE gate reminder
# Never blocks (exit 0 always)

MSG="CIEL FAIRE — Before writing: (1) alternatives considered? (2) idiomatic? (3) quality gates? (4) test-first (RED)? (5) removal gate?"

echo "$MSG"
exit 0
