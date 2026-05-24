---
name: memoire
description: Persists project knowledge in Ciel via cued-recall memory (etape 15 MEMOIRE). Captures interventions and decisions into .ciel/memory/{episodes,concepts,guards}/ with index.json mapping cues (paths, symbols, intents) to memories. Replayed automatically when matching cues fire. Replaces the legacy free-recall .ciel/learnings.md blob.
---

# Persist Project Knowledge — Cued-Recall Memory (Ciel v6.5+)

## What this covers

How to save and retrieve project knowledge using **cued recall**: memories tagged with mechanical cues (file paths, symbols, intents) that fire automatically when those cues appear in the next task's context. The model never has to "remember to search" — the system surfaces relevant memory by mechanical match.

See `docs/adrs/0001-cued-recall-memory.md` for the full design rationale.

## Core principle

**Cued recall over free recall.** Don't ask the model "is there relevant memory?" — surface memory automatically when the context cue (file, symbol, intent) matches.

## Three persistence targets

### 1. Episodes — `.ciel/memory/episodes/<YYYY-MM-DD>-<slug>.md`

Dated events: human corrections, incidents, decisions discovered during a task.

Frontmatter:
```yaml
---
id: mem_012
title: Admin routes use admin-guard wrapper
languages: [typescript]
path_patterns:
  - src/admin/**
  - src/pages/admin/**
symbols: [AdminGuard, useAdminGuard]
intents: [new-route, admin]
captured_at: 2026-05-08T14:32:00Z
captured_from: user-intervention  # or: incident, decision, bootstrap
trigger_count: 0
last_triggered: null
stale_after_days: 90
stale: false
---

# Admin routes use admin-guard wrapper

**Context:** when adding a route under `/admin/*`, do not use the standard
auth middleware. Use the project's `admin-guard` wrapper, which adds
audit logging and role-based checks.

**Why:** captured 2026-05-08 after the third incident where standard
middleware allowed read access without role check.

**How to apply:** import from `src/lib/auth/admin-guard.ts`. Wrap the
route handler. See `src/admin/users/page.tsx` for canonical usage.
```

Capture when:
- User corrects the model ("non, on utilise X ici")
- An incident is documented (build broke, prod paged, test flaked for non-obvious reason)
- A non-obvious decision is made (chose lib A over B because constraint C)

### 2. Concepts — `.ciel/memory/concepts/<topic>.md`

Stable conventions promoted from episodes that triggered ≥ N times. Same frontmatter, but with `captured_from: consolidation` and `promoted_from: [mem_012, mem_018]`.

Promotion rule (handled by `memoire-consolidator` skill):
- Episode triggered ≥ 5 times in last 60 days → candidate for promotion
- ≥ 2 episodes share ≥ 80% of tags + similar lesson → candidate for merge

### 3. Guards — `.ciel/memory/guards/<scope>.md`

Vigilance rules with narrow trigger scope and high-severity warnings. Same frontmatter, but with `severity: critical`. Used for:
- Foot-guns (commands that destroy prod)
- Forbidden patterns (editing a deployed migration)
- Mandatory checks before specific actions

## Index — `.ciel/memory/index.json`

The cue → memory mapping. Always loaded by `session-start.sh` at SessionStart.

```json
{
  "version": 2,
  "memories": {
    "mem_012": { "title": "...", "file": "...", "languages": [...], "..." : "..." }
  },
  "by_path": { "src/admin/**": ["mem_012"] },
  "by_symbol": { "AdminGuard": ["mem_012"] },
  "by_intent": { "new-route": ["mem_012"] },
  "by_language": { "typescript": ["mem_012"] }
}
```

The index is rebuilt from frontmatter scans by `memoire-consolidator` whenever a memory is added/updated.

## Capture flow

1. User submits prompt
2. `user-prompt-submit.sh` hook scans for intervention patterns: "tu as oublié", "non en fait", "attention que", "rappelle-toi", "n'oublie pas", "wait", "stop", "non on fait plutôt", "ici on fait plutôt"
3. If matched → emits a context message: "INTERVENTION DETECTED — propose capture"
4. Model surfaces an `AskUserQuestion`: "Capture this correction as memory? [Title / Tags suggested / Skip]"
5. User confirms or skips
6. On confirm → write `.ciel/memory/episodes/<date>-<slug>.md`, update `index.json`

**Never auto-silent.** The user is the filter against cargo-cult capture.

## Recall flow

1. SessionStart or new task begins
2. `session-start.sh` hook reads:
   - The user's prompt (extract keywords → intent cues)
   - `.ciel/map.json` (current focus modules → path cues)
   - Recently tracked files (`.ciel/tracked-files.json`) → path + symbol cues
3. Queries `index.json`: cues ∩ memories → candidate set
4. Scores by: `recency × trigger_count × tag-overlap`
5. Selects top-K under depth budget (Trivial 1K / Standard 3K / Critical 5K tokens)
6. Injects one-line previews:
   ```
   [mem_012, fired 7×] Admin routes use admin-guard wrapper
   [mem_007, fired 3×] Migration files are checksum-locked
   ```
7. Model can `Read` full content if relevant (cued exploration, not blanket dump)

## Bootstrap from existing docs

On first run, the slash command `/ciel-memory-bootstrap` ingests:

| Source | Format expected |
|---|---|
| `.ciel/learnings.md` | Legacy Ciel format with `[date] MISTAKE/RULE` entries |
| `.claude/lessons.md` or `lessons.md` | Same as above |
| `ciel-overlay.md` | "Key Lessons" section |
| `.claude/rules/*.md` | Each file = one rule |
| `AGENTS.md` | Rules sections |

Each ingested item becomes an episode with `captured_from: bootstrap`. Tags are inferred from content (file paths mentioned, symbols mentioned, language detected from imports).

If no source is found, the system reports it and waits for organic capture via interventions.

## Decay

- `last_triggered` is updated by `session-start.sh` whenever a memory is matched and injected
- After `stale_after_days` (default 90) without trigger → `stale: true`
- Stale memories excluded from auto-injection but kept on disk
- Skill `memoire-consolidator` periodically suggests purge or refresh

## Token budget (hard caps)

| Depth | Cap |
|---|---|
| Trivial | 1K tokens injected |
| Standard | 3K tokens injected |
| Critical | 5K tokens injected |

If candidate set exceeds cap, drop lowest-scoring entries first. Index itself is small (~50 tokens per entry); the cap concerns content previews and any auto-loaded full content.

## Common rationalizations

| Rationalization | Reality |
|---|---|
| "I'll remember this next session" | You won't. Even if you do, the next agent session won't. Capture or it's gone. |
| "The user corrected me, but it was obvious" | The fact that you missed it makes it non-obvious. Capture. |
| "All this is in CLAUDE.md already" | CLAUDE.md is loaded once and diluted by lost-in-the-middle (Liu 2023). Cued memory bypasses that. |
| "Capturing slows the user down" | One confirmation now vs. the same intervention next month. The math favors capture. |

## What to persist vs what to skip

PERSIST (becomes a memory):
- User corrections that aren't obvious from reading the code
- Incidents (what broke, root cause, fix that worked)
- Architecture decisions with their motivation
- Foot-guns (commands/patterns to avoid in this project)
- Wrappers / conventions that override library defaults

SKIP (don't pollute the corpus):
- The code itself (it's in git)
- Routine task completion ("I added a button")
- Anything trivially derivable by reading the file
- Personal style preferences (those go in `ciel-overlay.md`)

## How to verify (etape MEMOIRE)

- [ ] Did this session contain a user intervention/correction? If yes, was it captured?
- [ ] Did this session document a new pattern, foot-gun, or convention? If yes, episode created?
- [ ] Was the index.json updated by the capture flow?
- [ ] Are tags reasonable (paths actually exist, symbols are real)?
- [ ] If the same correction came up next month, would the cued recall fire? (Mental dry-run.)

## Migration from legacy `.ciel/learnings.md`

The legacy single-blob `learnings.md` is kept for backward compatibility but **deprecated**. New writes should go to `.ciel/memory/episodes/` via the capture flow. Run `/ciel-memory-bootstrap` to migrate existing entries — it parses the dated entries and converts each into an episode with inferred tags.

## Related

- `docs/adrs/0001-cued-recall-memory.md` — full design rationale and binding principles
- `skills/workflow/memoire-consolidator` — periodic maintenance: promote, merge, decay
- `commands/ciel-memory-bootstrap.md` — first-run scan + ingestion
- `hooks/user-prompt-submit.sh` — detects intervention patterns and proposes capture
- `hooks/session-start.sh` — injects matching memories at session start
