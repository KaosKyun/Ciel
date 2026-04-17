---
name: ciel
version: 2.0.0
description: "Skills-first deep-reasoning plugin for LLM-assisted development. 33 specialized skills + 4 thin-orchestrator agents + self-improvement subsystem."
author: KaosKyun
min_claude_code_version: "2.0"
---

# Ciel

Skills-first deep-reasoning plugin. Named after the Primordial Sage from *Tensei Shitara Slime Datta Ken* — the advisor who reasons at infinite speed before Rimuru acts.

Principle: **"Understand before generating. Verify before claiming done."**

## Architecture

v2.0.0 is a **total refactor** toward Anthropic's Skills-first paradigm (Barry Zhang / Mahesh Murag, AI Engineer Code Summit): one generic orchestrator + library of specialized skills > many specialized agents.

### Skills (33 total, organized in 5 categories)

- `skills/ciel/` — Lightweight orchestrator (~220 lines) that classifies depth and routes to specialized skills
- `skills/workflow/` — **13 skills** replacing the old monolithic CRÉER/CRITIQUER pipeline: `depth-classifier`, `quoi-framer`, `avec-quoi-versioner`, `stride-analyzer`, `pattern-fitness-check`, `evaluer-sizer`, `flux-narrator`, `faire-gatekeeper`, `security-regression-check`, `relire-critic`, `prouver-verifier`, `critiquer-auditor`, `meta-critiquer`
- `skills/research/` — **6 meta-research skills**: `research-web-sources`, `research-github-issues`, `research-forums`, `validate-source-credibility`, `synthesize-findings`, `fact-check-claims`
- `skills/domain/` — **8 domain expertise skills**: `frontend-mastery`, `backend-mastery`, `database-mastery`, `security-hardening`, `api-architecture`, `observability`, `performance-engineering`, `refactoring-patterns`
- `skills/utility/` — **5 utility skills**: `commit-writer`, `pr-body-generator`, `issue-closer`, `changelog-updater`, `staging-verifier`
- `skills/meta/` — **4 self-improvement skills** (Ciel modifies itself): `ciel-improve`, `skill-creator`, `skill-variant-evaluator`, `learnings-capture`

### Agents (4 thin orchestrators)

- `agents/researcher.md` — calls `research/*` skills in parallel, synthesizes findings
- `agents/explorer.md` — calls `pattern-fitness-check` + `flux-narrator` + domain skill
- `agents/critic.md` — routes RELIRE → `relire-critic` | CRITIQUER → `critiquer-auditor`
- `agents/improver.md` — long-running self-improvement loop

### Hooks (7 events)

- `hooks/session-start.sh` — Bannière, load overlay, TRACE_ID eval
- `hooks/user-prompt-submit.sh` — Depth pre-classification hint
- `hooks/pre-tool-write.sh` — FAIRE gates + STRIDE reminder (Critical files)
- `hooks/post-tool-write.sh` — RELIRE dispatch enforcement
- `hooks/pre-compact.sh` — session-progress.md capture
- `hooks/subagent-stop.sh` — Agent report size logging
- `hooks/stop.sh` — META-CRITIQUER dispatch

### Commands (7)

- `/ciel <task>` — Main entry (classifies depth, routes)
- `/ciel-recommend` — Community plugin discovery
- `/ciel-update` — Self-update from GitHub
- `/ciel-improve` — Analyze sessions, propose skill patches
- `/ciel-create-skill <name> <purpose>` — Create new skill from conversation pattern
- `/ciel-eval [skill-name]` — Run eval harness
- `/ciel-audit` — Session post-mortem (hook-independent diagnostic, produces copy-paste report)

### Self-improvement subsystem

- `evals/datasets/*.jsonl` — Binary eval tasks per skill
- `evals/runners/` — Headless skill evaluation via `claude --print`
- `evals/results/` — Scoreboards per skill × commit
- `scripts/run-evals.sh` — Eval harness runner

### Multi-platform distribution (auto-generated)

- `scripts/build-platforms.sh` — Regenerates all `platforms/*` from `skills/`
- Claude Code receives full Skills architecture
- Cursor/Windsurf receive compressed rule files (≤ 6 KB)
- Codex/OpenCode/Kilo receive medium-compressed AGENTS.md (≤ 32 KB)
- Ollama/LM Studio receive a ~300-token SYSTEM prompt

See [README.md](README.md) for installation and [CHANGELOG.md](CHANGELOG.md) for version history and fix/revert metrics.
