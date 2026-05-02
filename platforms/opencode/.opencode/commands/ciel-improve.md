---
command: ciel-improve
description: Self-improvement — analyze sessions and propose skill patches
agent: ciel-improver
subtask: true
---

# /ciel-improve — Self-improvement

Analyzes recent session transcripts to detect repeated failure modes, user corrections, and skill output truncation, then produces a patch-set proposing specific rewrites for Ciel skills.

Usage: `/ciel-improve`

## Process

1. Scans `.ciel/learnings.md` for recent user corrections
2. Analyzes session transcripts for failure patterns
3. Produces a patch-set with specific skill rewrites
4. Never rewrites autonomously — returns proposals for review
