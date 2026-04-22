#!/bin/bash
# Ciel — Stop hook
# Never blocks (exit 0 always)

# Ignore all arguments
shift $# 2>/dev/null || true

echo "CIEL STOP — META-CRITIQUER: (1) depth match? (2) failure mode? (3) user correction? (4) stale branches? (5) uncovered issues? (6) context health? (7) dead code sweep?"
exit 0
