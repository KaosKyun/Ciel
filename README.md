# Ciel

> *Named after the Primordial Sage from Tensura — the advisor who reasons at infinite speed before Rimuru acts.*

Skills-first deep-reasoning plugin for LLM-assisted development. **v2.0.0 total refactor** toward the Anthropic Skills-first paradigm: one generic orchestrator + library of 33 specialized skills > many specialized agents.

Principle: **"Understand before generating. Verify before claiming done."**

## The problem it solves

| LLM default behavior | Ciel solution |
|---|---|
| Skip research ("I already know this") | `research/*` skills — specialized per source (web, GitHub issues, forums) |
| Copy patterns without fitness check | `workflow/pattern-fitness-check` — 3-question fitness gate |
| Self-critique in same context = same blind spots | `critic` agent → `relire-critic` skill in fresh fork |
| "Done" = code written | `workflow/prouver-verifier` — staging evidence gates |
| Process skipped for "simple" tasks | Hooks — 7 events, deterministic enforcement |
| No feedback loop on process quality | `meta/ciel-improve` + `meta/skill-variant-evaluator` — auto-refine skills from session transcripts |
| Monolithic SKILL.md rots and gets skipped | 33 specialized skills, each ≤ 500 lines, composable and testable |

**Baseline**: 62.8% fix/revert ratio on Neiyomi with v1.x monolithic dev-reasoning skill (2026-04-04). v2.0.0 target: < 45% (reference SICA: 17 → 53%).

## Architecture (v2.0.0)

```
ciel/
├── skills/
│   ├── ciel/              Orchestrator (~220 lines) — classifies depth, routes to skills
│   ├── workflow/          13 skills — the old CRÉER/CRITIQUER pipeline, decomposed
│   ├── research/          6 skills — meta-research (web, github, forums, validate, synthesize, fact-check)
│   ├── domain/            8 skills — frontend/backend/db/security/api/observability/perf/refactor
│   ├── utility/           5 skills — commit/PR/issue/changelog/staging helpers
│   └── meta/              4 skills — ciel-improve, skill-creator, variant-evaluator, learnings-capture
├── agents/                4 thin orchestrators — researcher, explorer, critic, improver
├── commands/              6 commands — /ciel, /ciel-recommend, /ciel-update, /ciel-improve, /ciel-create-skill, /ciel-eval
├── hooks/                 7 hook events — session-start, user-prompt-submit, pre/post-tool-write, pre-compact, subagent-stop, stop
├── evals/                 Self-improvement harness — datasets, runners, results
└── platforms/             Auto-generated compressed versions for Cursor/Windsurf/Codex/OpenCode/Kilo/Ollama/LM Studio
```

## Platform Support

| Platform | File installed | Size | Compression |
|----------|---------------|------|-------------|
| **Claude Code** | `~/.claude/plugins/ciel/` | full | **Native Skills architecture** |
| **Cursor** | `.cursor/rules/ciel.mdc` | ≤ 3.5 KB | Heavy (essentials only) |
| **Windsurf** | `.windsurf/rules/ciel.md` | ≤ 3.5 KB | Heavy |
| **Codex CLI** | `AGENTS.md` | ≤ 30 KB | Medium (inlined workflow skills) |
| **OpenCode** | `AGENTS.md` + `opencode.json` | ≤ 30 KB | Medium |
| **Kilo Code** | `.kilocode/rules/ciel.md` + `.kilo/agents/` | ≤ 30 KB | Medium |
| **Ollama** | `Modelfile` (baked SYSTEM) | ~300 tokens | Extreme (core principles) |
| **LM Studio** | `system-prompt.md` (copy-paste) | ~200–500 tokens | Extreme |

Full self-improvement subsystem runs **only on Claude Code** (requires fork contexts + session transcripts). Other platforms receive stable snapshots; improvements are rebuilt into platforms via `scripts/build-platforms.sh`.

## Install

### Linux / macOS

```bash
# Universal installer — auto-detects your tools
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

The installer detects which AI tools are present and copies the right files for each. It creates `ciel-overlay.md` in your project root (fill in your stack versions and CI config). On Windows, `settings.json` hooks are automatically wired with `pwsh -File` commands.

## Usage

```
/ciel <task description>          # Main entry — depth classification + routing
/ciel-recommend                   # Discover community plugins for your stack
/ciel-improve                     # Analyze recent sessions, propose skill improvements
/ciel-create-skill <name> <purpose>   # Create a new skill
/ciel-eval [skill-name]           # Run eval harness on one or all skills
/ciel-audit                       # Audit current session, produce copy-paste report (hook-independent)
/ciel-update                      # Self-update from GitHub
```

On Claude Code, skills trigger automatically based on their YAML `description` field — you don't have to remember which one to use. The orchestrator `skills/ciel/` routes from `/ciel <task>` based on depth (Trivial / Standard / Critical).

On other platforms, Ciel is always active via rules files.

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

## Hooks

7 hook events wired via `settings.json` on Claude Code:

| Event | Purpose | Skill triggered |
|---|---|---|
| `SessionStart` | Banner, load overlay, TRACE_ID | — |
| `UserPromptSubmit` | Pre-classify depth | `depth-classifier` (light) |
| `PreToolUse` (Write/Edit) | FAIRE gates reminder | `faire-gatekeeper` |
| `PostToolUse` (Write/Edit) | RELIRE dispatch | `relire-critic` |
| `PreCompact` | Save session-progress | `learnings-capture` |
| `SubagentStop` | Log report size | (passive) |
| `Stop` | Meta-critique | `meta-critiquer` |

Hooks never block writes — they inject context via `hookSpecificOutput.additionalContext`.

## Self-improvement

Ciel can **create and improve its own skills**:

- `/ciel-improve` → reads the last N session transcripts, detects repeated failure modes, produces a patch-set with before/after diffs (for user approval — never autonomous rewrite)
- `/ciel-eval` → runs binary evals per skill (`evals/datasets/*.jsonl`), compares variant scores, proposes the winner
- `/ciel-create-skill <name> <purpose>` → generates a valid SKILL.md scaffold with YAML frontmatter, progressive-disclosure reference file, and registers it

The self-improvement subsystem is **closed-loop**: session → evals → patches → review → CHANGELOG entry with fix/revert ratio.

## Self-update

```bash
bash ~/.claude/plugins/ciel/scripts/self-update.sh     # Linux/macOS
pwsh ~/.claude/plugins/ciel/scripts/self-update.ps1    # Windows
```

Requires `gh` CLI authenticated (`gh auth login`).

## Versions & metrics

See [CHANGELOG.md](CHANGELOG.md) — each version records the observed fix/revert ratio before and after.

## Research basis

Built from:
- Audit of 675 commits (62.8% fix/revert with v1.x monolithic skill)
- Anthropic Skills-first paradigm — "Stop building agents, build Skills" (Barry Zhang / Mahesh Murag, AI Engineer Code Summit)
- [MAR — Multi-Agent Reflexion](https://arxiv.org/html/2512.20845) (degeneration of thought in single-agent critique)
- [SICA — Self-Improving Coding Agent](https://arxiv.org/html/2504.15228v2) (17→53% improvement via self-edit + metrics)
- [Reflexion](https://arxiv.org/abs/2405.06682) (self-reflection improves problem-solving, p < 0.001)
- [Process debt research](https://planally.com/why-process-debt-is-the-new-tech-debt/) (monolithic process = friction = skipping)
