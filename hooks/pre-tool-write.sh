#!/bin/bash
# Ciel — PreToolUse hook for Write/Edit
# Never blocks (exit 0 always)

# Ignore all arguments
shift $# 2>/dev/null || true

echo "CIEL FAIRE — Before writing: (1) alternatives considered? (2) idiomatic? (3) quality gates? (4) test-first (RED)? (5) removal gate?"
exit 0
