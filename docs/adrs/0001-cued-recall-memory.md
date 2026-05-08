# ADR-0001 — Cued-Recall Memory for Project Knowledge

**Status**: Accepted
**Date**: 2026-05-08
**Context**: Ciel v6.4.x → cued-recall memory system design

## Context

Ciel is a deep-reasoning orchestrator for coding agents. After empirical audit (see explorer audit on Neiyomi, 2026-05-08), three observations converged:

1. **Most of Ciel is already an amplifier (~75%)** — subagents, hooks, Read/Grep enforcement, WebFetch, external memory. The colonne vertébrale exploits real harness capabilities to compensate documented LLM blind spots (sycophancy, lost-in-the-middle, package hallucination, premature closure).

2. **Three pipeline steps remain reminders** — DIVERGE, QUOI, META. They ask the model to "think harder" without leveraging any harness capability. They are procedural compliance dressed as reasoning.

3. **Human intervention is the unreplaced gap** — even with all amplifiers, the user repeatedly tells the agent project-specific rules ("we use admin-guard wrapper here", "this migration pattern requires patching three writers"). These corrections encode tribal knowledge that no generic catalog can cover. They are the most valuable signal in the system, and they are currently lost between sessions.

The first two observations imply that Ciel needs a META that produces persistable artefacts, not introspection. The third implies that captured human corrections must be replayed when relevant — automatically, not on the model's volition.

## Decision

Adopt **cued recall** as the architectural principle for project memory.

### Definition

**Free recall**: ask the model "is there relevant memory?". Requires either dumping all memory (token-suicide) or trusting the model to search (forgotten in 8/10 cases).

**Cued recall**: when context provides a cue (file path, symbol, intent), the system **automatically surfaces** matching memories. The cue exists mechanically in the task; no cognitive effort is required from the model.

This mirrors how human memory actually works (Tulving, 1973). It is also fundamentally token-efficient: only relevant memories enter context, never the full corpus.

### Architecture

```
.ciel/memory/
├── index.json          # cue → memory_id mapping (always loaded, ~1-3K tokens)
├── episodes/           # dated events: corrections, incidents, decisions
│   └── 2026-05-08-admin-guard.md
├── concepts/           # stable conventions promoted from frequent episodes
│   └── auth-routes-convention.md
└── guards/             # vigilance rules, narrowly scoped triggers
    └── migration-immutability.md
```

### Schema (`index.json` v2)

```json
{
  "version": 2,
  "memories": {
    "mem_012": {
      "title": "Admin routes use admin-guard wrapper",
      "file": "concepts/admin-routes-convention.md",
      "languages": ["typescript"],
      "path_patterns": ["src/admin/**", "src/pages/admin/**"],
      "symbols": ["AdminGuard", "useAdminGuard"],
      "intents": ["new-route", "admin"],
      "trigger_count": 7,
      "last_triggered": "2026-05-01T10:23:00Z",
      "stale_after_days": 90,
      "stale": false
    }
  },
  "by_path": { "src/admin/**": ["mem_012"] },
  "by_symbol": { "AdminGuard": ["mem_012"] },
  "by_intent": { "new-route": ["mem_012", "mem_034"] },
  "by_language": { "typescript": ["mem_012", "mem_034"] }
}
```

### Four loops

1. **Encode (capture)** — `UserPromptSubmit` hook detects intervention patterns ("tu as oublié", "non en fait", "attention que", "rappelle-toi", "wait", "stop", "non on fait plutôt"). When matched, emits a context message proposing capture. The model surfaces a confirmation question to the user ; user validates title + tags or skips. **Never auto-silent** — keeps the user as the filter. Writes `.ciel/memory/episodes/<YYYY-MM-DD>-<slug>.md` and updates `index.json`.

2. **Retrieve (recall)** — `SessionStart` hook scans the prompt + tracked files + map.json to derive cues (paths, symbols, intent keywords). Queries `index.json` for matching memories. Selects top-K by recency × trigger_count, capped by depth budget (Trivial 1K / Standard 3K / Critical 5K tokens). Injects one-line previews; the model can `Read` full content via cued exploration.

3. **Consolidate** — `memoire-consolidator` skill (manual or on `/ciel-improve`) finds episodes with overlapping tags + similar lessons → merges into a `concept`. Promotes high-frequency triggers into "core conventions" (always loaded for matching files).

