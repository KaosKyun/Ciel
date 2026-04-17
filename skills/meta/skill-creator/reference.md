# skill-creator — Reference

## YAML frontmatter schema (full)

```yaml
---
name: <kebab-case, max 64 chars, unique>
description: <max 1024 chars, third person, front-loaded use case + keywords>
# Optional fields below
when_to_use: <appended to description, same 1024-char cap counts>
disable-model-invocation: true   # Only manual /<name> invocation
user-invocable: false            # Hidden from / menu, only Claude can invoke
allowed-tools: Read Grep Bash(git *)   # Pre-approved tools (space-separated or YAML list)
argument-hint: "[filename]"      # Shown in autocomplete
context: fork                    # Runs in subagent (isolated context)
agent: Explore                   # Which agent type if forked: Explore, Plan, general-purpose, custom
effort: high                     # low | medium | high | xhigh | max (overrides session)
paths: "src/**/*.ts,tests/**/*.ts"   # Glob for auto-activation
shell: bash                      # bash | powershell (for inline !`commands`)
hooks:                           # Lifecycle hooks scoped to this skill
  PreToolUse:
    - matcher: Edit|Write
      hooks:
        - type: command
          command: ...
---
```

## Writing good descriptions — examples

BAD:
- "Helps with documents" (too generic)
- "I can help you with X" (first person)
- "Use this when needed" (no specificity)

GOOD:
- "Analyzes Excel spreadsheets, creates pivot tables, generates charts. Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files."
- "Narrates end-to-end data flow for a coding task: trigger → handler → service → state → output, with BOUNDARIES, ASSUMPTIONS, BREAK POINTS called out. Invoke for Standard and Critical tasks before implementation, especially when writing tests or modifying flow logic."

Formula: `<what it does (third person, verb-first)> + <when to use (keywords + triggers)> + <optional: key capabilities>`

## Category decision tree

- Does it enforce one of the 10 CRÉER / 7 CRITIQUER / META-CRITIQUER steps? → `workflow`
- Does it find information outside the codebase (web, docs, forums)? → `research`
- Does it encode expertise about a specific technology or pattern family? → `domain`
- Does it wrap a frequent mechanical operation (commit, PR, issue)? → `utility`
- Does it modify Ciel itself? → `meta`

## Size validation

SKILL.md line count (excluding YAML frontmatter and blank lines):

- ≤ 100 lines → OK (ideal for focused skills)
- 100–300 lines → OK (typical)
- 300–500 lines → warning (consider splitting to reference.md)
- > 500 lines → reject, require split

reference.md line count:

- ≤ 500 lines → OK
- > 500 lines → warning, consider second reference if truly needed (but Anthropic guidance is max one level deep)

## Progressive disclosure rules

- Every SKILL.md should be self-sufficient for the common case
- `reference.md` contains: extended examples, cheatsheets, edge cases, schemas
- NEVER nest references (SKILL.md → reference.md → detail.md is forbidden)
- Link from SKILL.md like: `For <what>, see \`reference.md\`.`

## Tool allowlist — common combinations

| Skill type | Typical tools |
|------------|---------------|
| research | `WebSearch, WebFetch` |
| file exploration | `Read, Grep, Glob` |
| code review | `Read, Grep, Glob, Bash` |
| git operations | `Bash(git *)` |
| GitHub API | `mcp__github__*` |
| staging verification | `Bash, Monitor, WebFetch` |

When in doubt, list the minimum that works. More tools = more permission friction.

## Context: fork — when to use

Use `context: fork` when:
- The skill reads many files and would pollute the main context
- The skill needs to be isolated from the main session's reasoning (to avoid blind-spot inheritance)
- The skill produces a structured report meant to be summarized

Agent types for fork:
- `Explore` — read-only exploration, grep, read, glob, web fetch
- `Plan` — read-only with design focus
- `general-purpose` — full tool access in isolated context

Do NOT use fork for:
- Skills that modify files (fork is read-only in most configurations)
- Skills that need to maintain running state across invocations
- Very short skills where fork overhead dwarfs value

## Paths glob — when to use

Use `paths: "<glob>"` for skills that are only relevant when editing specific files:
- `frontend-mastery` → `paths: "**/*.{tsx,jsx,vue,svelte}"`
- `database-mastery` → `paths: "**/*.sql,migrations/**,prisma/**"`
- `security-hardening` → `paths: "**/auth/**,**/security/**,**/*{Token,Password,Secret}*"`

This auto-activates the skill only when Claude is working on matching files, saving context elsewhere.

## Duplication detection (70%+ overlap)

When validating a new skill name + description, compute keyword overlap with existing skills:

1. Extract nouns + verbs from description (lowercase, stem)
2. Compare against each existing skill's description
3. If Jaccard similarity > 0.7 → flag duplication

Typical overlap false positives: all workflow skills share "task", "coding", "Ciel" — exclude these stopwords.

## Common rejections

- Generic names: `research-stuff`, `do-things` → require specificity
- "And" names: `foo-and-bar` → split into two skills
- Overlap > 70% with existing skill → require differentiation
- > 500 lines SKILL.md → require reference.md split
- YAML validation failure → regenerate from template
