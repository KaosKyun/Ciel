---
name: research-forums
description: Fallback research source when official docs and GitHub issues are silent — searches StackOverflow, Reddit, Hacker News, and dev.to for community discussion. Lower priority than official sources but valuable for edge cases. Always followed by validate-source-credibility.
allowed-tools: WebSearch
context: fork
agent: researcher
---

# research-forums — Community discussion fallback

## What this covers
Meta-research skill #3 of 6. When official docs + GitHub issues don't resolve the question, community forums often have the answer. But quality is uneven — `validate-source-credibility` is mandatory after this.

## Core principle
**Community knowledge supplements official docs, never replaces them.** If a forum answer contradicts official docs, trust docs.

## Inputs

```
TECHNOLOGY: [lib name]
VERSION: [version if relevant]
QUESTION: [specific question]
```

## Process

### 1. StackOverflow

Queries:
- `site:stackoverflow.com <lib> <feature> <version>`
- `site:stackoverflow.com [<lib>] <question>`

Priority signals:
- Accepted answer (green checkmark)
- Answer with > 50 upvotes
- Answer from recognized maintainer

### 2. Reddit

Subs: `r/programming`, stack-specific (`r/typescript`, `r/golang`, `r/reactjs`, etc.)

Priority signals: upvote ratio > 0.9, top comment explains tradeoffs.

### 3. Hacker News

- `site:news.ycombinator.com <lib> <feature>`
- Priority: 100+ points + quality discussion

### 4. dev.to, medium, maintainer blogs

- Recent posts (< 18 months) usually more reliable
- Look for author bio matching lib committer

## Common patterns

### Good forum research

```
## FORUMS RESEARCH — Vitest 3

### StackOverflow
- https://stackoverflow.com/q/12345 — 89 upvotes, accepted — vi.hoisted() required for mock variables in Vitest 3

### Reddit
- https://reddit.com/r/vitest/comments/abc — 45 upvotes, 23 comments — consensus: vi.spyOn > vi.mock for most cases

### CONSENSUS
- Use vi.hoisted() for variables referenced in vi.mock()
- Prefer vi.spyOn over vi.mock for testing interactions

### DISAGREEMENTS
- Whether to use global vs per-test setup: SO says global, Reddit says per-test — depends on test isolation needs
```

### Bad forum research

```
Found some stuff on StackOverflow. People say use vi.mock.
```

Problems: no URLs, no upvote counts, no consensus analysis, no disagreement detection.

## Anti-patterns

- **Credibility not validated** — follow-up with `validate-source-credibility` on any non-official finding
- **Stale answers accepted** — reject if older than 2 years unless fundamentals unchanged
- **Forum > docs** — if forum answer contradicts official docs → trust docs
- **Single-source treated as fact** — one SO answer is a hypothesis, not an answer
- **No cross-reference** — corroborate with at least one other source before treating as fact

## How to verify

- [ ] ≥ 1 forum source found?
- [ ] Each source has URL + upvote/engagement signal?
- [ ] Staleness check performed (< 2 years)?
- [ ] Consensus and disagreements identified?
- [ ] validate-source-credibility will be invoked for non-official findings?

## When triggered

- `researcher` agent when `research-web-sources` and `research-github-issues` didn't resolve
- User asks for "community perspective" or "what do other people do"
- Niche library with sparse docs
