---
description: ---
subtask: false
---

---
description: Scan project for ingestable tribal docs (lessons.md, ciel-overlay.md, .claude/rules/, etc.) and propose ingestion into the cued-recall memory under .ciel/memory/. Reports findings if no sources found. Always confirms each candidate with the user before writing.
---

# /ciel-memory-bootstrap — Initialize Cued-Recall Memory

**Purpose:** First-run scan of an existing project to convert tribal knowledge already documented in `lessons.md`, `ciel-overlay.md`, `.claude/rules/`, and similar files into the structured cued-recall memory at `.ciel/memory/`.

**Usage:** `/ciel-memory-bootstrap` (no args)

This is **deterministic**: no agent dispatch, no pipeline, no DIVERGE/EVALUER. Just scan, propose, write on user confirmation.

---

## Instructions

You are bootstrapping the cued-recall memory for this project. Follow these steps in order.

### Step 1 — Scan

Run the bootstrap script in `scan` mode:

```bash
bash "$HOME/.ciel/hooks/memory-bootstrap.sh" scan
```

If `$CLAUDE_PROJECT_DIR` is set: `bash "$CLAUDE_PROJECT_DIR/hooks/memory-bootstrap.sh" scan`.

Report the output verbatim to the user.

### Step 2 — Decide path

- **If 0 sources found** → tell the user clearly: "No tribal docs to bootstrap from. The cued-recall memory will populate organically as you intervene with me. Nothing more to do." End here.
- **If sources found** → proceed to Step 3.

### Step 3 — Initialize structure

Run:

```bash
bash "$HOME/.ciel/hooks/memory-bootstrap.sh" ingest
```

This creates `.ciel/memory/{episodes,concepts,guards}/` and an empty `index.json`. It does NOT auto-write memories.

### Step 4 — Read each source

For each source found in Step 1, `Read` the file fully. Identify candidate memories:

| Source format | What becomes a memory |
|---|---|
| `[YYYY-MM-DD] MISTAKE: X → RULE: Y` lines | One memory per line. Title = the rule. |
| `## Heading\n\n- rule\n- rule` | One memory per rule. |
| Numbered lessons in `ciel-overlay.md` "Key Lessons" | One memory per lesson. |
| `## section` in CLAUDE.md/AGENTS.md describing a non-obvious convention | One memory per section. |

Skip pipeline/workflow descriptions, general principles already in CLAUDE.md, project descriptions, code examples.

### Step 5 — Propose batch capture

Present all candidates **as a batch** with the `question` tool. For each candidate show: title, source (file:line), suggested tags. User replies with: "all", specific indices, or "skip".

### Step 6 — Write captured memories

For each captured candidate, create `.ciel/memory/episodes/<YYYY-MM-DD>-<slug>.md` with frontmatter (id, title, languages, path_patterns, symbols, intents, captured_at, captured_from: bootstrap, source, trigger_count: 0, last_triggered: null, stale_after_days: 90, stale: false). Slug = first 5 words of title, kebab-cased.

### Step 7 — Rebuild index

Regenerate `.ciel/memory/index.json` by scanning all frontmatter under `.ciel/memory/`:
- memories: id → metadata
- by_path / by_symbol / by_intent / by_language: cue → [ids]

### Step 8 — Confirm

Report N captured, sources processed, index size. Suggest re-running `/ciel-memory-bootstrap` later to pick up new tribal docs.

---

## Constraints

- Never write a memory without user confirmation.
- Do not delete source files.
- Tag conservatively — narrow path patterns over broad globs.
- No agent dispatch — runs inline.
- Idempotent — detect existing memories by source field, offer skip on duplicates.

## See also

- `docs/adrs/0001-cued-recall-memory.md`
- `skills/workflow/memoire/SKILL.md`
- `skills/workflow/memoire-consolidator/SKILL.md`
