---
name: validate-source-credibility
description: Scores information sources on credibility and freshness — official docs > maintainer blog > GitHub issue/PR > StackOverflow accepted answer > community forum > random blog. Flags stale content (> 12 months for fast-moving libs, > 24 months for stable). Invoked during research synthesis to rank findings before trusting them.
allowed-tools: WebFetch
context: fork
agent: Explore
---

# validate-source-credibility — Rank sources by trust

Meta-research skill #4 of 6. Not all sources are equal. Wrong information confidently presented causes downstream failures.

---

## Inputs

```
SOURCE_URL: [URL of information source]
CLAIM: [what the source says — specific claim being evaluated]
TECHNOLOGY: [lib name]
VERSION: [version the claim is about]
```

---

## Credibility tiers

### Tier 1 — Official / primary source
- Official library documentation at `<lib>.org` / `<lib>.dev`
- Official GitHub release notes
- Library source code (reading the implementation)
- **Trust: high. Always prefer.**

### Tier 2 — Maintainer-authored
- Maintainer blog post / dev.to / medium article (author is a committer on the repo)
- Official library GitHub discussion with maintainer response
- Conference talk by a maintainer (recent)
- **Trust: high for the claim's scope; may have maintainer bias toward their preferred approach.**

### Tier 3 — Well-engaged community
- StackOverflow answer: accepted + > 50 upvotes + recent
- GitHub issue with maintainer comment confirming approach
- Reddit thread with clear consensus (high upvote ratio)
- **Trust: medium. Cross-reference with Tier 1/2.**

### Tier 4 — Individual community contributors
- Random blog post by non-maintainer
- Medium / dev.to article without maintainer credential
- Low-upvoted SO answer
- **Trust: low. Treat as hypothesis, verify against Tier 1/2.**

### Tier 5 — Unverified
- AI-generated content (detected via boilerplate patterns)
- Old tutorials / screencasts without clear authorship
- **Trust: zero. Flag, do not follow.**

---

## Freshness thresholds

| Library evolution pace | Max age acceptable |
|------------------------|--------------------|
| Fast-moving (React, Next.js, Ktor, Tailwind, TanStack) | 12 months |
| Medium (Rails, Django, Spring) | 18 months |
| Slow (C, SQL, git) | 36 months |
| Stable fundamentals (algorithms, data structures) | 5+ years |

Older sources: flag but don't auto-reject — sometimes fundamentals don't change.

---

## Process

### 1. Identify tier from URL

Parse URL + optional page content:
- Domain `<lib>.org` → Tier 1
- `github.com/<lib-org>/<lib>/issues` → Tier 3 (maintainer comment = Tier 2)
- `stackoverflow.com` → Tier 3 or 4 (check upvotes)
- Random blog → Tier 4 or 5

### 2. Extract date

Find the publication date (HTML `datePublished` meta tag, visible byline, or "Last updated" footer).

### 3. Compute freshness

Compare date vs current date vs library pace. Return: fresh / aging / stale.

### 4. Score

Combined score:
- Tier 1/2 + fresh → full trust
- Tier 1/2 + stale → verify current version still behaves this way
- Tier 3 + fresh → cross-reference with Tier 1/2
- Tier 3 + stale → hypothesis, verify
- Tier 4/5 → reject or verify against higher tier

---

## Output format

```
## SOURCE CREDIBILITY — <URL>

Tier: <1 / 2 / 3 / 4 / 5>
Freshness: <fresh | aging | stale> — <publication date, age>
Library pace: <fast | medium | slow>

Credibility signals:
- <signal: e.g. "maintainer-authored per GitHub profile"> 
- <signal: e.g. "accepted answer with 200 upvotes">

Trust assessment: <FULL | VERIFY | REJECT>

Recommendation: <how main session should treat this source>
```

---

## Guardrails

- **Never trust a Tier 4/5 source alone** — always cross-reference against Tier 1/2
- **Tier 1 doesn't override common sense**: if official docs say something that contradicts repository source code for the installed version, flag the conflict
- **AI-generated content detection**: boilerplate patterns, generic structure, recent publication without author credentials → suspect
- **Don't penalize age when appropriate**: for stable fundamentals, a 2017 article on TCP sockets is still correct
- **Freshness ≠ correctness**: a brand-new blog post can be wrong; an old maintainer article on stable API can be right

---

## When triggered

- By `synthesize-findings` skill when merging multi-source research
- On any finding from Tier 3/4/5 before it influences code decisions
- User request: "how reliable is this source?"