4. **Decay** — `last_triggered` decays. After `stale_after_days` without activation, entry flagged `stale: true`, excluded from auto-injection. Stays on disk for human review. Skill `memoire-consolidator` periodically suggests purge or refresh.

### Bootstrap

A first run on an existing project would start empty. To avoid that, the system **ingests existing tribal docs**:

- `.ciel/learnings.md` (legacy Ciel format)
- `.claude/lessons.md` or `lessons.md`
- `ciel-overlay.md` "Key Lessons" sections
- `.claude/rules/*.md`
- `AGENTS.md` rules sections

The slash command `/ciel-memory-bootstrap` performs this scan, reports findings, and prompts ingestion. If nothing is found, the system populates organically via captures.

### Token budget

Hard caps by depth:
- Trivial: 1K tokens of memory injected
- Standard: 3K tokens
- Critical: 5K tokens

Index lookups are O(1) via `index.json`. Memory contents are read on-demand by the model, not blanket-injected. Decay reclaims tokens automatically as memories age out.

## Consequences

### Positive

- META becomes a real amplifier: writes to `.ciel/memory/episodes/` from session-end + scans the conversation for missed interventions to retroactively capture.
- Human intervention burden decreases over time as the corpus accumulates project-specific knowledge.
- Token cost stays flat as corpus grows (cued injection caps the budget; index entries are cheap; decay reclaims).
- Knowledge becomes transferable: a new contributor (or a fresh session) starts with the project's accumulated tribal knowledge auto-injected.
- Markdown + JSON keeps the system human-readable and editable. Compatible with Obsidian, Logseq, Foam via `[[wikilinks]]` convention.

### Negative

- Adds capture friction: user must validate proposed captures (mitigation: confirmation can be skipped, system never blocks).
- Risks duplication with existing `lessons.md` / `learnings.md` (mitigation: bootstrap script ingests rather than competes; dedup via title hash).
- Bad tags → bad recall (mitigation: tags suggested by hook based on detected file/symbol context, validated by user).
- `src/lib/`-style kitchen-sink directories over-fire path cues (mitigation: combined path + symbol matching for memories tagged broadly).

### Neutral

- Adds ~400 lines to Ciel codebase (hooks + skill updates + bootstrap script + slash command + ADR).
- New file structure under `.ciel/memory/` — gitignored as local state, like other `.ciel/` artefacts.

## Design principles (binding for future evolution)

These principles guard against future drift back to free recall or blanket injection:

1. **Cued recall over free recall** — never ask the model "is there relevant memory ?". Surface memory automatically based on mechanical context cues.

2. **Confirmation over auto-silent** — captures require user validation. Cargo-cult accumulation is worse than gaps.

3. **Markdown over database** — the corpus must remain human-readable, editable, portable. A vector DB or external store may be added LATER as an indexing layer above markdown, never as a replacement.

4. **Token cap by design** — every injection path has a hard cap. Adding new cue types must not bypass the cap.

5. **Decay over accumulation** — untriggered memories become stale automatically. The system self-cleans.

6. **Bootstrap over greenfield** — new installations on existing projects ingest existing tribal docs first. We don't compete with what users already maintain.

## Alternatives considered

- **Vector DB from day one** — rejected: corpus too small to justify; opaque to user; lock-in risk.
- **Auto-silent capture** — rejected: leads to cargo-cult accumulation; user filter is essential.
- **Free recall via tool** — rejected: model forgets to search; doesn't know what it doesn't know.
- **Dumping all memory at session start** — rejected: violates token budget; lost-in-the-middle dilutes signal.

## References

- Tulving, E. (1973). *Cued recall and free recall*. Journal of Experimental Psychology.
- Liu et al. 2023, *Lost in the Middle: How Language Models Use Long Contexts*. arxiv.org/abs/2307.03172
- Sharma et al. 2023, *Towards Understanding Sycophancy in Language Models*. arxiv.org/abs/2310.13548
- Spracklen et al. 2024, *We Have a Package for You! Hallucinated Packages*. arxiv.org/abs/2406.10279
- Wang et al. 2024, *Rethinking the Bounds of LLM Reasoning*. arxiv.org/abs/2402.18272

## Related ADRs

- (none yet — first ADR in this repo)
