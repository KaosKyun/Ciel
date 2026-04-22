#!/bin/bash
# Ciel — PostToolUse hook for Write/Edit
# Trigger: after Write/Edit tool execution
# Purpose: inject RELIRE reminder
# Never blocks (exit 0 always)

MSG="CIEL RELIRE — File written. Review: (1) 3 RISQUES (functional + imports + data) (2) FIX/ACCEPT/DEFER."

echo "$MSG"
exit 0
