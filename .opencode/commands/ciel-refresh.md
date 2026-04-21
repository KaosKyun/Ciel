---
description: Scan Ciel skills for stale references (outdated versions, dead URLs, superseded citations). Produces freshness patch-set for user approval.
---

# /ciel-refresh — Freshness audit over the skill library

*Runs the `skill-freshness-auditor` meta-skill to surface stale external references across every Ciel skill and propose concrete updates.*

Usage: `/ciel-refresh [scope] [--force]`

- `scope` defaults to `all`. Other scopes: `workflow`, `research`, `domain`, `utility`, `meta`, `ciel`, or a specific skill name like `skill=debug-reasoning-rca`.
- `--force` bypasses the 18-month URL cache (re-checks every reference even if it was checked recently).

---

## What it does

1. Enumerates every `SKILL.md` and `reference.md` under `$CIEL_DIR/skills/` (or the filtered scope).
2. Extracts three categories of external refs:
   - **URLs** (any `http(s)://...`)
   - **Library + version pins** (e.g., `Playwright 1.49`, `React 19`, `Ktor 3.1`)
   - **Research citations** (e.g., `STRATUS 2024`, `ThoughtWorks Tech Radar April 2026`, `OWASP Top 10`, `WCAG 2.2`)
3. For each ref, runs a freshness check:
   - URL → `WebFetch` to confirm 200 OK + Last-Modified within the window
   - Library → `WebSearch` for latest stable, compare to the pinned version
   - Citation → `WebSearch` for a named superseding work
4. Produces a `freshness patch-set` — one entry per stale ref, with severity HIGH/MEDIUM/LOW and a proposed rewrite.
5. Waits for user approval on each patch (`[y/n/edit]`), then applies only the approved ones.
6. Logs the audit to `$CIEL_DIR/.freshness-log.jsonl` so future runs can skip refs that were checked recently.

---

## Severity levels

| Severity | Trigger | Example |
|---|---|---|
| **HIGH** | Broken (404 URL, removed-from-npm library) | `https://defunct-docs.example.com/api` returns 404 |
| **MEDIUM** | Outdated (lib 1 major behind, URL redirecting away) | Skill pins `Playwright 1.49`, latest is `2.3` |
| **LOW** | Minor drift (minor-version gap, citation 2-3 years old) | Skill cites `OWASP Top 10 2021`, current is `2025` |

---

## Output example

```
# Ciel freshness audit — 2026-04-17T14:30Z

Skills scanned: 48
References extracted: 127  (URLs: 62, libs: 44, citations: 21)
Cache hits (recent): 41
Network checks performed: 86
Findings: HIGH 2, MEDIUM 5, LOW 3

## Patch 1 — skills/workflow/playwright-visual-critic/SKILL.md — FRESHNESS-lib
Reference: `Playwright 1.49` at line 28
Finding: Latest stable is Playwright 2.3.1 (released 2026-02) — 2 majors behind.
Severity: MEDIUM

--- BEFORE (line 28)
Uses Playwright 1.49 MCP server for browser automation.
--- AFTER (proposed)
Uses Playwright 2.3.1 MCP server for browser automation (breaking changes vs 1.x: see https://playwright.dev/docs/release-notes#2.0).

Approve? [y/n/edit]
```

---

## When to run

- **Monthly routine** — drift accumulates silently; a batched pass keeps it bounded.
- **Before a major version bump** — so the new release ships without stale pins.
- **After a major upstream release** (Claude Code, OpenCode, Anthropic API) — their docs URLs may have moved.
- **After a long quiet period** on a specific skill — add `scope=skill=<name>` to hit just that one.

Avoid running on every task — a full scan burns ~1-3K tokens per skill (WebFetch + WebSearch).

---

## Cost

Typical full run (~50 skills) consumes 100-300K tokens depending on how many cached vs new checks. Cheaper after the first run (cache hits dominate). Projected cost is displayed before the network phase — abortable.

---

## Relation to other `/ciel-*` commands

- **`/ciel-improve`** — transcript-driven; catches what Ciel *experienced*. `/ciel-refresh` catches what *changed outside* Ciel.
- **`/ciel-eval`** — benchmarks skill variants on fixed datasets. `/ciel-refresh` doesn't grade quality, just currency.
- **`/ciel-audit`** — session-level violations. `/ciel-refresh` is library-level drift.
- **`/ciel-create-skill`** — scaffolds new. `/ciel-refresh` updates existing.
