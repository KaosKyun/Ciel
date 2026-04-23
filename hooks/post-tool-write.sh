#!/bin/bash
# Ciel — PostToolUse hook for Write/Edit
# Never blocks (exit 0 always)

shift $# 2>/dev/null || true

echo "CIEL RELIRE — File written. Review: (1) 3 RISQUES (functional + imports + data) (2) FIX/ACCEPT/DEFER."
exit 0
