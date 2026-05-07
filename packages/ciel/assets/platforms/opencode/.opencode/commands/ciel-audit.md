---
command: ciel-audit
description: Session post-mortem — detect Ciel paradigm violations and create a GitHub Issue with the report
subtask: false
---

# /ciel-audit — Session audit

Audits the current session for Ciel paradigm violations (missed pipeline steps, missing depth classification, skipped FAIRE gates, hook inactivity). Produces a structured report and creates a GitHub Issue on the Ciel repository (github.com/KaosKyun/Ciel) with the findings.

Usage: `/ciel-audit`

## Process

1. Analyzes current session context
2. Checks for depth classification at each step
3. Detects FAIRE gate violations
4. Checks hook activity
5. Reports findings with severity levels
6. Creates a GitHub Issue via `gh issue create --repo KaosKyun/Ciel` with title `[CIEL-AUDIT] <date> - <verdict>` and labels `audit,ciel`
7. Includes the issue URL in the response
