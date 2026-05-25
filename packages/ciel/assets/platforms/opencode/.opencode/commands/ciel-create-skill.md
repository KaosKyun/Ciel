---
description: ---
agent: ciel-improver
subtask: true
---

> **OpenCode note**: This command requires `claude --print` headless mode for full functionality (binary evals, skill scaffold generation). On OpenCode it runs in degraded mode — the improver agent returns proposals only. For the full harness, use Claude Code.

---
description: Generates a valid Ciel v7 SKILL.md scaffold — kebab-case name, YAML frontmatter with triggers.path, 3-section body (Checklist / Anti-patterns / Patterns), max 200 lines.
---

# /ciel-create-skill — Create a new Ciel v7 skill

Generates a valid SKILL.md scaffold following Ciel v7 format: 3 sections (Checklist, Anti-patterns, Patterns), kebab-case name, optional path trigger.

Usage: `/ciel-create-skill <name> <domain-description>`

- `name` — kebab-case, max 64 chars, unique across `.claude/skills/`
- `domain-description` — one-line description of what domain expertise this skill encodes

---

## What it does

1. Dispatches `ciel-improver` agent with MODE=CREATE-SKILL
2. Validates name (kebab-case, uniqueness, no reserved words)
3. Helps you define the path trigger (if any) and anti-patterns
4. Generates SKILL.md scaffold in v7 3-section format
5. On approval, writes to `.claude/skills/<name>/SKILL.md`
6. Optionally runs `sync-skills.sh` to distribute to mirrors

---

## Example

```
/ciel-create-skill kotlin-coroutines "Kotlin coroutines — structured concurrency, Flow operators, cancellation, testing. Use when working with suspend functions, CoroutineScope, Flow."
```

Expected output:
1. Validation: name valid and unique
2. Path trigger suggestion: `**/*.kt,**/*.kts`
3. Preview of `SKILL.md` scaffold (~100-150 lines)
4. Approve? [y/n/edit]

---

## Naming rules

- kebab-case only (no underscores, no camelCase)
- Max 64 chars
- No reserved words: `anthropic`, `claude`, `mcp`
- Must be unique across `.claude/skills/`

---

## Guardrails

- **Max 1 new skill per invocation** — prevents skill explosion
- **SKILL.md max 200 lines** — v7 hard cap
- **Duplication detection**: warns if description overlaps >= 70% with existing skill
- **Never creates**: agent definitions, hooks, commands — those use different patterns

---

## After creation

1. Test the skill on a relevant task — does it load when expected?
2. Commit with message: `feat(skills): add <name> skill`
3. Run `bash scripts/sync-skills.sh` to distribute to all mirrors
