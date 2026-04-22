# AGENTS.md — Ciel deep-reasoning workflow (OpenCode, v3.7.0)

Source: https://github.com/KaosKyun/Ciel

Principle: **"Understand before generating. Verify before claiming done."**

Ciel is installed as OpenCode-native primitives:

- **Plugin** (`.opencode/plugins/ciel.ts`) — session events + workflow injection + depth classification + RELIRE reminders + META-CRITIQUER.
- **Primary Agent** (`.opencode/agents/ciel.md`) — single orchestrator: QUOI → AVEC QUOI → RECHERCHE → CODEBASE → FAIRE → RELIRE → PROUVER. Dispatches subagents for Standard/Critical tasks.
- **Subagents** (`.opencode/agents/ciel-*.md`) — dispatch with `@ciel-researcher`, `@ciel-explorer`, `@ciel-critic`, `@ciel-improver`.
- **Commands** (`.opencode/commands/`) — `/ciel-init`, `/ciel-update`, `/ciel-refresh`, `/ciel-improve`, `/ciel-eval`, `/ciel-create-skill`, `/ciel-recommend`, `/ciel-audit`.

---

## Primary Agent — Single Orchestrator

| Agent | Mode | Rôle | Permissions |
|-------|------|------|-------------|
| **`ciel`** | `primary` | Full pipeline: QUOI → AVEC QUOI → RECHERCHE → CODEBASE → FAIRE → RELIRE → PROUVER | `edit: allow`, `bash: allow` (full tools) |

**Usage:**
1. **One agent** — no Tab switching needed. `ciel` handles planning AND implementation.
2. **@mention** subagents directly: `@ciel-researcher find docs for X`.

---

## Depth gauge — classify BEFORE starting

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-line fix | `quoi-framer` → inline, no dispatch |
| **Standard** (feature, refactor) | hook, route, component | `@ciel-explorer` if 3+ files → `ciel` does FAIRE → `@ciel-critic` if 5+ files |
| **Critical** (auth, DB, security, payment) | auth/, DB schema, payment | `@ciel-researcher` + `@ciel-explorer` IN PARALLEL → `ciel` does FAIRE → `@ciel-critic MODE=RELIRE` (mandatory) |

Unsure → **Standard**. Touching user data or auth → **Critical**.

---

## 10-step pipeline (OpenCode-native)

1. **QUOI** — 1-sentence goal + NOT-X + definition of done
2. **AVEC QUOI** — read installed versions (not memory), load overlay
3. **RECHERCHE** — `@ciel-researcher`: official docs + anti-patterns + version changelog
4. **SÉCURITÉ** — STRIDE + killer checklist (Critical only)
5. **CODEBASE + FLUX** — `@ciel-explorer`: pattern fitness + data flow narration
6. **ÉVALUER** — sizing + 2 failure modes + alternatives + counterfactual
7. **FAIRE** — test-first (RED), alternatives gate, idiomatic gate, removal gate
8. **RELIRE** — `@ciel-critic MODE=RELIRE`: 3 RISQUE + FIX/ACCEPT/DEFER
9. **PROUVER** — AVANT/APRÈS evidence + CI gate + PR body
10. **META-CRITIQUER** — 30s post-task reflection: depth match? failure mode? user correction?

---

## Subagent dispatch rules

| Agent | When | Context | Permissions |
|-------|------|---------|-------------|
| `@ciel-researcher` | RECHERCHE step (Standard + Critical) | Isolated fork — no session bias | webfetch/websearch allowed, no edit |
| `@ciel-explorer` | CODEBASE + FLUX (Standard + Critical) | Isolated fork — reads codebase fresh | read/grep/glob allowed, no edit |
| `@ciel-critic` | RELIRE after FAIRE / CRITIQUER on diff | Isolated fork — different blind spots | bash/read allowed, no edit |
| `@ciel-improver` | `/ciel-improve`, `/ciel-eval`, `/ciel-create-skill` | Meta-analysis | bash/read/webfetch allowed, no edit |

Dispatch `@ciel-researcher` + `@ciel-explorer` **IN PARALLEL** before writing code on Critical tasks.

---

## Automatic context injection (plugin hooks)

The `ciel.ts` plugin injects:

- **META-CRITIQUER** — 7-item reflection after every completed task (injected in every system prompt)
- **Depth classification** on every user prompt (via `experimental.chat.messages.transform`)
- **RELIRE reminders** after every Write/Edit (via `tool.execute.after`)
- **FAIRE gates** reminder before every Write/Edit (via `tool.execute.before`)
- **Overlay context** from `ciel-overlay.md` (via `experimental.chat.system.transform`)
- **learnings-capture** on `experimental.session.compacting`
- **session.deleted** logging (tracks subagent child sessions)

---

## Intent routing (auto-dispatch)

| Intent keywords | Expected agent/skill |
|----------------|---------------------|
| "debug", "RCA", "incident" | `@ciel-critic MODE=RCA` + `debug-reasoning-rca` |
| "use library X", "API" | `@ciel-researcher` + `doc-validator-official` |
| "review UI", "visual" | `@ciel-critic` + `playwright-visual-critic` (if MCP) |
| "accessibility", "a11y", "WCAG" | `@ciel-explorer` + `accessibility-wcag-auditor` |
| "CI", "workflow", ".github" | `@ciel-explorer` + `cicd-security-hardener` |
| "merge PR", "auto-merge" | `pr-merger` (after `prouver-verifier` + CI green) |
| "respond to review" | `pr-review-responder` |
| "watch CI", "flaky" | `ci-watcher` |

---

## ciel-overlay.md

Create `ciel-overlay.md` at project root with:

```markdown
# Ciel Overlay — [Project Name]

## Stack
- Frontend: [lib + version]
- Backend: [framework + version]
- DB: [type + version]

## URLs docs
| Lib | Version | URL |
|-----|---------|-----|
| React | 19.0.0 | https://react.dev |

## Fichiers critiques
- src/auth/
- *Service.*
- *Routes.*

## CI commands
- Test: `pnpm test`
- Lint: `pnpm lint`

## Leçons projet
- [date] MISTAKE: forgot transaction block → RULE: always wrap DB queries in `transaction {}`
```

The plugin loads this automatically on `session.created` and injects it into every system prompt.

---

## Commands (utilitaires)

| Command | Purpose |
|---------|---------|
| `/ciel-init` | Bootstrap Ciel wiring (auto-detect platform, fix config) |
| `/ciel-update` | Check for newer Ciel version, reinstall |
| `/ciel-refresh` | Freshness audit over skill library (stale URLs, outdated pins) |
| `/ciel-improve` | Analyze sessions, propose skill patches |
| `/ciel-eval` | Run eval harness for skills (SDK Client on OpenCode) |
| `/ciel-create-skill` | Generate valid `SKILL.md` scaffold |
| `/ciel-recommend` | Discover community plugins matched to project stack |
| `/ciel-audit` | Session post-mortem (Ciel paradigm violations) |

---

## Model selection

Ciel agents inherit the **globally selected model** via `/models` or `opencode.json` `"model"` field.

No model is hardcoded in agent configs — switch freely between:
- `anthropic/claude-sonnet-4-5`
- `anthropic/claude-opus-4-5`
- `openai/gpt-5.2`
- `openai/gpt-5.1-codex`
- etc.

Subagents inherit the model of the primary agent that invokes them.