#!/bin/bash
# Ciel — Stop hook
# Trigger: Claude finishes responding
# Purpose: inject meta-critiquer instruction
# Never blocks (exit 0 always)

MSG="CIEL STOP — META-CRITIQUER: (1) depth match? (2) failure mode? (3) user correction? (4) stale branches? (5) uncovered issues? (6) context health? (7) dead code sweep?"

echo "$MSG"
exit 0
