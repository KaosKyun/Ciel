---
name: synthesize-findings
description: Merges outputs from research-web-sources, research-github-issues, and research-forums into a single structured report with FINDINGS / ANTI-PATTERNS / PHILOSOPHY / API SURFACE / UNCERTAINTIES sections. Cross-references conflicting claims (e.g. stale forum vs fresh docs — trust docs) and deduplicates. Produces the final research deliverable the researcher agent returns to the main session.
---

# synthesize-findings — Merge research into one report

Meta-research skill #5 of 6. After parallel research skills have produced raw findings, this skill merges them into the single canonical format that the `researcher` agent returns.

---

## Inputs

```
WEB_RESULTS: [output of research-web-sources — or "none"]
GITHUB_RESULTS: [output of research-github-issues — or "none"]
FORUM_RESULTS: [output of research-forums — or "none"]
CREDIBILITY_SCORES: [output of validate-source-credibility for low-tier sources]
```

---

## Process

### 1. Deduplicate

Same claim from multiple sources → merge, cite all sources ordered by credibility tier (highest first).

### 2. Resolve conflicts

When two sources disagree:

- Higher credibility tier wins (official docs > forum)
- Newer wins among same tier
- If both are recent Tier 1 but disagree: flag as uncertainty
- If version-specific: align to installed version

### 3. Populate canonical sections

- **FINDINGS**: positive statements with version + source
- **ANTI-PATTERNS À ÉVITER**: what NOT to do, with reason + source
- **PHILOSOPHY DU FRAMEWORK**: how the framework wants this solved (1-2 sentences)
- **API SURFACE**: verified imports / signatures / DB columns / response shapes
- **INCERTITUDES**: unresolved questions, flagged conflicts, version gaps

### 4. Apply credibility filter

Any finding sourced only from Tier 4/5 without Tier 1/2 cross-reference → demote to UNCERTAINTY (with source annotation).

### 5. Enforce minimum gate

Output is incomplete if ANY of:
- 0 findings
- 0 anti-patterns
- No philosophy statement
- No version stamp on any finding

Report incomplete → return warning to researcher agent.

---

## Output format

```
## FINDINGS
- <finding with version + source URL>
- <finding>

## ANTI-PATTERNS À ÉVITER
- <anti-pattern> — <reason> — <source URL>

## PHILOSOPHY DU FRAMEWORK
<1-2 sentences>

## API SURFACE (verified)
- <import/function verified at: URL or file:line>
- <DB columns verified: migration:line or pg_attribute>
- <response format verified: source>

## INCERTITUDES
- <unresolved question>
- <version gap: docs are for v3.0, installed is v3.1 — unclear if X still applies>
- <conflict: docs say X, GitHub issue #123 says Y — investigate>
```

---

## Guardrails

- **Never invent findings**: if research skills didn't produce a finding for a category, leave it empty; don't fabricate
- **Always cite**: every finding, anti-pattern, API surface claim has a URL or file:line
- **Uncertainties are valuable**: empty UNCERTAINTIES section is suspicious — research rarely resolves everything
- **Output budget**: ≤ 500 tokens (the researcher agent returns this to main session — stay compact)
- **No preamble, no conclusion**: structured report only

---

## When triggered

- By `researcher` agent at the end of its research pipeline
- User request: "summarize research findings on X"
