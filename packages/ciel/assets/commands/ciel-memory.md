---
description: Query and consult the Ciel cued-recall memory. List memories, search by keyword/symbol/intent/path, or show a specific memory. Uses memory-engine.py query internally. Read-only — never writes memories.
---

# /ciel-memory — Consult Cued-Recall Memory

**Purpose:** Search and browse the structured memories stored under `.ciel/memory/`. Use this when the user wants to know what Ciel remembers about a topic, symbol, file path, or intent.

**Usage:**
- `/ciel-memory <query>` — search memories matching a topic, symbol, or phrase
- `/ciel-memory list` — list all memory titles and IDs
- `/ciel-memory show <id>` — display the full content of a specific memory
- `/ciel-memory stats` — show memory health: total count, orphan count, stale count, last triggered dates

This is **read-only**: no writes to `.ciel/memory/`, no index rebuild, no agent dispatch.

---

## Instructions

You are consulting the cued-recall memory. Follow these steps.

### Step 1 — Determine mode

Parse the user input after `/ciel-memory`:

| Input | Mode | Action |
|-------|------|--------|
| No args or a search phrase | **query** | Go to Step 2 |
| `list` | **list** | Go to Step 3 |
| `show <id>` | **show** | Go to Step 4 |
| `stats` | **stats** | Go to Step 5 |

### Step 2 — Query mode

Run the memory engine in query mode:

```bash
engine="$CLAUDE_PROJECT_DIR/.claude/hooks/memory-engine.py"
[ -f "$engine" ] || engine="$CLAUDE_PROJECT_DIR/hooks/memory-engine.py"
python3 "$engine" query --prompt "<user query>" --cwd "$CLAUDE_PROJECT_DIR"
```

The engine outputs JSON to stdout. Parse it and present a user-friendly summary:

- **Memories found (N):** for each, show:
  - `id` — memory identifier
  - `title` — one-line summary
  - `symbols` — matched symbols (if any)
  - `intents` — matched intents (if any)
  - `trigger_count` — how many times this memory has been triggered
  - `last_triggered` — when it was last matched

- **If 0 results:** tell the user clearly. Suggest:
  - "No memories matched. Try a different keyword, or `/ciel-memory list` to see all memories."
  - "The cued-recall memory populates when you intervene with corrections (the system captures them automatically)."

### Step 3 — List mode

Run a quick scan of all memory frontmatter:

```bash
python3 -c "
import json, os, re
index_path = os.path.join(os.environ.get('CLAUDE_PROJECT_DIR', '.'), '.ciel', 'memory', 'index.json')
with open(index_path) as f:
    idx = json.load(f)
mems = idx.get('memories', {})
for mid, m in sorted(mems.items(), key=lambda x: x[1].get('title', '')):
    print(f\"{mid} | {m.get('title', 'untitled')} | triggered={m.get('trigger_count',0)}x | last={m.get('last_triggered','never')}\")
"
```

Present as a table:

```
ID       | Title                    | Triggers | Last Seen
---------|--------------------------|----------|----------
mem_001  | Use cursor-based pag...  | 5x       | 2026-05-20
mem_002  | Never trust default ...  | 0x       | never
...
```

If empty: "No memories yet. The cued-recall memory is empty. It populates when you intervene with corrections. Run `/ciel-memory-init` to seed from existing tribal docs."

### Step 4 — Show mode

The user asked for a specific memory by ID (`mem_XXX`).

```bash
python3 -c "
import json, os
index_path = os.path.join(os.environ.get('CLAUDE_PROJECT_DIR', '.'), '.ciel', 'memory', 'index.json')
with open(index_path) as f:
    idx = json.load(f)
mem = idx.get('memories', {}).get('<id>')
if mem:
    # Find the episode file
    mem_dir = os.path.join(os.environ.get('CLAUDE_PROJECT_DIR', '.'), '.ciel', 'memory', 'episodes')
    for fname in os.listdir(mem_dir):
        if fname.endswith('.md'):
            with open(os.path.join(mem_dir, fname)) as f:
                content = f.read()
            if '<id>' in content:
                import json as j
                print(json.dumps({'id': '<id>', 'title': mem.get('title',''), 'content': content}, indent=2))
                break
"
```

