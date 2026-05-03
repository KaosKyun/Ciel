---
command: ciel-recommend
description: Discover community plugins matched to your project stack
agent: ciel-researcher
subtask: true
---

# /ciel-recommend — Plugin discovery

Discovers community and officialOpenCode plugins matched to the project's detected stack.

Usage: `/ciel-recommend`

## Process

1. Reads project stack from package.json, ciel-overlay.md
2. Searches OpenCode ecosystem for matching plugins
3. Returns recommendations ranked by relevance
