---
name: research-github-issues
description: Searches GitHub issues for error symptoms and library API usage questions, detecting open issues, closed-with-workaround, or PR-in-progress status. Triggered when task involves an external library with a reported symptom. Invoked by the researcher agent as parallel research to official docs.
allowed-tools: WebFetch, WebSearch
context: fork
agent: researcher
---

# research-github-issues — GitHub issues prior art

## What this covers
Meta-research skill #2 of 6. When official docs don't cover an edge case, GitHub issues often have the answer — someone else hit the same problem.

## Core principle
**Every bug you encounter, someone else encountered first.** GitHub issues are the world's largest debugging knowledge base. Check before investigating from scratch.

## Inputs

```
TECHNOLOGY: [lib name + repo path, e.g. "ktor" / "ktorio/ktor"]
VERSION: [exact installed version]
SYMPTOM: [error message OR unexpected behavior description]
```

## Process

### 1. Identify the repo

From the lib name, resolve to the GitHub repo. Check `package.json` `repository` field for canonical URL.

### 2. Search issues

Queries (via WebSearch or WebFetch):
- `site:github.com/<repo>/issues <symptom>`
- `site:github.com/<repo>/issues <feature> <version>`

Include both `is:open` and `is:closed`.

### 3. Classify each relevant issue

- **Open + active** → known problem, official fix pending → workaround needed now
- **Closed + merged fix** → version N included fix; check if our version ≥ N
- **Closed with workaround** → apply workaround (cite link)
- **Closed as "not a bug"** → our usage is wrong (read the comment)
- **Closed as duplicate** → follow to the parent issue

### 4. Check linked PRs

If an issue references a PR, check the PR:
- Merged → fix is in release vX.Y
- Draft → fix is in progress
- Closed unmerged → fix abandoned, need workaround

## Common patterns

### Good GitHub issues research

```
## GITHUB ISSUES RESEARCH — @auth/core

### Relevant issues
| # | Title | Status | Our impact |
|---|-------|--------|-----------|
| #1234 | useSession throws on expired tokens | closed in v4.0.1 | Our version is 4.0.0 — upgrade needed |
| #5678 | OAuth callback fails with PKCE | open | Matches our symptom — apply workaround |

### Workarounds applicable
- Add `skipCSRFCheck: true` to OAuth config — source: #5678 comment by maintainer

### Fix version ranges
- useSession fix in v4.0.1 — our version: v4.0.0 — suggest upgrade
```

### Bad research

```
Found some issues. One was closed. Should be fine.
```

Problems: no issue numbers, no status classification, no version check, no workarounds.

## Anti-patterns

- **No links** — every issue reference needs a URL
- **Single comment as truth** — check for maintainer response + consensus
- **Ignoring version ranges** — "fixed in 3.x" could mean 3.0 or 3.5 — read the changelog
- **Treating community workaround as gospel** — verify it works; prefer official fix
- **Empty result fabricated** — if no relevant issues found, report "no matches"

## How to verify

- [ ] ≥ 1 GitHub issue found and classified?
- [ ] Each issue has URL, status, and impact assessment?
- [ ] Version ranges checked (our version vs fix version)?
- [ ] Workarounds documented with source links?
- [ ] Linked PRs checked (merged/draft/closed)?

## When triggered

- `researcher` agent when TASK mentions a symptom / error message
- Standard/Critical tasks using a library that's not purely internal
- When `research-web-sources` docs are silent on an edge case
- User request: "check if this is a known issue"
