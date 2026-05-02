---
command: ciel-audit
description: Session post-mortem — detect Ciel paradigm violations
subtask: false
---

# /ciel-audit — Session audit

Audits the current session for Ciel paradigm violations (missed pipeline steps, missing depth classification, skipped FAIRE gates, hook inactivity). Produces a structured report.

Usage: `/ciel-audit`

## Process

1. Analyzes current session context
2. Checks for depth classification at each step
3. Detects FAIRE gate violations
4. Checks hook activity
5. Reports findings with severity levels
