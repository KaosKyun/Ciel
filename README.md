# Ciel

[![CI](https://github.com/KaosKyun/Ciel/workflows/CI/badge.svg)](https://github.com/KaosKyun/Ciel/actions/workflows/ci.yml)
[![Test Hooks](https://github.com/KaosKyun/Ciel/workflows/Test%20Hooks/badge.svg)](https://github.com/KaosKyun/Ciel/actions/workflows/test-hooks.yml)
[![Platform Validation](https://github.com/KaosKyun/Ciel/workflows/Platform%20Validation/badge.svg)](https://github.com/KaosKyun/Ciel/actions/workflows/platform-validation.yml)
[![Skill Integrity](https://github.com/KaosKyun/Ciel/workflows/Skill%20Integrity/badge.svg)](https://github.com/KaosKyun/Ciel/actions/workflows/skill-integrity.yml)
[![Release](https://github.com/KaosKyun/Ciel/workflows/Release/badge.svg)](https://github.com/KaosKyun/Ciel/actions/workflows/release.yml)
[![Deploy Staging](https://github.com/KaosKyun/Ciel/workflows/Deploy%20Staging/badge.svg)](https://github.com/KaosKyun/Ciel/actions/workflows/deploy-staging.yml)

> *Named after the Primordial Sage from Tensura — the advisor who reasons at infinite speed before Rimuru acts.*

Skills-first deep-reasoning plugin for LLM-assisted development. One generic orchestrator + library of ~50 specialized skills + 4 thin-orchestrator agents + self-improvement subsystem. Dual-platform: Claude Code + OpenCode.

Principle: **"Understand before generating. Verify before claiming done."**

## The problem it solves

| LLM default behavior | Ciel solution |
|---|---|
| Skip research ("I already know this") | `research/*` skills — specialized per source (web, GitHub issues, forums) |
| Copy patterns without fitness check | `workflow/pattern-fitness-check` — 3-question fitness gate |
| Self-critique in same context = same blind spots | `critic` agent → `relire-critic` skill in fresh fork |
| "Done" = code written | `workflow/prouver-verifier` — staging evidence gates |
| Process skipped for "simple" tasks | Hooks — 9 events, deterministic enforcement |
| Dispatch gate ignored (10+ inline calls before Task()) | `pre-tool-count.sh` — mechanical hard-stop at N=5 inline Bash/Read/Grep/Glob |
| No feedback loop on process quality | `meta/ciel-improve` + `meta/skill-variant-evaluator` + `meta/skill-freshness-auditor` — auto-refine skills from session transcripts AND external drift |
| Monolithic SKILL.md rots and gets skipped | ~50 specialized skills, each ≤ 500 lines, composable and testable |

**Baseline**: 62.8% fix/revert ratio on Neiyomi with v1.x monolithic dev-reasoning skill (2026-04-04). v2.5.0 target: < 45% (reference SICA: 17 → 53%).

## Architecture

```
ciel/
├── skills/
│   ├── ciel/              Orchestrator (~340 lines) — classifies depth, routes to skills
│   ├── workflow/          20 skills — decomposed CRÉER/CRITIQUER pipeline + depth-classifier
│   ├── research/          6 skills — web / github-issues / forums / validate / synthesize / fact-check
│   ├── domain/            10 skills — frontend/backend/db/security/api/observability/perf/refactor/a11y/cicd
│   ├── utility/           8 skills — commit/PR/issue/changelog/staging/branch/pr-body helpers
│   └── meta/              5 skills — ciel-improve, skill-creator, variant-evaluator, learnings-capture, skill-freshness-auditor
├── agents/                4 thin orchestrators — researcher, explorer, critic, improver
├── commands/              7 slash commands — /ciel-audit, /ciel-init, /ciel-update, /ciel-improve, /ciel-create-skill, /ciel-eval, /ciel-recommend, /ciel-refresh
├── hooks/                 9 hook events — session-start, user-prompt-submit, pre/post-tool-write, pre/post-tool-count (v2.5.0), pre-compact, subagent-stop, stop
├── evals/                 Self-improvement harness — datasets, runners, results
└── platforms/             Generated platform builds — OpenCode (native TS plugin + subagents + commands), Cursor, Windsurf, Codex, Kilo, Ollama, LM Studio
```

Note: `/ciel` and `/ciel-improve` have no command file on Claude Code — Claude Code auto-routes `/<name>` to the same-named skill. On OpenCode, thin-wrapper command files exist (9 total) because OpenCode's slash router doesn't auto-route.

## Platform Support

| Platform | Files installed | Discipline enforcement |
|----------|----------------|-----------------------|
| **Claude Code** | `~/.claude/skills/`, `~/.claude/agents/`, `~/.claude/commands/`, `~/.claude/plugins/ciel/hooks/` | **Full** — mechanical dispatch-gate counter, RELIRE dispatch, meta-critiquer on Stop |
| **OpenCode** | `./.opencode/plugins/ciel.ts` + `./.opencode/agents/` + `./.opencode/commands/` + `./AGENTS.md` + merged `./opencode.json` | **Partial** — FAIRE reminders + RELIRE sticky + depth classification via TS plugin (mechanical counter port planned in a future release — see CHANGELOG) |
| **Cursor** | `.cursor/rules/ciel.mdc` | Static rules file (≤ 6KB compressed) |
| **Windsurf** | `.windsurf/rules/ciel.md` | Static rules file (≤ 6KB compressed) |
| **Codex CLI** | `AGENTS.md` | Medium-compressed (≤ 64KB, inlined workflow skills) |
| **Kilo Code** | `.kilocode/rules/ciel.md` + `.kilo/agents/` | Medium-compressed with agents |
| **Ollama** | `Modelfile` (baked SYSTEM) | ~300 tokens core principles |
| **LM Studio** | `system-prompt.md` (copy-paste) | ~200–500 tokens |

Full self-improvement subsystem (eval harness, transcript analysis) runs on Claude Code. Other platforms receive stable snapshots; improvements are rebuilt into platforms via `scripts/build-platforms.sh`.

## Install

### Linux / macOS

```bash
# Universal installer — auto-detects your tools (Claude / OpenCode / etc.)
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)

# Claude Code (official plugin)
claude plugin install github:KaosKyun/Ciel

# Manual — clone and run installer
git clone https://github.com/KaosKyun/Ciel.git ~/.ciel
bash ~/.ciel/scripts/install.sh [project-root]
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.ps1 | iex
claude plugin install github:KaosKyun/Ciel
```

After install, **run `/ciel-init --user` in a fresh Claude Code session, then restart Claude Code**. This merges Ciel hooks into `~/.claude/settings.json` (user-scope = active regardless of CWD). Without this, hooks silently do nothing — including the mechanical dispatch-gate counter.

On OpenCode, the installer copies `.opencode/plugins/ciel.ts` + agents + commands + merges `opencode.json` non-destructively. No restart required for OpenCode unless you were already in a session.

The installer creates `ciel-overlay.md` in your project root (fill in your stack versions and CI config).

## Usage

```
/ciel <task description>                  # Main entry — depth classification + routing
/ciel-init [--user] [--check]             # Wire hooks into .claude/settings.json (or ~/.claude/settings.json with --user)
/ciel-audit                               # Audit current session, produce copy-paste report (hook-independent)
/ciel-refresh [scope] [--force]           # Scan skills for stale external refs (URLs, lib versions, citations)
/ciel-improve                             # Analyze recent sessions, propose skill improvements (transcript-driven)
/ciel-recommend                           # Discover community plugins for your stack
/ciel-create-skill <name> <purpose>       # Create a new skill
/ciel-eval [skill-name]                   # Run eval harness on one or all skills
/ciel-update                              # Self-update from GitHub (preserves user config)
```

On Claude Code, skills trigger automatically based on their YAML `description` field. The orchestrator `skills/ciel/` routes from `/ciel <task>` based on depth (Trivial / Standard / Critical).

On OpenCode, the same slash commands work via the TS plugin routing into the same skills (which live at `./.claude/skills/` and are read natively by OpenCode per its docs).

## Project overlay

Project-specific config lives in `ciel-overlay.md`:

```markdown
# ciel overlay — My Project
## Stack
- Frontend: React 19.0.0
- Backend: Ktor 3.0.0
## Versions (pour RECHERCHE)
- react: 19.0.0 — https://react.dev
## CI
- Staging: https://staging.example.com
- Deploy: git push origin branch (~30s)
## Leçons projet
- [date] MISTAKE: ... → RULE: ...
```

## Hooks (Claude Code)

9 hook events wired via `~/.claude/settings.json`:

| Event | Matcher | Purpose | Behavior |
|---|---|---|---|
| `SessionStart` | — | Banner, load overlay, TRACE_ID | `systemMessage` banner |
| `UserPromptSubmit` | — | Pre-classify depth | `additionalContext` injection |
| `PreToolUse` | `Write\|Edit` | FAIRE gates reminder | `systemMessage` injection |
| `PreToolUse` | `Bash\|Read\|Grep\|Glob` | Dispatch-gate counter (v2.5.0) | Under 5 → `systemMessage` with counter; at 5+ → **hard-stop via `permissionDecision:"deny"`** |
| `PostToolUse` | `Write\|Edit` | RELIRE dispatch after 3+ files or critical file | `systemMessage` reminder |
| `PostToolUse` | `Bash\|Read\|Grep\|Glob\|Task` | Counter increment + reset-on-Task | State file `/tmp/ciel-counter-$session_id` |
| `PreCompact` | — | Save session-progress | `systemMessage` nudge |
| `SubagentStop` | — | Log report size | (passive) |
| `Stop` | — | Meta-critique + learnings capture | `decision:"block"` with reason (loop-guarded via `stop_hook_active`) |

The `PreToolUse` counter hook is the only hook that blocks tool calls — all others inject context only. On OpenCode, equivalent behaviors live in the TS plugin (`platforms/opencode/.opencode/plugins/ciel.ts`) using `experimental.chat.system.transform`, `experimental.chat.messages.transform`, and `tool.execute.after`.

## Self-improvement

Ciel can **create, improve, and audit its own skills**. Three orthogonal axes:

- **`/ciel-improve`** (transcript-driven) — reads the last N session transcripts, detects repeated failure modes, produces a patch-set with before/after diffs (user approval, never autonomous rewrite).
- **`/ciel-refresh`** (outside-world-driven) — scans every `SKILL.md` for stale external references (library version pins, URLs, research citations), produces a freshness patch-set. Complements `/ciel-improve` on an orthogonal axis.
- **`/ciel-eval`** — runs binary evals per skill (`evals/datasets/*.jsonl`), compares variant scores, proposes the winner.
- **`/ciel-create-skill <name> <purpose>`** — generates a valid SKILL.md scaffold with YAML frontmatter, progressive-disclosure reference file.

The self-improvement subsystem is **closed-loop**: session → evals → patches → review → CHANGELOG entry with fix/revert ratio.

## Self-update

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh) --update
# or (if you already have the plugin installed)
bash ~/.claude/plugins/ciel/scripts/install.sh --update
# or (from a repo clone)
bash /path/to/Ciel/scripts/install.sh --update
```

The network one-liner includes cache-bust headers (v2.4.7) so you always get the freshly-pushed version, not the CDN-cached one. User config is preserved across update — `.mcp.json`, `ciel-overlay.md`, `opencode.json`, `.claude/settings.json` are all whitelisted (v2.4.6).

## Versions & metrics

See [CHANGELOG.md](CHANGELOG.md) — each version records the change set and, where measurable, observed fix/revert ratio.

## Research basis

Built from:
- Audit of 675 commits (62.8% fix/revert with v1.x monolithic skill)
- Anthropic Skills-first paradigm — "Stop building agents, build Skills" (Barry Zhang / Mahesh Murag, AI Engineer Code Summit)
- [MAR — Multi-Agent Reflexion](https://arxiv.org/html/2512.20845) (degeneration of thought in single-agent critique)
- [SICA — Self-Improving Coding Agent](https://arxiv.org/html/2504.15228v2) (17→53% improvement via self-edit + metrics)
- [Reflexion](https://arxiv.org/abs/2405.06682) (self-reflection improves problem-solving, p < 0.001)
- [Process debt research](https://planally.com/why-process-debt-is-the-new-tech-debt/) (monolithic process = friction = skipping)
- CriticBench 2024 — self-critique is the hardest critique mode for LLMs (motivates fresh-fork dispatch)
