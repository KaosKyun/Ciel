---
name: research-forums
description: Fallback research source when official docs and GitHub issues are silent — searches StackOverflow, Reddit (r/programming, stack-specific subs), Hacker News, and dev.to for community discussion on a technology question. Source diversity reduces docs-echo bias. Lower priority than research-web-sources (official) and research-github-issues (primary) but still valuable for edge cases.
allowed-tools: WebSearch
context: fork
agent: Explore
---

# research-forums — Community discussion fallback

Meta-research skill #3 of 6. When official docs + GitHub issues don't resolve the question, community forums often have the answer. But quality is uneven — `validate-source-credibility` is mandatory after this.

---

## Inputs

```
TECHNOLOGY: [lib name]
VERSION: [version if relevant]
QUESTION: [specific question]
```

---

## Process

### 1. StackOverflow

Queries:
- `site:stackoverflow.com <lib> <feature> <version>`
- `site:stackoverflow.com [<lib>] <question>` (uses SO tag syntax)

Priority signals:
- Accepted answer (green checkmark)
- Answer with > 50 upvotes
- Answer from recognized maintainer (blue badge, lib author in profile)

### 2. Reddit

Subs to check:
- `r/programming` (general)
- Stack-specific: `r/typescript`, `r/golang`, `r/rust`, `r/Kotlin`, `r/reactjs`, `r/node`, etc.

Queries:
- `site:reddit.com/r/<sub> <lib> <feature>`

Priority signals:
- Upvote ratio > 0.9
- Top comment explains tradeoffs (not just "use X")
- Discussion includes both sides of the question

### 3. Hacker News

- `site:news.ycombinator.com <lib> <feature>`
- Check for recent (< 2 years) discussions on the library or problem

Priority: submissions that got 100+ points + quality discussion in comments.

### 4. dev.to, medium, maintainer blogs

- Search for maintainer-authored articles (look for author bio matching lib committer)
- Recent posts (< 18 months) usually more reliable

---

## Output format

```
## FORUMS RESEARCH — <tech>

### StackOverflow
- <answer URL> — <N upvotes, accepted?> — <summary>

### Reddit
- <thread URL> — <upvotes / comments> — <summary>

### Hacker News
- <submission URL> — <points / date> — <summary>

### Blogs / dev.to
- <article URL> — <author + credibility signal> — <summary>

### CONSENSUS (what multiple sources agree on)
- <consensus point 1>
- <consensus point 2>

### DISAGREEMENTS (sources conflict — investigate)
- <point>: <source A says X, source B says Y>

### UNCERTAINTIES
- <unresolved question>
```

---

## Guardrails

- **Source credibility is MANDATORY**: follow-up with `validate-source-credibility` on any non-official finding before trusting
- **Date everything**: stale forum answers are common. Reject if older than 2 years unless fundamentals haven't changed.
- **Community vs official**: if forum answer contradicts official docs → trust docs
- **Beware single-source**: if only one person on StackOverflow claims X works, it's a hypothesis, not an answer
- **Cross-reference**: forum answer should corroborate with at least one other source (another SO answer, a doc snippet, a blog post) before being treated as fact

---

## When triggered

- `researcher` agent when `research-web-sources` and `research-github-issues` didn't resolve the question
- User asks for "community perspective" or "what do other people do"
- When a task involves a niche library with sparse docs
