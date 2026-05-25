---
description: ---
subtask: false
---

---
description: Scan project for ingestable tribal docs (lessons.md, ciel-overlay.md, .claude/rules/, Claude Code auto-memory at ~/.claude/projects/<slug>/memory/, etc.) and propose ingestion into the cued-recall memory under .ciel/memory/. Reports findings if no sources found. Always confirms each candidate with the user before writing.
---

# /ciel-memory-init — Initialize Cued-Recall Memory

**Purpose:** First-run scan of an existing project to convert tribal knowledge already documented in `lessons.md`, `ciel-overlay.md`, `.claude/rules/`, Claude Code's per-project auto-memory (`~/.claude/projects/<slug>/memory/`), and similar files into the structured cued-recall memory at `.ciel/memory/`.

**Usage:** `/ciel-memory-init` (no args)

This is **deterministic**: no agent dispatch, no pipeline, no DIVERGE/EVALUER. Just scan, propose, write on user confirmation.

---

## Instructions

You are bootstrapping the cued-recall memory for this project. Follow these steps in order.

### Step 1 — Scan

Run the bootstrap script in `scan` mode:

```bash
# Try installed location first, fallback to dev location
script="$CLAUDE_PROJECT_DIR/.claude/hooks/memory-bootstrap.sh"
[ -f "$script" ] || script="$CLAUDE_PROJECT_DIR/hooks/memory-bootstrap.sh"
bash "$script" scan
```

Or, if running on an installed Ciel: `bash "$HOME/.ciel/hooks/memory-bootstrap.sh" scan`.

Report the output verbatim to the user.

### Step 2 — Decide path

Based on the scan output:

- **If 0 sources found** → tell the user clearly: "No tribal docs to bootstrap from. The cued-recall memory will populate organically as you intervene with me. Nothing more to do." End here.
- **If sources found** → proceed to Step 3.

### Step 3 — Initialize structure

Run:

```bash
script="$CLAUDE_PROJECT_DIR/.claude/hooks/memory-bootstrap.sh"
[ -f "$script" ] || script="$CLAUDE_PROJECT_DIR/hooks/memory-bootstrap.sh"
bash "$script" ingest
```

This creates `.ciel/memory/{episodes,concepts,guards}/` and an empty `index.json`. It does NOT auto-write memories — auto-ingestion would create cargo-cult entries from possibly-stale docs (see ADR-0001).

### Step 4 — Read each source

For each source found in Step 1, `Read` the file fully. Identify candidate memories:

| Source format | What becomes a memory |
|---|---|
| `[YYYY-MM-DD] MISTAKE: X → RULE: Y` lines (lessons.md style) | One memory per line. Title = the rule. |
| `## Heading\n\n- rule\n- rule` (rules.md style) | One memory per rule. |
| Numbered lessons in `ciel-overlay.md` "Key Lessons" | One memory per lesson. |
| `## section` in CLAUDE.md/AGENTS.md describing a non-obvious convention | One memory per section. |
| **Claude Code auto-memory** entries (`~/.claude/projects/<slug>/memory/*.md`, excluding `MEMORY.md`) | One memory per file. Title = frontmatter `description`. Cues derived per "Auto-memory mapping" below. |

#### Auto-memory mapping (special parser)

Claude Code auto-memory uses a different frontmatter than Ciel's cued-recall. Each source file looks like:

```yaml
---
name: feedback-okhttp-cookiejar-override
description: Neiyomi shared PersistentCookieJar overrides manual Cookie headers via OkHttp BridgeInterceptor
metadata:
  type: feedback
---

(body markdown — Context / Why / How to apply sections)
```

When you encounter a file under `$AUTO_MEMORY_DIR`, map it to a Ciel episode as follows:

| Auto-memory field | Ciel frontmatter field | Notes |
|---|---|---|
| `description:` | `title:` | one-line summary |
| `name:` | base of slug for filename | already kebab-case |
| `metadata.type:` (`user`/`feedback`/`project`/`reference`) | `intents:` `[<type>]` plus topic-specific intents inferred from body | e.g. `feedback` + `okhttp` + `cookie` |
| body markdown | Ciel episode body, verbatim | preserve Context/Why/How to apply structure |
| paths cited in body (e.g. `src/`, `*.kt`, `Caddyfile`) | `path_patterns:` | infer from grep — narrow patterns preferred |
| symbols cited in body (class/function/table names) | `symbols:` | infer from grep |
| language hint (file extensions in body) | `languages:` | `kotlin`/`typescript`/`python`/`sql`/etc. |
| `captured_from:` (NEW) | `auto-memory-migration` | distinguishes from user-intervention captures |

