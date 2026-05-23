---
name: research-web-sources
description: Fetches official documentation via WebFetch and searches best practices via WebSearch for a specific library+version. Produces findings with version-stamped URLs and at least 1 anti-pattern. Invoked in the RECHERCHE step by the researcher agent.
allowed-tools: WebSearch, WebFetch
context: fork
agent: researcher
---

# research-web-sources — Official docs + best practices

## What this covers
Meta-research skill #1 of 6. Fetches the primary source (official docs) + best-practice articles for a specific library+version. This is the highest-credibility research step — if official docs answer the question, stop here.

## Core principle
**Official docs are the source of truth.** If docs exist and answer the question, don't search further. Escalate to GitHub issues and forums only when docs are silent.

## Inputs

```
TASK: [1-sentence description]
TECHNOLOGY: [lib name]
VERSION: [exact installed version — from avec-quoi-versioner]
QUESTION: [specific question]
```

## Process

### 1. Fetch official documentation

- Primary: WebFetch the official docs URL
- If docs for the exact version aren't available, fetch the latest + note the version gap
- Focus on the specific API/feature in question — don't fetch whole doc site

### 2. WebSearch for best practices

Queries (run at least 2):
- `[feature] [lib] [version] best practices`
- `[feature] [lib] idiomatic way`

### 3. Identify framework philosophy

From docs: how does this framework WANT this problem solved? Not just what the API is — the intended approach.

### 4. Extract anti-patterns (MANDATORY — at least 1)

Queries:
- `[lib] [feature] common mistakes anti-patterns`
- `[lib] [version] pitfalls avoid`

Cite at least one documented anti-pattern with source URL.

## Common patterns

### Good research output

```
## RESEARCH — React 19

### FINDINGS
- Server Components are the default in React 19 — no "use client" needed for static rendering
- `use()` hook replaces useEffect for data fetching in client components
- Source: https://react.dev/reference/rsc/server-components (React 19.0)

### ANTI-PATTERNS À ÉVITER
- useEffect + fetch waterfall — use Server Components instead — official docs
- "use server" on components — this directive is for Server Functions, not components — react.dev

### PHILOSOPHY DU FRAMEWORK
React 19 pushes data fetching to the server. Client components handle interactivity only.
```

### Bad research output

```
FINDINGS:
- React is good for UI
- You can use hooks
```

Problems: no version, no specific API, no source URLs, no anti-patterns.

## Anti-patterns

- **No version stamp** — every finding must include the version it applies to
- **Filling gaps with assumptions** — if docs don't cover it, say so explicitly
- **Preamble** — return only the structured report, no "I found that..."
- **Fetching entire doc site** — focus on the specific API/feature in question
- **Minimum output not met** — ≥ 1 WebSearch result + ≥ 1 documented finding required

## How to verify

- [ ] ≥ 1 WebSearch performed?
- [ ] ≥ 1 finding with version stamp?
- [ ] ≥ 1 anti-pattern cited?
- [ ] Source URLs present?
- [ ] Framework philosophy stated (1-2 sentences)?
- [ ] No preamble (structured report only)?

## When triggered

- `researcher` agent, RECHERCHE step on Standard/Critical tasks
- User explicit request: "research <lib> <feature>"
- When task mentions a library that's not fully understood

## References

- Tier-1 source credibility — validate-source-credibility skill
- Ciel waterfall: research-web-sources → research-github-issues → research-forums → synthesize-findings
