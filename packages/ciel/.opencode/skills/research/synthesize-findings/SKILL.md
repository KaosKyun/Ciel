---
name: synthesize-findings
description: Merges outputs from research-web-sources, research-github-issues, and research-forums into a single structured report with FINDINGS / ANTI-PATTERNS / PHILOSOPHY / API SURFACE / UNCERTAINTIES sections. Cross-references conflicting claims and deduplicates. Produces the final research deliverable.
---

# synthesize-findings — Merge research into one report

## What this covers
Meta-research skill #5 of 6. After parallel research skills have produced raw findings, this skill merges them into the single canonical format that the `researcher` agent returns.

## Core principle
**Conflicts are signals, not noise.** When two sources disagree, that disagreement is the most valuable finding. Surface it, don't hide it.

## Inputs

```
WEB_RESULTS: [output of research-web-sources — or "none"]
GITHUB_RESULTS: [output of research-github-issues — or "none"]
FORUM_RESULTS: [output of research-forums — or "none"]
CREDIBILITY_SCORES: [output of validate-source-credibility for low-tier sources]
```

## Process

### 1. Deduplicate

Same claim from multiple sources → merge, cite all sources ordered by credibility tier (highest first).

### 2. Resolve conflicts

When two sources disagree:
- Higher credibility tier wins (official docs > forum)
- Newer wins among same tier
- Both recent Tier 1 but disagree → flag as uncertainty
- Version-specific → align to installed version

### 3. Populate canonical sections

- **FINDINGS**: positive statements with version + source
- **ANTI-PATTERNS À ÉVITER**: what NOT to do, with reason + source
- **PHILOSOPHY DU FRAMEWORK**: how the framework wants this solved (1-2 sentences)
- **API SURFACE**: verified imports / signatures / response shapes
- **INCERTITUDES**: unresolved questions, conflicts, version gaps

### 4. Apply credibility filter

Any finding sourced only from Tier 4/5 without Tier 1/2 cross-reference → demote to INCERTITUDE.

### 5. Enforce minimum gate

Output is incomplete if ANY of:
- 0 findings
- 0 anti-patterns
- No philosophy statement
- No version stamp on any finding

## Common patterns

### Good synthesis

```
## FINDINGS
- React 19 Server Components are the default — no "use client" needed for static rendering [v19.0]
  Source: https://react.dev/reference/rsc/server-components (Tier 1)
- `use()` hook replaces useEffect for data fetching [v19.0]
  Source: react.dev (Tier 1) + SO #12345 89 upvotes (Tier 3)

## ANTI-PATTERNS À ÉVITER
- useEffect + fetch waterfall — use Server Components instead — react.dev
- "use server" on components — directive is for Server Functions — react.dev

## PHILOSOPHY DU FRAMEWORK
React 19 pushes data fetching to the server. Client components handle interactivity only.

## API SURFACE (verified)
- `use()` — react.dev/reference/react/use
- Server Components — `async function Component()` without "use client"

## INCERTITUDES
- Migration path from useEffect-based data fetching: docs show examples but no automated codemod exists
```

### Bad synthesis

```
React is good. Use Server Components. Don't use useEffect.
```

Problems: no version, no sources, no anti-patterns, no uncertainties.

## Anti-patterns

- **Inventing findings** — if research didn't produce a finding, leave it empty
- **No citations** — every finding has a URL or file:line
- **Empty INCERTITUDES** — suspicious. Research rarely resolves everything.
- **Conflicts hidden** — when sources disagree, surface it as INCERTITUDE
- **Output too long** — ≤ 500 tokens (researcher returns this to main session)

## How to verify

- [ ] All 3 research inputs consumed (or marked "none")?
- [ ] FINDINGS have version stamps + source URLs?
- [ ] ≥ 1 anti-pattern documented?
- [ ] PHILOSOPHY stated (1-2 sentences)?
- [ ] Conflicts surfaced as INCERTITUDES?
- [ ] Output ≤ 500 tokens?
- [ ] Minimum gate passed (findings + anti-patterns + philosophy + versions)?

## When triggered

- By `researcher` agent at the end of its research pipeline
- User request: "summarize research findings on X"