**Skip `MEMORY.md`** — it's a table-of-contents index, not memory content. The scan already excludes it.

**Backup before delete.** After successfully writing an episode file for an auto-memory entry, MOVE (not delete) the source to `$AUTO_MEMORY_DIR/.migrated-to-ciel/<filename>` so the user can audit migration. The MEMORY.md index file itself stays in place — Claude Code may regenerate it on next session.

Skip:
- The pipeline / workflow descriptions (those belong in CLAUDE.md, not memory)
- General principles already in CLAUDE.md
- Anything that's just project description (READMEish)
- Code examples (those go in skills/, not memory)

### Step 5 — Propose batch capture

Once you have N candidate memories from the sources, present them to the user **as a batch**, not one by one (avoid 50 confirmation prompts). Use a single `AskUserQuestion` with the structure:

> "Found N candidates from your tribal docs. I'll list them; you tell me which to capture, which to skip, or 'all'."

For each candidate, show:
- **Title** (one line)
- **Source** (file:line)
- **Suggested tags** (paths, symbols, intents, language inferred from the lesson content)

The user replies with: "all", "1,3,5,8" (specific indices), or "skip".

### Step 6 — Write captured memories

For each captured candidate, create `.ciel/memory/episodes/<YYYY-MM-DD>-<slug>.md` with frontmatter:

```yaml
---
id: mem_<NNN>
title: <title>
languages: [<inferred>]
path_patterns:
  - <pattern>
symbols: [<inferred>]
intents: [<inferred>]
captured_at: <ISO8601 now>
captured_from: bootstrap
source: <original-file:line>
trigger_count: 0
last_triggered: null
stale_after_days: 90
stale: false
---

# <title>

<content from source, lightly cleaned>
```

ID strategy: read existing `index.json` for max id, increment. Slug = first 5 words of title, kebab-cased.

### Step 7 — Rebuild index

After all writes, regenerate `.ciel/memory/index.json` by parsing every frontmatter under `.ciel/memory/{episodes,concepts,guards}/`:

```python
# pseudo — use python3 -c '...' inline
for each *.md file:
    parse frontmatter
    add to memories dict by id
    for each path_pattern, symbol, intent, language:
        append id to corresponding by_* index
write back to index.json
```

### Step 8 — Confirm

Report:

- N memories captured
- Sources processed
- Index rebuilt with M total entries
- Suggest: "Cued-recall memory now active. Memories will auto-inject when their cues match in future tasks. Run `/ciel-memory-init` again anytime to re-scan for new tribal docs."

---

## Constraints

- **Never write a memory without user confirmation.** Even on bulk confirmation ("all"), display the list first.
- **Do not delete the source files.** Bootstrap converts; the user keeps the originals as long as they want.
- **Tag conservatively.** A memory tagged with `**/*` will fire on every task and pollute. If unsure, narrow the path pattern.
- **No agent dispatch.** This command is deterministic and runs inline.
- **Idempotent.** Re-running on an already-bootstrapped project should detect existing memories (by source field) and offer to skip duplicates.

---

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Script not found | `$CLAUDE_PROJECT_DIR` not set | Try `$HOME/.ciel/hooks/memory-bootstrap.sh` instead |
| Nothing scanned | No tribal docs in this project | Working as intended; report and end |
| Memories all tagged with broad paths | Source content didn't include path hints | Ask user to refine tags after listing |
| index.json malformed after rebuild | python3 parse error | Recreate empty index, re-run rebuild step |
| Auto-memory not detected | Slug derivation mismatch (cwd has unexpected characters) | Override via `CIEL_AUTO_MEMORY_DIR=<absolute-path> bash hooks/memory-bootstrap.sh scan` |
| Auto-memory file has `name:` but no `description:` | Older auto-memory format | Use first heading or filename as title; ask user to confirm before writing |

## See also

- `docs/adrs/0001-cued-recall-memory.md` — full design rationale
- `skills/workflow/memoire/SKILL.md` — capture/recall flow
- `skills/workflow/memoire-consolidator/SKILL.md` — periodic maintenance
