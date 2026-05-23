# Patch-Set Format Specification

Shared output format for `ciel-improve` (transcript-driven skill rewrites) and `skill-freshness-auditor` (external-reference freshness). Both produce the same structure for user approval.

## Format

Each patch-set is a markdown file with sections. One patch per change, never batched.

```
## Patch <N>/<TOTAL>: <brief description>

### File
<relative path to the SKILL.md or file>

### Change
<what to add, remove, or modify — exact text>

### Rationale
<why this change improves the skill — 1-2 sentences>

### Evidence
<for freshness: the source URL + what changed>
<for improve: the transcript excerpt that triggered this>
```

## Rules

1. **Max 5 patches per run** — a larger change means the skill needs a rewrite, not patches
2. **One patch per concern** — never batch unrelated changes into one patch
3. **Relative paths only** — never absolute paths
4. **No auto-apply** — patches are for user approval only
5. **Evidence is mandatory** — without evidence, the patch is speculation

## Example

```
## Patch 1/3: Update Playwright MCP version pin

### File
skills/domain/mcp-configurator/SKILL.md

### Change
Replace `@playwright/mcp@latest` with `@playwright/mcp@1.52.0`

### Rationale
v1.52.0 added `browser_drop` tool, fixing a gap in file upload workflow.

### Evidence
https://github.com/microsoft/playwright-mcp/releases/tag/v1.52.0
```
