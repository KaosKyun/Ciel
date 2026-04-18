---
description: "Create a new Ciel skill scaffold with validated naming and category"
agent: ciel-improver
subtask: true
---

Create a new Ciel skill. Usage: `/ciel-create-skill <name> <purpose>`

Load the `ciel` skill via `skill({ name: "ciel" })` and follow the `skill-creator` instructions.

Args: $ARGUMENTS

## Rules
- kebab-case name, max 64 chars
- Valid categories: workflow, research, domain, utility, meta
- SKILL.md ≤ 300 lines, reference.md ≤ 500 lines
- Output the proposed files for user approval before writing
