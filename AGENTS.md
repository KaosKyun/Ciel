# AGENTS.md -- Ciel deep-reasoning workflow v5 (OpenCode)

Source: https://github.com/KaosKyun/Ciel

Principle: **"Understand before generating. Verify before claiming done."**

Ciel v5 is installed as OpenCode-native primitives:

- **Plugin** (`.opencode/plugins/ciel.ts`) -- session events + workflow injection + depth classification + SPIKE mode + RELIRE reminders + META-CRITIQUER + map/parking/memory persistence.
- **Primary Agent** (`.opencode/agents/ciel.md`) -- single orchestrator v5: DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE -> RECHERCHE -> SECURITE -> CODEBASE -> EVALUER -> ASK2 -> FAIRE -> ADR -> RELIRE -> PROUVER -> MEMOIRE -> META. Dispatches subagents for Standard/Critical tasks.
- **Subagents** (`.opencode/agents/ciel-*.md`) -- dispatch with `@ciel-researcher`, `@ciel-explorer`, `@ciel-critic` (5 modes), `@ciel-improver`.
- **Commands** (`.opencode/commands/`) -- `/ciel-init`, `/ciel-update`, `/ciel-refresh`, `/ciel-improve`, `/ciel-eval`, `/ciel-create-skill`, `/ciel-recommend`, `/ciel-audit`.

---

## Primary Agent -- Single Orchestrator

| Agent | Mode | Role | Permissions |
|-------|------|------|-------------|
| **`ciel`** | `primary` | Full pipeline v5: 16 steps | `edit: allow`, `bash: allow` (full tools) |

**Usage:**
1. **One agent** -- no Tab switching needed. `ciel` handles planning AND implementation.
2. **@mention** subagents directly: `@ciel-researcher find docs for X`.
3. **ASK window**: the agent uses OpenCode's `question` tool to clarify ambiguities.
4. **SPIKE mode**: `.ciel/exploration.active` flag assouplit les quality gates.

---

## Depth gauge v5 -- classify BEFORE starting

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-line fix | QUOI -> FAIRE -> META (inline, no dispatch) |
| **Standard** (feature, refactor) | hook, route, component | 16-step pipeline complet avec dispatch conditionnel |
| **Critical** (auth, DB, security, payment) | auth/, DB schema, payment | 16-step pipeline + `@ciel-researcher` + `@ciel-explorer` IN PARALLEL + `@ciel-critic` mandatory + SECURITE |
| **Spike** (prototype, exploration) | POC, draft, experimental | QUOI -> ASK -> AVEC QUOI -> DIVERGE -> FAIRE (gates assouplies) -> META |

Unsure -> **Standard**. Touching user data or auth -> **Critical**.

---

## 16-step pipeline v5 (OpenCode-native)

1. **DOCS** -- Lire README, ADRs, tickets, overlay, .ciel/map.json
2. **QUOI** -- 1-sentence goal + NOT-X + definition of done + intentions partagees
3. **ASK** -- Utiliser le `question` tool pour clarifier les ambiguites
4. **AVEC QUOI** -- read installed versions (not memory), load overlay
5. **DIVERGE** -- Explorer 2-3 approches radicalement differentes
6. **RECHERCHE** -- `@ciel-researcher`: official docs + anti-patterns + version changelog
7. **SECURITE** -- STRIDE + killer checklist (Critical only)
8. **CODEBASE + FLUX** -- `@ciel-explorer`: LSP navigation + pattern fitness + git history + data flow
9. **EVALUER** -- sizing + 2 failure modes + alternatives + counterfactual
10. **ASK2** -- Questions sur le plan avant d'implementer
11. **FAIRE** -- test-first (RED), 5 quality gates (alternatives, idiomatic, quality, removal, boy-scout)
12. **ADR** -- Documenter les decisions architecturales dans docs/adrs/ (si significatif)
13. **RELIRE** -- `@ciel-critic MODE=RELIRE`: 3 RISQUE + FIX/ACCEPT/DEFER
14. **PROUVER** -- AVANT/APRES evidence + CI gate + PR body
15. **MEMOIRE** -- Sauvegarder la carte (.ciel/map.json) + apprentissages (.ciel/learnings.md)
16. **META** -- 30s post-task reflection (10 items)

---

## Subagent dispatch rules

