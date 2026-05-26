---
name: validate-source-credibility
description: Scores information sources on credibility and freshness — official docs > maintainer blog > GitHub issue > StackOverflow > community forum > random blog. Flags stale content (> 12 months for fast-moving libs). Invoked during research synthesis to rank findings before trusting.
allowed-tools: WebFetch
context: fork
agent: researcher
---

# validate-source-credibility — Rank sources by trust

## What this covers
Meta-research skill #4 of 6. Not all sources are equal. Wrong information confidently presented causes downstream failures. This skill scores every finding before it influences code decisions.

## Core principle
**Credibility is tiered, not binary.** A Tier-1 source (official docs) needs no validation. A Tier-4 source (random blog) is a hypothesis until cross-referenced.

## Inputs

```
SOURCE_URL: [URL of information source]
CLAIM: [what the source says]
TECHNOLOGY: [lib name]
VERSION: [version the claim is about]
```

## Credibility tiers

| Tier | Source | Trust |
|------|--------|-------|
| **1** | Official docs, GitHub release notes, source code | High — always prefer |
| **2** | Maintainer blog, maintainer GitHub discussion, conference talk | High for scope; possible bias |
| **3** | SO accepted (50+ upvotes), GitHub issue with maintainer comment, Reddit consensus | Medium — cross-reference |
| **4** | Random blog, low-upvoted SO, Medium article without credentials | Low — verify against Tier 1/2 |
| **5** | AI-generated content, old tutorials without authorship | Zero — flag, do not follow |

## Freshness thresholds

| Library pace | Max age |
|-------------|---------|
| Fast (React, Next.js, Ktor, Tailwind) | 12 months |
| Medium (Rails, Django, Spring) | 18 months |
| Slow (C, SQL, git) | 36 months |
| Stable fundamentals | 5+ years |

## Process

### 1. Identify tier from URL + content

### 2. Extract publication date

### 3. Compute freshness (fresh / aging / stale)

### 4. Score: Tier + Freshness → FULL / VERIFY / REJECT

## Common patterns

### Good credibility assessment

```
## SOURCE CREDIBILITY — https://blog.example.com/react-19-patterns

Tier: 4 (personal blog, no maintainer credential)
Freshness: aging — published 2025-11-08, 5 months old
Library pace: fast (React)

Credibility signals:
- Author unknown in React contributor list
- No upvote/engagement data available

Trust assessment: VERIFY — cross-reference with official docs before using

Recommendation: Do not trust alone. Verify claim "use() replaces useEffect" against react.dev.
```

### Bad credibility assessment

```
Source looks reliable. Use it.
```

Problems: no tier, no freshness check, no trust assessment.

## Anti-patterns

- **Tier 4/5 trusted alone** — always cross-reference against Tier 1/2
- **Tier 1 overrides common sense** — if docs contradict source code for installed version, flag conflict
- **Age penalized unfairly** — stable fundamentals don't age. A 2017 article on TCP sockets is still correct.
- **Freshness = correctness** — a brand-new blog post can be wrong; an old maintainer article on stable API can be right
- **AI-generated content not detected** — boilerplate patterns, generic structure, no author credentials → suspect

## How to verify

- [ ] Tier assigned (1-5)?
- [ ] Publication date extracted?
- [ ] Freshness assessed against library pace?
- [ ] Trust assessment given (FULL / VERIFY / REJECT)?
- [ ] Recommendation states how main session should treat this source?

## When triggered

- By `synthesize-findings` when merging multi-source research
- On any finding from Tier 3/4/5 before it influences code decisions
- User request: "how reliable is this source?"
