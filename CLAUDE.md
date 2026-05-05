# CLAUDE.md — Ciel v6 (IMPERATIVE — FOLLOW ALL RULES)

This file is Claude Code's project-level instruction. **It is not advisory — these rules are mandatory.**

**Core principle:** *"Understand before generating. Verify before claiming done."*

---

## MANDATORY: Every response MUST follow this format

```
[CIEL] Depth: <Trivial|Standard|Critical|Spike>
Pipeline step: <DOCS|QUOI|ASK|AVEC QUOI|DIVERGE|RECHERCHE|CODEBASE|EVALUER|ASK2|FAIRE|RELIRE|PROUVER|MEMOIRE|META>
[your response content]
```

Classify depth in the FIRST line of EVERY response. No exceptions.

---

## MANDATORY: How to start every task

1. **Classify depth** using the Depth Gauge below
2. **Create TODO list** with `TaskCreate` — one entry per pipeline step
3. **Mark current step `in_progress`** as you work
4. **Complete all steps** for the classified depth before declaring done
5. **End with META** — always, 10 items, non-negotiable

---

## Rules (immutable — do NOT skip)

1. **Depth first** — every response starts with `[CIEL] Depth: <Trivial|Standard|Critical|Spike>`
2. **Pipeline** — follow the 16-step table below. Complete ALL steps for your depth. No shortcuts.
3. **TODO list** — use `TaskCreate` at the start of each task (one task per pipeline step). Mark each step `in_progress` before starting it, `completed` when done.
4. **ASK** — use AskUserQuestion tool ONLY if ambiguous. If context is sufficient, DECIDE and move on.
5. **Subagents** — dispatch `ciel-researcher` (research), `ciel-explorer` (codebase), `ciel-critic` (review) via Task tool.
6. **TEST-FIRST (RED)** — write tests BEFORE source code. Never the reverse.
7. **SELF-CHECK** — after each step, verify: did I do DOCS? QUOI? ASK? DIVERGE? RECHERCHE?
8. **META** — post-task reflection always, non-negotiable. 10 items.

## Pipeline (16 steps)

| Step | Depth | Action |
|------|-------|--------|
| **DOCS** | All | Read AGENTS.md, CLAUDE.md, ciel-overlay.md, .ciel/map.json, .ciel/memory.json |
| **QUOI** | All | Goal (1 sentence) + NOT-X + Definition of Done |
| **ASK** | Std/Crit | `AskUserQuestion` if ambiguous. Otherwise DECIDE. |
| **AVEC QUOI** | Std/Crit | Read installed versions (package.json) — not memory |
| **DIVERGE** | Std/Crit | 2-3 different approaches BEFORE choosing |
| **RECHERCHE** | Std/Crit | Dispatch `ciel-researcher`: official docs + anti-patterns + changelog |
| **SECURITE** | Critical | STRIDE 6 categories → `ciel-critic` MODE=CRITIQUER |
| **CODEBASE** | Std/Crit | Dispatch `ciel-explorer`: pattern fitness + data flow + git history |
| **EVALUER** | Std/Crit | Sizing + 2 failure modes + counterfactual |
| **ASK2** | Std/Crit | Validate plan with user before coding |
| **FAIRE** | All | Test-first RED + alternatives + idiomatic |
| **ADR** | Decision | If architectural decision → `docs/adrs/` |
| **RELIRE** | Std/Crit | Dispatch `ciel-critic` MODE=RELIRE: 3 RISKS + FIX/ACCEPT/DEFER |
| **PROUVER** | Std/Crit | BEFORE/AFTER evidence + CI gate |
| **MEMOIRE** | All | Save .ciel/map.json + learnings + memory.json |
| **META** | All | Post-task reflection (10 items) |

## Depth Gauge

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-liner | QUOI → FAIRE → META |
| **Standard** | hook, route, component, service | Full 16 steps |
| **Critical** | auth, DB schema, security, payment | Full + STRIDE + `ciel-critic` mandatory |
| **Spike** | POC, draft, experimental | QUOI → ASK → AVEC QUOI → DIVERGE → FAIRE (relaxed) → META |

Unsure → Standard. Touching user data or auth → Critical.

## Top 10 Guards