| Agent | When | Context | Permissions |
|-------|------|---------|-------------|
| `@ciel-researcher` | RECHERCHE step (Standard + Critical) | Isolated fork -- no session bias | webfetch/websearch allowed, no edit |
| `@ciel-explorer` | CODEBASE + FLUX (Standard + Critical) | Isolated fork -- reads codebase fresh | read/grep/glob + LSP allowed, no edit |
| `@ciel-critic` | RELIRE after FAIRE / CRITIQUER / RCA / FEEDBACK / INVESTIGATE | Isolated fork -- different blind spots | bash/read allowed, no edit |
| `@ciel-improver` | `/ciel-improve`, `/ciel-eval`, `/ciel-create-skill` | Meta-analysis | bash/read/webfetch allowed, no edit |

Dispatch `@ciel-researcher` + `@ciel-explorer` **IN PARALLEL** before writing code on Critical tasks.

---

## Automatic context injection (plugin hooks)

The `ciel.ts` v5 plugin injects:

- **META-CRITIQUER** -- 10-item reflection after every completed task (injected in every system prompt)
- **Depth classification** on every user prompt (via `experimental.chat.messages.transform`)
- **SPIKE mode detection** -- `.ciel/exploration.active` flag detected and injected
- **Project map** -- `.ciel/map.json` loaded into every session
- **Session memory** -- `.ciel/memory.json` loaded into every session
- **RELIRE reminders** after every Write/Edit (via `tool.execute.after`)
- **FAIRE gates** reminder before every Write/Edit (via `tool.execute.before`)
- **Parking lot** -- fortuitous discoveries written to `.ciel/parking.md`
- **Overlay context** from `ciel-overlay.md` (via `experimental.chat.system.transform`)
- **learnings-capture** on `experimental.session.compacting`
- **session.deleted** logging (tracks subagent child sessions)

---

## ASK window -- using the `question` tool

The `question` tool is an OpenCode built-in tool for asking the user questions during execution.
Use it during phases 3 (ASK) and 10 (ASK2) of the pipeline:

- Clarify ambiguous requirements
- Validate assumptions
- Propose implementation options
- Get decisions on trade-offs

Each question includes a header, the question text, and a list of options.
Users can select from options or type custom answers.

---

## Intent routing (auto-dispatch) v5

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
| "spike", "prototype", "explore X" | Depth=Spike, gates assouplies, .ciel/exploration.active |

---

## Memory systems

### Project map (.ciel/map.json)

Persistent project structure map maintained by the plugin:
- Modules and their paths
- Key files and responsibilities
- Architectural decisions (ADR references)
- Reusable patterns
- Updated after every exploration

### Parking lot (.ciel/parking.md)

Fortuitous discoveries noted during tasks:
- Tangential findings that are NOT the task focus
- Noted but not acted upon
- Reviewed at the start of each session

### Session memory (.ciel/memory.json)

Cross-session learnings:
- Build commands and debugging insights
- User corrections and preferences
- Failure modes and lessons learned
- Loaded at the start of each session

---

## ciel-overlay.md

Create `ciel-overlay.md` at project root with:

```markdown
# Ciel Overlay -- [Project Name]

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

## Lecons projet
- [date] MISTAKE: forgot transaction block -> RULE: always wrap DB queries in `transaction {}`
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

## LSP tool integration (OpenCode experimental)

If `OPENCODE_EXPERIMENTAL_LSP_TOOL` is set, the explorer agent can use:
- `goToDefinition`: jump to function/class definitions
- `findReferences`: find all usages of a symbol
- `hover`: get type information
- `documentSymbol`: list symbols in a file
- `workspaceSymbol`: search for symbols across the project
- `prepareCallHierarchy`, `incomingCalls`, `outgoingCalls`: understand call graphs

Enable with: `OPENCODE_EXPERIMENTAL_LSP_TOOL=true opencode`

---

## Model selection

Ciel agents inherit the **globally selected model** via `/models` or `opencode.json` `"model"` field.

No model is hardcoded in agent configs -- switch freely between:
- `anthropic/claude-sonnet-4-5`
- `anthropic/claude-opus-4-5`
- `openai/gpt-5.2`
- `openai/gpt-5.1-codex`
- etc.

Subagents inherit the model of the primary agent that invokes them.
