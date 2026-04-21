---
description: Generate valid SKILL.md scaffold (kebab-case ≤64 chars, YAML description ≤1024, body ≤500 lines). Follows Anthropic Skills-first rules.
---
---

# /ciel-create-skill — Create a new Ciel skill

*Generates a valid SKILL.md scaffold following Anthropic Skills-first rules (kebab-case name ≤64 chars, YAML frontmatter ≤1024-char description, ≤500-line body, progressive disclosure to one reference.md).*

Usage: `/ciel-create-skill <name> <purpose>`

- `name` — kebab-case, max 64 chars, unique across `skills/`
- `purpose` — one-line description of what the skill does

---

## What it does

1. Dispatches the `improver` agent in MODE=CREATE-SKILL
2. The agent invokes `skill-creator` skill
3. Validates name, category (you pick), description length, uniqueness, paths glob
4. Generates a scaffold SKILL.md + optional reference.md
5. Returns the proposed files for user review
6. On approval, writes files + registers in `skills/ciel/reference.md` catalog

---

## Example

```
/ciel-create-skill kotlin-coroutines-mastery "Expert in Kotlin coroutines: structured concurrency, Flow operators, cancellation, testing. Use when working with suspend functions, CoroutineScope, Flow, or coroutine builders."
```

Expected output:
1. Validation: ✓ name valid, unique, no reserved words
2. Category suggestion: `domain` (based on "Expert in X" pattern)
3. Preview of `skills/domain/kotlin-coroutines-mastery/SKILL.md` (~150 lines)
4. Preview of `skills/domain/kotlin-coroutines-mastery/reference.md` (~300 lines) with Flow operators cheatsheet
5. Catalog entry: `| kotlin-coroutines-mastery | Kotlin files with suspend/Flow |`
6. Approve? [y/n/edit]

---

## Naming rules

- kebab-case only (no underscores, no camelCase)
- Max 64 chars
- No reserved words: `anthropic`, `claude`, `mcp`
- Must be unique across `skills/**/SKILL.md`
- Warn if starts with category name (e.g. `workflow-foo` in `workflow/` is redundant)

---

## Category decision

- `workflow` — enforces a CRÉER/CRITIQUER/META-CRITIQUER step
- `research` — finds information outside the codebase
- `domain` — encodes expertise in a specific tech or pattern family
- `utility` — wraps a frequent mechanical operation
- `meta` — modifies Ciel itself

---

## Guardrails

- **Max 1 new skill per invocation** — prevents skill explosion
- **SKILL.md size**: ≤ 300 lines (hard cap)
- **reference.md size**: ≤ 500 lines (hard cap)
- **Duplication detection**: warns if description overlaps ≥ 70% with existing skill
- **Never creates**: files in `.claude-plugin/`, agents, hooks, commands — those use different patterns

---

## After creation

1. Test the skill: `/ciel-eval <name>` (runs baseline eval if dataset exists)
2. If it's a `workflow` skill, update `skills/ciel/SKILL.md` pipeline sections to reference it
3. Commit with message `feat(ciel): add <category>/<name> skill`
