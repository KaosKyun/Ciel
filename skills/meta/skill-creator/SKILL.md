---
name: skill-creator
description: Creates a new Ciel skill from a conversation pattern or explicit user request. Validates kebab-case naming (≤64 chars), YAML frontmatter (description ≤1024 chars, third-person, front-loaded use case), file size (SKILL.md ≤500 lines), and progressive-disclosure structure (one reference.md max). Use when the user types /ciel-create-skill or when /ciel-improve detects a repeating pattern worth extracting.
allowed-tools: Read, Glob, Bash
---

# skill-creator — Meta-skill for skill creation

This skill generates a valid SKILL.md scaffold following Anthropic Skills-first rules. It does NOT write the file directly — it returns a diff for user approval, then applies it if approved.

For the full YAML template and validation rules, see `reference.md`.

---

## Inputs

- **name**: kebab-case, max 64 chars, unique across `skills/`
- **category**: one of `workflow`, `research`, `domain`, `utility`, `meta`
- **purpose**: one-line description of what the skill does (will become the `description` field foundation)
- **context-fork?**: does the skill need an isolated fork context? (boolean)
- **agent-type**: if forked, which agent? (Explore, Plan, general-purpose)
- **tools-needed**: subset of available tools the skill will use
- **paths-glob?**: if the skill should auto-activate on specific file paths, the glob pattern

---

## Validation pipeline

### 1. Name validation

- Match regex: `^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$` (kebab-case, ≤ 64 chars, no leading/trailing hyphen)
- Reserved words: reject if contains `anthropic`, `claude`, `mcp`
- Uniqueness: check `skills/**/SKILL.md` YAML `name` fields — must not collide
- Category prefix: warn if name starts with the category (e.g. `workflow-foo` in `workflow/` category is redundant)

### 2. Category validation

Must be exactly one of: `workflow`, `research`, `domain`, `utility`, `meta`. Reject otherwise.

### 3. Description generation

From the `purpose` input, generate a valid description:

- Third person: "Analyzes X" ✓ / "I analyze X" ✗
- Front-load use case + keywords that trigger Claude's selection
- Include "Use when..." clause with specific triggers
- ≤ 1024 chars total (hard limit)
- Recommended 200-500 chars (enough specificity without bloat)

### 4. Scaffold SKILL.md

Template (fills in placeholders):

```markdown
---
name: <name>
description: <generated description>
[allowed-tools: <comma-separated tools> — only if non-default]
[context: fork — only if needed]
[agent: <agent-type> — only if context: fork]
[paths: "<glob>" — only if auto-activate]
---

# <human-readable name> — <category>

<1-2 sentence overview of what this skill does>

For <extended content area>, see `reference.md`.

---

## Inputs

- <expected inputs>

---

## Process

### 1. <step name>

<description>

### 2. <step name>

<description>

---

## Output format

<expected output shape>

---

## Guardrails

- <rule 1>
- <rule 2>

---

## When triggered

- <trigger 1>
- <trigger 2>
```

### 5. Optional reference.md

If the user indicates the skill needs extended content, generate `reference.md` scaffold alongside SKILL.md. Critical rule: only ONE level of reference, never nested.

### 6. Register in catalog

Append to `skills/ciel/reference.md` under the appropriate category section.

---

## Output format

```
# Proposed new skill: <category>/<name>

## Validation results
- Name: ✓ valid kebab-case, ≤ 64 chars, unique
- Category: ✓ <category>
- Description length: <N> / 1024 chars
- Tools: <list>
- Context: <main | fork>

## Files to create
1. skills/<category>/<name>/SKILL.md (<N> lines)
2. skills/<category>/<name>/reference.md (<M> lines) [if applicable]

## Preview — skills/<category>/<name>/SKILL.md
<full file content>

## Catalog entry to append
<1-line entry for skills/ciel/reference.md>

Approve and create? [y/n/edit]
```

---

## Guardrails

- **Max 1 new skill per invocation** (prevents skill explosion)
- **SKILL.md line budget**: ≤ 300 lines hard cap (aim for 100-200)
- **reference.md line budget**: ≤ 500 lines hard cap
- **Duplication check**: if description overlaps significantly with an existing skill (≥ 70% keyword match), warn and ask user to merge or differentiate
- **Never create**: skills named like `claude-*`, `anthropic-*`, `mcp-*`
- **Always preserve**: YAML valid at all times — if any field breaks the schema, rescaffold from template

---

## When triggered

- User runs `/ciel-create-skill <name> <purpose>`
- `ciel-improve` or `meta-critiquer` detects a pattern worth extracting and proposes a new skill
- User says "create a skill for X" or "turn this into a skill"
