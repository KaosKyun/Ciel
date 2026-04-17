---
name: skill-freshness-auditor
description: Scans every Ciel skill (SKILL.md + reference.md) for stale external references — outdated library version pins, dead URLs, superseded research citations — and produces a freshness patch-set proposing specific rewrites for user approval. Complements `ciel-improve` (transcript-driven) by catching drift from the outside world instead of from observed failures. Never auto-rewrites; always returns a patch-set.
allowed-tools: Read, Grep, Glob, Bash, WebFetch, WebSearch
---

# skill-freshness-auditor — Keep skills current against external reality

Skills age through two channels: (a) **inside** — user corrections, observed failures, truncation (handled by `ciel-improve`); and (b) **outside** — the library you pinned shipped a new major, the official docs URL moved, the research paper you cited was superseded. This skill owns channel (b).

Output is always a proposal — user approves each patch before it writes to disk.

---

## Inputs

- **skills-root**: defaults to `$CIEL_DIR/skills/` (or `./skills/` if running against a clone). Optionally filter via `--scope=<category>` (workflow/research/domain/utility/meta/ciel).
- **freshness-window**: defaults — URLs older than 18 months = warn, library majors older than 12 months = warn, research citations older than 24 months = warn. Overridable.
- **max-patches**: defaults 5 per run (same cap as `ciel-improve`).

---

## Process

### 1. Enumerate skills

```bash
find "$SKILLS_ROOT" -name SKILL.md -o -name reference.md
```

For each file, record path + last-modified time (`git log -1 --format=%ai <path>` if in a repo, else mtime).

### 2. Extract external references

Three categories (grep-based extraction per skill):

| Category | Regex / heuristic | Examples in existing skills |
|---|---|---|
| **URL** | `https?://[^\s)]+` | docs.anthropic.com, cli.github.com, raw.githubusercontent.com |
| **Library + version pin** | `\b([A-Za-z][\w\-./]+)\s+(v?\d+\.\d+(?:\.\d+)?)` OR table rows like `Playwright 1.49` | Vitest, Playwright, React, Ktor, Anthropic SDK |
| **Research citation** | `\b(STRATUS|CriticBench|IdentityChain|ThoughtWorks.*Tech Radar|OWASP Top \d+|WCAG [\d.]+|SLSA Level \d+) (\d{4})` | STRATUS 2024, ThoughtWorks Tech Radar April 2026 |

Store per-skill: `[(category, text, location), ...]`.

### 3. Freshness check per reference

Dispatch three sub-procedures **in parallel** (one per category) to minimize wall-clock:

#### 3a. URL liveness
For each URL:
- `WebFetch url="$URL" prompt="Return just the HTTP status and Last-Modified header if shown."` — ≤ 200 tokens/check.
- Flag if: 404, 301/302 to unrelated domain, OR Last-Modified > freshness-window.

#### 3b. Library version drift
For each library + version pair:
- `WebSearch "<library> latest stable version 2026"` (or current year).
- Extract the latest major/minor from the first 2 results.
- Flag if: pinned major ≠ latest major (breaking-change gap) OR pinned minor < latest - 2 minors.

#### 3c. Research citation recency
For each citation:
- `WebSearch "<name> <year+1 or later> superseded revised v2"` — look for a newer version.
- Flag if: a newer paper/version exists AND is >6 months old (not a preprint hot off the press).

### 4. Produce the freshness patch-set

For each flagged finding, emit ONE patch entry. Format identical to `ciel-improve` patches (reuses that skill's approval UX):

```
## Patch K — skills/<category>/<name>/SKILL.md — FRESHNESS-<subcategory>
Reference: `<exact text>` at line N
Finding: <1 sentence why it's stale — with freshness-source URL>
Severity: HIGH (broken) | MEDIUM (outdated) | LOW (minor)

--- BEFORE (line N)
<old line>
--- AFTER (proposed)
<new line with updated ref>

Approve? [y/n/edit]
```

Per-severity handling:
- **HIGH** (broken): 404 URL, removed-from-npm library → proposed AFTER = best replacement found, or `[BROKEN — resolve manually]` marker
- **MEDIUM** (outdated): version drift 1 major behind, URL still-200-but-redirecting → AFTER = latest pin
- **LOW** (minor): minor-version drift only, research citation 2-3 years old but still current → AFTER = optional bump, or note in `## Last-audited` footer

### 5. Track history

After each approved patch, append a line to `$CIEL_DIR/.freshness-log.jsonl`:

```json
{"ts":"2026-04-17T14:30Z","skill":"skills/workflow/pattern-fitness-check/SKILL.md","ref":"Playwright 1.49","action":"bumped-to-1.53","audit_version":"2.4.5"}
```

Skip re-auditing a ref whose log entry is < freshness-window old (cache hits — saves WebFetch budget across repeated runs).

---

## Output format

```
# Ciel freshness audit — <ISO-8601 timestamp>

Skills scanned: <N>
References extracted: <M>  (URLs: <u>, libs: <l>, citations: <c>)
Cache hits (recent): <h>
Network checks performed: <nc>
Findings: HIGH <h>, MEDIUM <m>, LOW <l>

## Patches proposed (max 5)

## Patch 1 — …
## Patch 2 — …

## Cached (skipped this run — last audit within freshness window)
- <path>:<line> <ref> (last checked <date>)

## Unable to check (network / paywall / ambiguity)
- <path>:<line> <ref> — reason: <timeout | cloudflare | semantic ambiguity>
```

---

## Guardrails

- **Max 5 patches per run** — same cap as `ciel-improve`. Prevents noise; defer rest to next run.
- **Never autonomous rewrite** — every patch waits for `[y/n/edit]`. No exceptions.
- **Never downgrade a pin** — if a skill pins v2 and latest is v3, propose bump; never propose going to v1 based on noise.
- **Version-pin patches must cross-check** — before proposing "bump X from v1.2 to v1.5", fetch v1.5's changelog to ensure the feature the skill relies on still exists. An AI-hallucinated bump that breaks semantics is worse than a slightly-stale pin.
- **Research citation patches require a named superseding work** — never replace a citation with "(outdated)" alone; the new citation must be specific and fetchable.
- **Skip auto-patching `CHANGELOG.md`** — changelogs are append-only history; outdated refs there are a feature, not a bug.
- **Respect `--scope` filter** — if the user asks only for `workflow` skills, don't scan `domain` or `meta`.
- **Cache window override** — `--force` bypasses the 18-month URL cache (rerun everything).

---

## When triggered

- User runs `/ciel-refresh`
- User asks "are any skills stale?" or "check Ciel for outdated references"
- Scheduled monthly (recommended) — drift accumulates silently; a monthly pass keeps it bounded
- Before a major version bump — so the new version ships without stale pins

Do NOT trigger automatically on every task — this is a batched meta operation, ~1-3K tokens per skill scanned. Burns budget if over-invoked.

---

## Relation to other meta skills

- **`ciel-improve`** — transcript-driven; catches failures Ciel experienced. This skill catches reality changes Ciel has not yet tripped over.
- **`skills-first-design-auditor`** — structure-driven; validates frontmatter, length, examples. This skill validates *content currency*, not form.
- **`skill-variant-evaluator`** — A/B scorer. Not invoked here unless a patch is a semantic rewrite (version bump alone doesn't need evaluation).
- **`skill-creator`** — scaffolds new skills. This skill updates existing ones in place.
