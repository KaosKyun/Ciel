# AGENTS.md — Ciel deep-reasoning workflow (OpenCode, v6.15.0)

Source: https://github.com/KaosKyun/Ciel

Principle: **"Understand before generating. Verify before claiming done."**

Ciel is installed as OpenCode-native primitives:

- **Plugin** (`.opencode/plugins/ciel.ts`) — pre/post-write hooks + depth classification on user prompts.
- **Subagents** (`.opencode/agents/ciel-*.md`) — dispatch with `@ciel-researcher`, `@ciel-explorer`, `@ciel-critic`, `@ciel-improver`.
- **Commands** (`.opencode/commands/ciel*.md`) — run with `/ciel`, `/ciel-improve`, `/ciel-refresh`, `/ciel-audit`, `/ciel-init`, `/ciel-eval`, `/ciel-create-skill`, `/ciel-recommend`, `/ciel-update`.

---

## Depth gauge — classify BEFORE starting

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-line fix | `QUOI` → `FAIRE` → `META` |
| **Standard** | hook, route, component, service | Full pipeline, dispatch `@ciel-researcher` + `@ciel-explorer` in parallel before coding |
| **Critical** | auth, DB schema, security, payment | Full pipeline + STRIDE threat model + `@ciel-critic` mandatory |

Unsure → Standard. Touching user data or auth → Critical.

---

## 10-step pipeline (condensed)

1. **QUOI** — 1-sentence goal + NOT-X + definition of done
2. **AVEC QUOI** — read installed versions (not memory), load overlay
3. **RECHERCHE** — `@ciel-researcher` (Standard+Critical): official docs + anti-patterns + version changelog
4. **SÉCURITÉ** — STRIDE + killer checklist (Critical only)
5. **CODEBASE + FLUX** — `@ciel-explorer`: pattern fitness + data flow narration
6. **ÉVALUER** — sizing + 2 failure modes + alternatives + counterfactual
7. **FAIRE** — test-first (RED), alternatives gate, idiomatic gate, removal gate
8. **RELIRE** — `@ciel-critic` MODE=RELIRE: 3 RISQUE (functional + imports + data) + FIX/ACCEPT/DEFER
9. **PROUVER** — AVANT/APRÈS evidence + CI gate + PR body + issue comment
10. **META** — 30s post-task reflection: depth match? failure mode? user correction?

---

## Top 10 Guards

1. "I already know this" = red flag — need research
2. Verify before asserting (no citation = don't know it)
3. DB columns: verify real schema before query
4. Test URL host:port must match handler host:port
5. Pattern copied blindly → fitness check fails
6. Self-critique in same context = same blind spots — dispatch `@ciel-critic`
7. No alternative considered = back to ÉVALUER
8. Scope drift at 3+ files → re-read QUOI
9. Write test FIRST (RED), not after
10. "No error in logs" ≠ proof — trigger scenario, see positive signal

---

## Agent dispatch rules

| Agent | When | Context | Permissions |
|-------|------|---------|-------------|
| `@ciel-researcher` | RECHERCHE step (Standard + Critical) | Isolated fork — no session bias | webfetch allowed, no edit |
| `@ciel-explorer` | CODEBASE + FLUX (Standard + Critical) | Isolated fork — reads codebase fresh | bash/read, no edit |
| `@ciel-critic` | RELIRE after FAIRE / CRITIQUER on diff | Isolated fork — different blind spots | bash/read, no edit |
| `@ciel-improver` | On `/ciel-improve` only | Extended token budget | webfetch allowed, no edit |

Dispatch `@ciel-researcher` + `@ciel-explorer` **IN PARALLEL** before writing code.

---

## Automatic context injection (plugin hooks)

The `ciel.ts` plugin injects depth classification on every user prompt and RELIRE reminders after every `Write`/`Edit` on code files. You don't need to remember to invoke Ciel — the plugin fires on the right events.

---

## MCP integration (opt-in)

Ciel ships a `.mcp.json` template at the repo root with two opt-in servers: `playwright` (visual critique) and `context7` (live official docs). Register them via:

```bash
bash ~/.claude/plugins/ciel/scripts/install.sh --with-mcp=playwright,context7
```

**Important** — OpenCode issue #2319: plugin hooks (`tool.execute.before/after`) do NOT fire for MCP tool calls. The `playwright-visual-critic` skill orchestrates the flow explicitly (navigate → snapshot → dispatch `@ciel-critic`) rather than relying on auto-triggered hooks. When you use a visual-critique workflow, dispatch the critic agent yourself after capture.
