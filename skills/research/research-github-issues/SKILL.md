---
name: research-github-issues
description: Searches github.com/[lib]/issues for error symptoms and library API usage questions, detecting open issues, closed-with-workaround, or PR-in-progress status. Triggered when task involves an external library with a reported symptom (error message, unexpected behavior). Invoked by the researcher agent as parallel research to official docs.
allowed-tools: WebFetch, WebSearch
context: fork
agent: Explore
---

# research-github-issues — GitHub issues prior art

Meta-research skill #2 of 6. When official docs don't cover an edge case, GitHub issues often have the answer — someone else hit the same problem.

---

## Inputs

```
TECHNOLOGY: [lib name + repo path, e.g. "ktor" / "ktorio/ktor"]
VERSION: [exact installed version]
SYMPTOM: [error message OR unexpected behavior description]
```

---

## Process

### 1. Identify the repo

From the lib name, resolve to the GitHub repo:
- `ktor` → `ktorio/ktor`
- `react` → `facebook/react`
- `tanstack-query` → `TanStack/query`

Check `package.json` `repository` field or docs for canonical repo URL.

### 2. Search issues

Queries (via WebSearch or WebFetch on `https://github.com/<repo>/issues?q=`):

- `site:github.com/<repo>/issues <symptom>` 
- `site:github.com/<repo>/issues <feature> <version>`

Include both:
- `is:open` — active, not yet resolved
- `is:closed` — resolved (read how!)

### 3. Classify each relevant issue

For each issue found:

- **Open + active** → known problem, official fix pending → workaround needed now
- **Closed + merged fix** → version N included fix; check if our version is ≥ N
- **Closed with workaround** → apply workaround (cite link)
- **Closed as "not a bug"** → our usage is wrong (read the comment)
- **Closed as duplicate** → follow to the parent issue

### 4. Check linked PRs

If an issue references a PR, check the PR:
- Merged → fix is in release vX.Y
- Draft → fix is in progress
- Closed unmerged → fix abandoned, need workaround

---

## Output format

```
## GITHUB ISSUES RESEARCH — <tech>

### Relevant issues
| # | Title | Status | Our impact |
|---|-------|--------|-----------|
| #1234 | <title> | closed in v3.0.0 | Our version is 3.0.1 — fix included ✓ |
| #5678 | <title> | open | Matches our symptom — apply workaround from comment |
| #9012 | <title> | closed (not a bug) | Our usage is non-idiomatic — refactor needed |

### Workarounds applicable
- <workaround> — source: <issue URL + comment permalink>

### Fix version ranges
- <feature> fixed in <version> — our version: <v>
- If our version < fix version: <suggest upgrade if safe>

### PRs in progress
- <PR #> — <title> — status: <draft | review | merged>

### UNCERTAINTIES
- <unknown — flag for main session>
```

---

## Guardrails

- **Cite with links**: every issue reference needs a URL
- **Check comment consensus**: a single comment doesn't make truth. Look for maintainer response + thumbs up count
- **Version ranges matter**: "fixed in 3.x" could mean 3.0 or 3.5 — read the changelog
- **Don't treat community workaround as gospel**: verify it actually works; prefer official fix
- **Empty result valid**: if no relevant issues found, report "no matches" — don't fabricate

---

## When triggered

- `researcher` agent when TASK mentions a symptom / error message
- Standard/Critical tasks using a library that's not purely internal
- When `research-web-sources` docs are silent on an edge case
- User request: "check if this is a known issue"
