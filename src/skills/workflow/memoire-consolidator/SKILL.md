---
name: memoire-consolidator
description: Periodic maintenance of.ciel/memory/ — promotes high-frequency episodes to concepts, merges duplicates, marks stale entries, rebuilds index.json. Run manually or via /ciel-improve. Keeps the cued-recall corpus from accumulating noise as projects age.
---

# Consolidate Cued-Recall Memory

## What this covers

The corpus under `.ciel/memory/` grows over time. Without maintenance it accumulates duplicates, stale entries, and episodes that should have been promoted to stable concepts long ago. This skill is the maintenance pass.

See `skills/workflow/memoire/SKILL.md` for the capture/recall flow and `docs/adrs/0001-cued-recall-memory.md` for the full design.

## When to run

- Manually via `/ciel-improve` or direct invocation
- When `index.json` shows ≥ 50 episodes
- Quarterly on long-lived projects
- After any large bootstrap import (existing tribal docs ingested at once)

## Five operations

### 1. Promote frequent episodes → concepts

Criterion: episode with `trigger_count ≥ 5` AND `last_triggered` within 60 days.

Action: copy episode content to `.ciel/memory/concepts/<slug>.md`, set `captured_from: consolidation` and `promoted_from: [original_id]`. Mark original episode `superseded_by: <new_id>` and exclude from active index.

Why: concepts are stable conventions. Frequent triggers prove the rule has crystallized.

### 2. Merge similar episodes

Criterion: two or more episodes share ≥ 80% of tags AND describe the same lesson (semantic similarity, judged by reading content).

Action: create a new concept that subsumes them, mark all originals `merged_into: <concept_id>`.

Why: bootstrap or rapid capture often produces near-duplicates ("admin routes use admin-guard" + "always wrap admin in admin-guard"). Merging reduces noise without losing the signal.

### 3. Mark stale entries

Criterion: `last_triggered` is older than `stale_after_days` (default 90) OR null + `captured_at` older than 90 days.

Action: set `stale: true` in frontmatter and in `index.json`. Stale entries are excluded from auto-injection but remain on disk.

Why: untriggered memories may be obsolete (the file no longer exists, the convention changed). Auto-injecting them produces false positives.

### 4. Detect dead anchors

Criterion: a memory's `path_patterns` no longer match any file in the repo (deleted module, renamed convention).

Action: flag for human review in `.ciel/memory/review-queue.md`. Don't auto-delete — the user should decide whether the memory is obsolete or needs updated paths.

### 5. Rebuild `index.json`

Always done last. Scans all `*.md` under `.ciel/memory/{episodes,concepts,guards}/`, parses frontmatter, regenerates the cue indices (`by_path`, `by_symbol`, `by_intent`, `by_language`).

This guarantees the index never drifts from source-of-truth (the markdown files).

## Output report

After running, emit a summary:

```
[memoire-consolidator] 2026-05-08
Promoted: 3 episodes → concepts
Merged: 2 episode pairs → 2 concepts
Stale: 7 entries flagged
Dead: 1 anchor needs review (see.ciel/memory/review-queue.md)
Index: rebuilt — 42 active memories, 9 stale, 51 total
```

## Anti-patterns to avoid

| Anti-pattern | Reason |
|---|---|
| Auto-deleting stale entries | User may want to revive; deletion is irreversible. Always flag, never delete. |
| Promoting on first trigger | One trigger isn't crystallization. Wait for repetition. |
| Merging without reading content | Tags may overlap by accident (two different `auth/**` rules). Read before merge. |
| Skipping index rebuild | Drift between index and markdown is worse than missing data — silent corruption. |

## Design principles inherited from ADR-0001

- Markdown is source of truth; index is derived
- User is the filter for irreversible actions (deletion, merge with conflict)
- Decay over accumulation: stale flag is automatic, but action on it is human

## Related skills

- `memoire` — capture/recall flow (writes the inputs this skill consumes)
- `meta-critiquer` — post-task reflection that may trigger consolidation if many captures occurred
- `learnings-capture` — older format, superseded by cued-recall memoire
