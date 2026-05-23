---
name: skill-creator
description: Creates a new Ciel skill from a conversation pattern or explicit user request. Validates kebab-case naming, YAML frontmatter, file size limits, and progressive-disclosure structure. Returns proposed SKILL.md for user approval — never writes directly.
allowed-tools: Read, Glob, Bash
---

# skill-creator — Meta-skill for skill creation

## What this covers
Generates a valid SKILL.md scaffold following Ciel's conventions. Returns a diff for user approval, then applies it if approved.

## Core principle
**Skills are discovered, not registered.** The `description` field is the skill's search key. If it's vague, the skill won't trigger.

## Inputs

- **name**: kebab-case, max 64 chars, unique
- **category**: `workflow`, `research`, `domain`, `utility`, `meta`
- **purpose**: one-line description (becomes `description` foundation)
- **context-fork?**: needs isolated fork context? (boolean)
- **tools-needed**: subset of available tools

## Validation pipeline

### 1. Name validation

- Regex: `^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$`
- Reserved: reject `anthropic`, `claude`, `mcp` prefixes
- Uniqueness: check existing skills — no collision
- Category prefix: warn if redundant (e.g. `workflow-foo` in `workflow/`)

### 2. Description generation

- Third person: "Analyzes X" ✓ / "I analyze X" ✗
- Front-load use case + trigger keywords
- Include "Use when..." clause
- ≤ 1024 chars, recommended 200-500

### 3. Scaffold SKILL.md

```markdown
---
name: <name>
description: <generated description>
[allowed-tools: <tools> — only if non-default]
[context: fork — only if needed]
[agent: <agent-type> — only if context: fork]
---

# <human-readable name>

<1-2 sentence overview>

---

## Inputs
<expected inputs>

## Process
<steps>

## Output format
<expected output shape>

## Guardrails
<rules>

## When triggered
<triggers>
```

### 4. Optional reference.md

If user indicates need for extended content, generate `reference.md` alongside SKILL.md. Only ONE level of reference, never nested.

## Common patterns

### Good skill description

```yaml
description: Generates 3 hostile critiques per changed file (1 functional, 1 import, 1 data-assumption) and resolves each with FIX/ACCEPT/DEFER. Invoked by the critic agent on Write/Edit for Standard/Critical tasks with 3+ changed files.
```

### Bad skill description

```yaml
description: Helps with code review.
```

Problems: no trigger, no output, no specificity.

## Anti-patterns

- **Max 1 new skill per invocation** — prevents skill explosion
- **SKILL.md ≤ 300 lines** — aim for 100-200
- **reference.md ≤ 500 lines**
- **Duplication check** — if ≥ 70% keyword overlap with existing skill, warn
- **Never create**: `claude-*`, `anthropic-*`, `mcp-*` names
- **Always preserve**: valid YAML frontmatter

## How to verify

- [ ] Name valid kebab-case, ≤ 64 chars, unique?
- [ ] Category is one of the 5 valid categories?
- [ ] Description: third person, ≤ 1024 chars, includes trigger?
- [ ] SKILL.md ≤ 300 lines?
- [ ] No overlap with existing skills (grep checked)?
- [ ] YAML frontmatter valid?
- [ ] Catalog entry appended to reference.md?

## When triggered

- User runs `/ciel-create-skill <name> <purpose>`
- `ciel-improve` detects a pattern worth extracting
- User says "create a skill for X" or "turn this into a skill"