Read the episode file and present it:

```
## mem_XXX: <title>

**Symbols:** ...
**Intents:** ...
**Path patterns:** ...
**Languages:** ...
**Captured:** <date> | **Last triggered:** <date> | **Trigger count:** N

---

<full memory body>
```

If ID not found: "No memory with ID `<id>`. Use `/ciel-memory list` to see all IDs."

### Step 5 — Stats mode

```bash
python3 -c "
import json, os
from datetime import datetime, timezone
index_path = os.path.join(os.environ.get('CLAUDE_PROJECT_DIR', '.'), '.ciel', 'memory', 'index.json')
with open(index_path) as f:
    idx = json.load(f)
mems = idx.get('memories', {})
total = len(mems)
stale = sum(1 for m in mems.values() if m.get('stale'))
never_triggered = sum(1 for m in mems.values() if m.get('trigger_count', 0) == 0)
top = sorted(mems.values(), key=lambda m: m.get('trigger_count', 0), reverse=True)[:5]
# Check integrity
mid_set = set(mems.keys())
orphans = 0
empty_keys = 0
for idx_name in ('by_path', 'by_symbol', 'by_intent', 'by_language'):
    idx_map = idx.get(idx_name, {})
    for k, v in idx_map.items():
        if not v:
            empty_keys += 1
        else:
            orphans += sum(1 for mid in v if mid not in mid_set)
print(f'total={total} stale={stale} never_triggered={never_triggered} orphans={orphans} empty_keys={empty_keys}')
top_titles = [(m.get('title','')[:60], m.get('trigger_count',0)) for m in top]
print('top:', json.dumps(top_titles))
"
```

Present:

```
## Memory Stats

| Metric | Value |
|--------|-------|
| Total memories | N |
| Stale | N |
| Never triggered | N |
| Orphan references | N |
| Empty index keys | N |

### Top 5 Most Triggered
1. **mem_XXX** — Title (Nx)
2. ...

### Health
- Score: X/100 (doctor memory check)
- Recommendation: ...
```

After stats, suggest:
- If never_triggered > 50%: "Many memories have never been triggered. Consider pruning low-signal memories."
- If orphans > 0: "Index has orphan references. Run `/ciel-doctor` for details."
- If stale > 0: "Stale memories exist. Memory engine will auto-flag during rebuild."

---

## Constraints

- **Read-only.** Never write to `.ciel/memory/` from this command. Use `/ciel-memory-init` for ingestion.
- **No agent dispatch.** This command is deterministic. No researcher, explorer, or critic.
- **No index rebuild.** Querying does not trigger a rebuild. Use `/ciel-doctor` or `memory-engine.py rebuild-index` explicitly if the index is corrupt.
- **Handle missing index gracefully.** If `.ciel/memory/index.json` doesn't exist, tell the user: "No memory index found. Run `/ciel-memory-init` to initialize."

## Failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| Script not found | `$CLAUDE_PROJECT_DIR` not set | Try `$HOME/.ciel/hooks/memory-engine.py` |
| index.json missing | Memory never initialized | Run `/ciel-memory-init` |
| index.json malformed | Manual edit error | Run `python3 hooks/memory-engine.py rebuild-index` |
| 0 results on valid query | Cues don't match memory tags | Try broader terms or `/ciel-memory list` |

## See also

- `/ciel-memory-init` — ingestion (scan, seed, capture)
- `/ciel-doctor` — health check including memory index integrity
- `hooks/memory-engine.py` — the engine powering query/rebuild/capture
- `docs/adrs/0001-cued-recall-memory.md` — design rationale
