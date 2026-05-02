---
command: ciel-create-skill
description: Generate a new Ciel SKILL.md scaffold
agent: ciel-improver
subtask: true
---

# /ciel-create-skill — Create new skill

Generates a valid Ciel SKILL.md scaffold following Anthropic Skills-first rules (kebab-case ≤64, YAML description ≤1024, body ≤500 lines).

Usage: `/ciel-create-skill <name> <purpose>`

## Process

1. Validates skill name (kebab-case, ≤64 chars)
2. Researches common patterns for the domain
3. Generates SKILL.md with YAML frontmatter
4. Returns proposed skill for user approval
5. Never writes autonomously
