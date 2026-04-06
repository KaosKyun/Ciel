# Ciel

> *Named after the Primordial Sage from Tensura — the advisor who reasons at infinite speed before Rimuru acts.*

Universal deep-reasoning workflow plugin for LLM-assisted development. Distributed across 5 enforcement layers to eliminate the systematic failure modes of single-skill AI workflows.

## The problem it solves

| LLM default behavior | Ciel solution |
|---|---|
| Skip research ("I already know this") | `researcher` agent — mandatory, isolated context |
| Copy patterns without fitness check | `explorer` agent — 3-question fitness check on every pattern |
| Self-critique in same context = same blind spots | `critic` agent — fresh context, MAR-inspired isolation |
| "Done" = code written | `PROUVER` — staging evidence mandatory before PR |
| Process skipped for "simple" tasks | Hooks — deterministic enforcement on every file write |
| No feedback loop on process quality | `CHANGELOG` — fix/revert ratio tracked per version |

**Baseline**: 62.8% fix/revert ratio on Neiyomi with monolithic dev-reasoning skill (2026-04-04).

## Architecture

```
Layer 1 — ciel-overlay.md    Project context (stack, versions, rules) — always loaded
Layer 2 — hooks/             Deterministic enforcement — never bypassable
Layer 3 — skills/ciel/       CRÉER/CRITIQUER workflow — explicit invocation
Layer 4 — agents/            researcher + explorer + critic — isolated contexts
Layer 5 — CHANGELOG.md       Fix/revert metrics per version — closed feedback loop
```

## Platform Support

| Platform | File installed | Size | Notes |
|----------|---------------|------|-------|
| **Claude Code** | `~/.claude/skills/ciel/SKILL.md` | 27KB | Full workflow + hooks + agents |
| **Cursor** | `.cursor/rules/ciel.mdc` | 4KB | MDC format, compressed, under 6KB limit |
| **Windsurf** | `.windsurf/rules/ciel.md` | 3.8KB | Plain MD, under 6KB limit |
| **Codex CLI** | `AGENTS.md` | 27KB | Full workflow, under 32KB limit |
| **OpenCode** | `AGENTS.md` + `opencode.json` | 27KB | Full workflow |
| **Kilo Code** | `.kilocode/rules/ciel.md` | 27KB | Full workflow |
| **Ollama** | `Modelfile` (baked SYSTEM) | — | `ollama create ciel -f Modelfile` |
| **LM Studio** | `system-prompt.md` (copy-paste) | — | Paste into Settings → System Prompt |

**Cursor/Windsurf note**: due to the 6KB per-file limit, these platforms receive a compressed version covering all key principles, the 10-step pipeline, top guards, and context budget. Full docs remain at this repo.

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
# Universal installer — auto-detects your tools
irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.ps1 | iex

# Claude Code (official plugin)
claude plugin install github:KaosKyun/Ciel

# Manual — clone and run installer
git clone https://github.com/KaosKyun/Ciel.git ~/.ciel
pwsh ~/.ciel/scripts/install.ps1 [project-root]
```

The installer detects which AI tools are present and copies the right files for each. It also creates `ciel-overlay.md` in your project root (fill in your stack versions and CI config). On Windows, `settings.json` hooks are automatically wired with `pwsh -File` commands instead of `bash`.

### Per-platform quick install

**Linux / macOS:**

```bash
# Cursor only
mkdir -p .cursor/rules && curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/platforms/cursor/.cursor/rules/ciel.mdc -o .cursor/rules/ciel.mdc

# Windsurf only
mkdir -p .windsurf/rules && curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/platforms/windsurf/.windsurf/rules/ciel.md -o .windsurf/rules/ciel.md

# Codex / OpenCode / Kilo — AGENTS.md
curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/platforms/codex/AGENTS.md -o AGENTS.md

# Ollama
curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/platforms/ollama/Modelfile -o Modelfile
# Edit FROM line, then: ollama create ciel -f Modelfile
```

**Windows (PowerShell):**

```powershell
# Cursor only
New-Item -ItemType Directory -Force .cursor/rules | Out-Null
irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/platforms/cursor/.cursor/rules/ciel.mdc -OutFile .cursor/rules/ciel.mdc

# Windsurf only
New-Item -ItemType Directory -Force .windsurf/rules | Out-Null
irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/platforms/windsurf/.windsurf/rules/ciel.md -OutFile .windsurf/rules/ciel.md

# Codex / OpenCode / Kilo — AGENTS.md
irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/platforms/codex/AGENTS.md -OutFile AGENTS.md

# Ollama
irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/platforms/ollama/Modelfile -OutFile Modelfile
# Edit FROM line, then: ollama create ciel -f Modelfile
```

After installing, bootstrap your project overlay:

```bash
cp ciel-overlay-template.md ciel-overlay.md   # or let the installer create it
# Fill in: stack versions, CI URL, deploy commands, critical file patterns
```

## Usage

```
/ciel <task description>          # Claude Code
# Other platforms: Ciel is always-active via rules files
```

Ciel classifies the task depth (Trivial/Standard/Critical), dispatches researcher + explorer in parallel, enforces RELIRE via an isolated critic session, and requires staging evidence before done.

## Portability

Ciel is stack-agnostic. Project-specific config lives in `ciel-overlay.md`:

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
```

The overlay stays in your project. The plugin stays generic.

## Hooks behavior

Each hook has a `.sh` (Linux/macOS) and a `.ps1` (Windows) variant — same logic, same output format.

- **`pre-write-gate`** — Before any code file write: injects FLUX checkpoint reminder. Critical files (auth/, Service, Route...) get a stronger STRIDE reminder.
- **`post-write-relire`** — After any code file write: injects mandatory critic dispatch instruction.

Hooks inject context — they never block writes.

To wire hooks manually in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{ "matcher": "Write|Edit", "hooks": [
      { "type": "command", "command": "bash ~/.claude/plugins/ciel/hooks/pre-write-gate.sh" }
    ]}],
    "PostToolUse": [{ "matcher": "Write|Edit", "hooks": [
      { "type": "command", "command": "bash ~/.claude/plugins/ciel/hooks/post-write-relire.sh" }
    ]}]
  }
}
```

On Windows, replace `bash ... .sh` with `pwsh -File ... .ps1`.

## Self-update

```bash
# Linux / macOS
bash ~/.claude/plugins/ciel/scripts/self-update.sh

# Windows
pwsh ~/.claude/plugins/ciel/scripts/self-update.ps1
```

Requires `gh` CLI authenticated (`gh auth login`). Compares local SHA with remote — downloads only if a new version is available.

## Versions & metrics

See [CHANGELOG.md](CHANGELOG.md) — each version records the observed fix/revert ratio before and after.

## Research basis

Built from:
- Audit of 675 commits (62.8% fix/revert with monolithic skill)
- [MAR — Multi-Agent Reflexion](https://arxiv.org/html/2512.20845) (degeneration of thought in single-agent critique)
- [SICA — Self-Improving Coding Agent](https://arxiv.org/html/2504.15228v2) (17→53% improvement via self-edit + metrics)
- [Reflexion](https://arxiv.org/abs/2405.06682) (self-reflection improves problem-solving, p < 0.001)
- [Process debt research](https://planally.com/why-process-debt-is-the-new-tech-debt/) (monolithic process = friction = skipping)
