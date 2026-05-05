---
command: ciel-refresh
description: Freshness audit over the skill library
agent: ciel-improver
subtask: true
---

# /ciel-refresh — Freshness audit

Scans every Ciel skill for stale external references (outdated library version pins, dead URLs, superseded research citations) and produces a freshness patch-set for user approval.

Usage: `/ciel-refresh`

## Process

1. Lists all skills from `skills/`
2. For each skill, checks external references
3. Flags outdated URLs, version pins, citations
4. Produces patch-set for user approval
5. Never rewrites autonomously