1. **"I already know this" = red flag** → need RESEARCH. Do it.
2. **Verify before asserting** — no citation = you don't know. Don't guess.
3. **DB columns** — verify real schema before query (migration file, not memory).
4. **Test URL host:port** — must match handler host:port. Verify.
5. **Pattern copied blindly** → fitness check fails. Verify before copying.
6. **Self-critique in same context** = same blind spots → dispatch `ciel-critic`.
7. **No alternative considered** → back to EVALUER. Find 2-3 approaches.
8. **Scope drift at 3+ files** → re-read QUOI. Re-center.
9. **Write test FIRST (RED)**, not after. Always.
10. **"No error in logs" ≠ proof** → trigger scenario, see positive signal.

## Subagent Dispatch (MANDATORY for Standard/Critical)

**Rule**: Dispatch BOTH `ciel-researcher` + `ciel-explorer` **IN PARALLEL** before writing any code on Standard/Critical tasks.

| Agent | When | Via | In parallel with |
|-------|------|-----|-----------------|
| `ciel-researcher` | RECHERCHE (Std/Crit) | `task` subagent_type=`ciel-researcher` | `ciel-explorer` |
| `ciel-explorer` | CODEBASE (Std/Crit) | `task` subagent_type=`ciel-explorer` | `ciel-researcher` |
| `ciel-critic` (RELIRE) | RELIRE after FAIRE (Std/Crit) | `task` subagent_type=`ciel-critic` | — |
| `ciel-critic` (CRITIQUER) | SECURITE (Critical only) | `task` subagent_type=`ciel-critic` | — |
| `ciel-improver` | ONLY on /ciel-improve, /ciel-eval | `task` subagent_type=`ciel-improver` | — |

**IMPORTANT**: If a subagent dispatch fails (`ProviderModelNotFoundError`), fall back to inline research/exploration. Do NOT skip the step.

## Skills reference

- **Workflow**: `depth-classifier`, `quoi-framer`, `avec-quoi-versioner`, `diverge`, `evaluer-sizer`, `faire-gatekeeper`, `prouver-verifier`, `memoire`, `meta-critiquer`
- **Security**: `stride-analyzer`, `security-hardening`, `security-regression-check` (Critical only)
- **Domain**: `frontend-mastery`, `backend-mastery`, `database-mastery`, `api-architecture`, `performance-engineering`
- **Utility**: `pr-opener`, `commit-writer`, `branch-setup`, `issue-creator`, `issue-closer`

## Hooks (automatic — configured in .claude/settings.json)

| Hook | Trigger | Action |
|------|---------|--------|
| `check-test-first.sh` | Before Edit/Write | Warns if source file has no test |
| `block-destructive.sh` | Before `rm *` | Blocks destructive commands |
| `track-file.sh` | After Edit/Write | Tracks changed files for RELIRE |
| `meta-critiquer.sh` | SubagentStop | Triggers post-task reflection |

## Common failures to avoid

These are the most frequently skipped pipeline steps. Do NOT fall into these traps:

| Failure | When it happens | Fix |
|---------|----------------|------|
| **No DOCS** | Starting a task without reading project state | Always read `.ciel/map.json` + `ciel-overlay.md` first |
| **No QUOI** | Coding without defining the goal + constraints | State "Goal (1 sentence) + NOT-X + DoD" before touching code |
| **No DIVERGE** | Using the first approach that comes to mind | Generate 2-3 alternatives before picking one |
| **No subagents** | Doing research/exploration inline instead of dispatching | Dispatch `ciel-researcher` + `ciel-explorer` in parallel |
| **No RELIRE** | Merging without a hostile code review | Always dispatch `ciel-critic` MODE=RELIRE before merge |
| **No PROUVER** | Claiming done without evidence | Show BEFORE/AFTER evidence (logs, curl, screenshot) |
| **No MEMOIRE** | Losing state between sessions | Save `.ciel/map.json` + `.ciel/memory.json` at task end |
| **No META** | Skipping reflection | Always run META (10 items) — it closes the feedback loop |

**Self-check**: After each step, ask yourself: "Did I just skip a pipeline step?" If yes, go back and do it.

## MCP integration (opt-in)

Ciel supports Playwright (visual critique) and Context7 (live docs) via MCP. Register:
```bash
bash install.sh --with-mcp=playwright,context7
```
