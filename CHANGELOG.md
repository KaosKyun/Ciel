# Ciel — Changelog

## v2.1.5 — 2026-04-17 — autonomy protocol (gather before asking)

**Context** — Ciel agents were written with "bail out and ask the user" logic ("If REPRO is missing → STOP" in `debug-reasoning-rca`). This treats the user as a form to fill in, instead of treating the agent as capable of gathering context. An autonomous agent should exhaust available sources (git, filesystem, overlay, tool calls, MCP) before asking.

### Added

- **`skills/ciel/SKILL.md`** — new "Autonomy protocol" section defining the 7-source gather order (user prompt → overlay → git state → filesystem → tool invocations → MCP → codebase grep) and the `[ASSUMED from <source>]` / `[GIVEN by user]` / `[UNKNOWN]` annotation format that every dispatched skill must emit.
- **Individual skill INPUTS sections updated** with explicit "Auto-inference sources" — each input documents how to obtain it without asking:
  - `debug-reasoning-rca` — SYMPTOM from error logs, REPRO from package scripts / Playwright MCP, SCOPE from `git diff` + `git blame`, RECENT_CHANGES from `git log --since="7 days ago"`
  - `doc-validator-official` — PACKAGE_SOURCES from manifest glob, TARGET_STACK from manifest reads, PROPOSED_APIS from task description parse
  - `ai-failure-modes-detector` — AUTHOR from commit trailer (`Claude Code` = LLM), TEST_COVERAGE from filesystem existence, PROPOSED_DEPS from manifest diff
  - `modern-patterns-checker` — CODE_UNDER_REVIEW from branch diff, TARGET_STACK from manifests

### Behavioral change

Before (interrogative):
```
User: /ciel my library update broke production
Ciel: Can you tell me: what library? what error? what command?
```

After (autonomous):
```
User: /ciel my library update broke production
Ciel: [ASSUMED] lib = @auth/core 3→4 from package.json diff, error = logs show
"useAuth undefined" 1243x, repro = curl .../login returns 500. Dispatching
@ciel-critic MODE=RCA...
```

### When Ciel still asks

Only when a critical input cannot be gathered after exhausting all sources (e.g., greenfield project with no manifests at all). Always ONE specific question with 2-3 concrete options — never open-ended "tell me more".

### Unchanged

Dispatch directive (v2.1.4), intent routing (v2.1.3), installer, manifest, skills inventory — all intact.

---

## v2.1.4 — 2026-04-17 — force Task-dispatch for fork-context skills

**Context** — v2.1.3 made the orchestrator route intents to the correct Ciel skill (e.g., debug → `debug-reasoning-rca`), but Claude invoked it **inline via the Skill tool** in the main session. The skill's frontmatter declares `context: fork` + `agent: critic` — meaning it's supposed to run in a forked subagent context for blind-spot mitigation (CriticBench 2024). Inline invocation defeats the architecture: same-session critique of same-session work = degenerate self-review.

### Fixed

- **`skills/ciel/SKILL.md`** — added a "Dispatch directive" section after the intent routing table. Explicitly maps each `context: fork` Ciel skill to a `Task(@ciel-<role>, '...')` dispatch, NOT a `Skill(<name>)` inline. Lists the inline-OK exceptions (`depth-classifier`, `quoi-framer`, `faire-gatekeeper`, `meta-critiquer`, `prouver-verifier`, etc.) and the anti-pattern to avoid.

### Rationale

| Skill frontmatter | Invocation | Why |
|---|---|---|
| `context: fork` + `agent: X` | `Task(@ciel-X, ...)` | Fresh context — blind-spot mitigation, isolated tool permissions, main session stays lean |
| No `context: fork` | `Skill(...)` inline | Deterministic / lightweight — fork overhead unjustified |

### Effect

- `/ciel debug production issue` → now triggers `Task(@ciel-critic, 'MODE=RCA ...')` instead of inline `Skill(debug-reasoning-rca)`. The critic runs in a fork with fresh context, its own RCA hypotheses, and `edit: false` tool permission.
- Same story for `doc-validator-official`, `modern-patterns-checker`, `playwright-visual-critic`, `cicd-security-hardener`, `accessibility-wcag-auditor`, `skills-first-design-auditor`, `self-consistency-verifier`, `ai-failure-modes-detector`, and all `skills/research/*`.

### Unchanged

Inline pipeline skills (`quoi-framer`, `depth-classifier`, `avec-quoi-versioner`, `faire-gatekeeper`, `evaluer-sizer`, `relire-critic` for Trivial/Standard <3 files, `meta-critiquer`, `prouver-verifier`, `synthesize-findings`, `learnings-capture`) still run inline — fork would be overkill.

---

## v2.1.3 — 2026-04-17 — hotfix: orchestrator routes v2.1.0 skills + command frontmatter

**Context** — On a live install, `/ciel debug this production issue` invoked Claude Code's native `systematic-debugging` skill instead of Ciel's `debug-reasoning-rca`. Root cause: the `skills/ciel/SKILL.md` orchestrator was written for v2.0.0 and never updated to reference the 10 new v2.1.0 skills. Claude's skill-matcher fell back to the native skill with the closest description. Separately, `commands/*.md` lacked YAML frontmatter, which on some Claude Code versions caused `Unknown command: /ciel`.

### Fixed

- **`skills/ciel/SKILL.md`** — added "Intent routing (v2.1.0 skills)" section mapping debugging/docs/testing/a11y/CI-CD/UI-critique intents to the correct Ciel skill + dispatcher. Includes an anti-collision rule: "systematic debugging", "root cause analysis", "bug investigation" MUST route to `debug-reasoning-rca`, never to native `systematic-debugging`.
- **`skills/workflow/debug-reasoning-rca/SKILL.md`** — strengthened YAML `description` to include "systematic debugging" / "THE skill to invoke for ANY bug" so semantic matching prefers it over the native.
- **`commands/*.md`** — added YAML frontmatter (`description:`) to all 6 commands for proper Claude Code slash-command registration.
- **`commands/ciel.md`** — body updated to document the intent-matching step explicitly.

### Unchanged

Installer, manifest, update flow (v2.1.2's semver guard), hooks — nothing else touched.

### Effect

- `/ciel debug X` now routes to `debug-reasoning-rca` via `@ciel-critic` MODE=RCA (3 hypotheses, fault-type taxonomy) instead of the generic native `systematic-debugging`.
- `/ciel <task>` no longer triggers "Unknown command" on fresh installs.
- All 10 v2.1.0 skills are now explicitly reachable via natural-language intent signals.

---

## v2.1.2 — 2026-04-17 — hotfix: semver guard + CDN staleness

**Context** — A live `--update` run produced a bewildering loop: remote `VERSION` was served stale by the GitHub raw CDN (5 min `max-age`), returning `2.1.0` while the user's local manifest already had `2.1.1`. The v2.1.1 check used string equality (`!=`), so "remote 2.1.0 ≠ local 2.1.1" was flagged as an "update available" — pointing DOWN. `_do_update` ran, executed uninstall, then the re-entry used the ALSO-cached v2.1.0 script from `curl` (the CDN doesn't discriminate per-file), re-triggering the `BASH_SOURCE[0]: unbound variable` that was supposedly fixed in v2.1.1 — because the CDN was serving the pre-fix script.

### Fixed

- **`_check_update`** now parses X.Y.Z semver and only returns "update available" (code `2`) when `remote > local`. When `remote < local` (CDN stale / dev build), it reports "Up to date. (local ahead of remote — CDN stale or dev build; nothing to do.)" and returns `0`.
- **`_check_update`** also sends `Cache-Control: no-cache` + `Pragma: no-cache` + a cache-busting `?t=<epoch>` query param on the `VERSION` request to reduce staleness (CDN usually honors at least one).
- Added `_semver_cmp` helper (pure-bash, no external tool required).

### Unchanged

Everything from v2.1.1 (tri-state `_check_update`, `${BASH_SOURCE[0]:-}` guard, `bash <(curl ...)` re-entry) is intact.

### Recovery for users bitten by the loop

If your install was wiped by the v2.1.0 or v2.1.1 `--update` loop, restore fresh:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
```

Do NOT use `--update` until your `curl https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION` returns `2.1.2` (wait up to 5 min for CDN).

---

## v2.1.1 — 2026-04-17 — hotfix: `--update` flow

**Context** — v2.1.0's `--update` had two production bugs surfaced on a live install:

1. **`_check_update` return code was ambiguous** — it returned `0` whether you were up-to-date or a new version existed. `_do_update` therefore ran the uninstall + re-install cycle even when nothing had changed, destroying a perfectly good install.
2. **`curl | bash -s --` tripped `set -u`** — the re-entry via `bash -s` leaves `BASH_SOURCE[0]` unset, and the tmp-clone guard read `${BASH_SOURCE[0]}` directly. Result: `unbound variable` exit, install left in a half-removed state.

### Fixed

- **`scripts/install.sh`** — `_check_update` now returns tri-state (`0`=up-to-date, `2`=update available, `1`=error). `_do_update` branches on this and short-circuits cleanly when already current.
- **`scripts/install.sh`** — tmp-clone guard reads `${BASH_SOURCE[0]:-}` via an intermediate variable. Both `curl | bash -s` (stdin) and `bash <(curl ...)` (process substitution) now fall through to the clone path without crashing.
- **`_do_update`** — re-entry now uses `bash <(curl ...)` instead of `curl | bash -s --`, ensuring `BASH_SOURCE[0]` is defined in the child shell.

### Unchanged

Everything else from v2.1.0 (10 skills, MCP opt-in, manifest, uninstall, SessionStart banner) is intact.

### If you were bitten by the bug

Your install was uninstalled but not re-installed. Restore with a fresh install:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
```

---

## v2.1.0 — 2026-04-17 — 10 new skills + MCP opt-in + uninstall/update

**Context** — v2.0.0 landed the skills-first architecture but left gaps in the reasoning coverage (no debugging RCA, no official-doc validator, no anti-pattern 2026 guardrail, no AI-failure-mode detector), did not exploit available MCP servers (Playwright for visual critique, Context7 for live docs), and the installer had no clean uninstall or update path. v2.1.0 closes all three gaps in one pass.

### Added — 10 new skills

- **`skills/workflow/debug-reasoning-rca/`** — Root-Cause Analysis with 3 parallel hypotheses, fault-type classification (model/context/orchestration/environment), semantic diff. Dispatched via `@ciel-critic`. 75% MTTR reduction target (STRATUS).
- **`skills/workflow/doc-validator-official/`** — Fetches official docs for the pinned lib version, validates every proposed API call, rejects Stack Overflow as primary source. Flags cutoff-warning for libs post-January 2026. Dispatched via `@ciel-researcher`.
- **`skills/workflow/modern-patterns-checker/`** — Detects obsolete patterns (React classes, Python 2, sync-in-async, CommonJS in ESM, old Go error handling) with 2026 canonical replacements. ThoughtWorks Technology Radar April 2026.
- **`skills/workflow/ai-failure-modes-detector/`** — Six canonical LLM failure modes: invented APIs, hallucinated deps, version drift, async/sync mismatch, confident-wrong, extrinsic hallucination. Dispatched via `@ciel-explorer`.
- **`skills/workflow/self-consistency-verifier/`** — IdentityChain pattern: 3 diverse solutions, AST compare, behavioral compare, consistency score. Dispatched via `@ciel-critic` for Critical tasks.
- **`skills/workflow/test-strategy-vitest-playwright/`** — Pyramid 70/20/10 (unit/integration/E2E), Vitest + MSW + Playwright + fast-check. Accessibility-tree assertions over screenshots.
- **`skills/workflow/playwright-visual-critic/`** — Wraps Playwright MCP: navigate → accessibility-tree snapshot → dispatch `@ciel-critic`. Requires `--with-mcp=playwright`. Documents OpenCode gap #2319.
- **`skills/domain/cicd-security-hardener/`** — SLSA Level 3 baseline, Sigstore/Cosign keyless, ephemeral runners, SBOM, no long-lived cloud credentials, no `pull_request_target` with untrusted checkout.
- **`skills/domain/accessibility-wcag-auditor/`** — WCAG 2.2 AA (legal baseline April 2026 via ADA Title II / EN 301 549). Focus Not Obscured 2.4.11, Target Size 2.5.8, Accessible Auth 3.3.8. Manual + automated layers.
- **`skills/meta/skills-first-design-auditor/`** — Lints new skills against Anthropic's April 2026 skills guide (≤500 lines, 2-3 examples, executable checks, clear trigger). Dispatched via `@ciel-improver`.

### Added — MCP integration

- **`.mcp.json`** — project-scope template with `playwright` (@playwright/mcp) and `context7` (@upstash/context7-mcp). Opt-in only.
- **`install.sh --with-mcp=playwright,context7`** — merges selected servers into `$PROJECT_ROOT/.mcp.json`. Backs up any existing file.
- **AGENTS.md** (OpenCode) — documents MCP workflow and OpenCode gap #2319 (plugin hooks do NOT see MCP tool calls; `playwright-visual-critic` orchestrates the critic dispatch explicitly).

### Added — installer uninstall / update

- **`VERSION`** — root file holding `2.1.0`. Compared against GitHub main by `--check-update`.
- **`~/.ciel/manifest.json`** — generated on every install. Lists version, installed_at, platforms, mcp servers, and the full list of tracked files. Enables clean uninstall.
- **`install.sh --uninstall`** — iterates manifest `files[]`, prompts confirmation (skippable with `-y`), preserves whitelist (`.mcp.json`, `ciel-overlay.md`, `AGENTS.md`).
- **`install.sh --check-update`** — non-blocking (`curl --max-time 5`) fetch of remote `VERSION`, compares, prints banner if newer.
- **`install.sh --update`** — requires manifest, runs uninstall-then-reinstall from the latest main branch.
- **`hooks/session-start.{sh,ps1}`** — throttled 24h update check (curl max 2s, silent on failure). Surfaces `[UPDATE] Ciel vX → vY available` banner in the session banner.
- **`commands/ciel-update.md`** — rewritten to delegate to `install.sh --update` / `--check-update`.

### Changed

- **`scripts/build-platforms.sh`** — `LIMIT_opencode_agent` bumped from 49152 to 65536 (bundles now include 6 additional skills inline/compact across roles). Routing matrix adds: `doc-validator-official` → researcher (inline); `modern-patterns-checker` + `ai-failure-modes-detector` → explorer (inline); `test-strategy-vitest-playwright` + `playwright-visual-critic` → explorer (compact); `cicd-security-hardener` + `accessibility-wcag-auditor` → explorer domain (compact); `debug-reasoning-rca` + `self-consistency-verifier` → critic (inline); `skills-first-design-auditor` → improver (inline).
- **`scripts/install.sh`** — refactored flag parser, added `INSTALLED_FILES` tracking, `_register_installed_files` post-install registry, `_install_mcp`, `_do_uninstall`, `_do_update`, `_check_update`, `_manifest_write`. Bumps banner to v2.1.0.

### Removed

- **`scripts/self-update.sh`** — deprecated in favor of `install.sh --update`. `gh` CLI no longer required for updates.

### Follow-up

- 5 platform issues (#2 Cursor, #3 Windsurf, #4 Codex, #5 Kilo, #6 LMStudio+Ollama) still open — when their native primitives are restored, they should bundle these 10 new skills as well.
- MCP opt-in wiring for OpenCode (the project-level `.mcp.json` works for Claude Code; OpenCode reads its own `opencode.json` mcp block — users may mirror).

---

## Unreleased — platforms: restore native OpenCode adaptation

**Context** — v2.0.0 replaced all platform-native adaptations with a single 907-line compressed `AGENTS.md` dump. The pre-refactor OpenCode integration (plugin with pre/post-write hooks, 3 ciel-* subagents, 2 commands) was deleted in the process. This lot restores OpenCode's native primitives and updates them to the v2 4-agent + 33-skill model.

### Added

- **`platforms/opencode/.opencode/plugins/ciel.ts`** — TypeScript plugin (port of `hooks/pre-tool-write.sh`, `post-tool-write.sh`, `user-prompt-submit.sh`). Fires on `tool.execute.before`, `tool.execute.after`, `chat.params`. Injects depth classification and FAIRE/RELIRE reminders. Pure TS, no shell dependency.
- **`platforms/opencode/.opencode/agents/ciel-{researcher,explorer,critic,improver}.md`** — 4 subagents with OpenCode frontmatter (`mode: subagent`, scoped tool permissions). Skills they invoke (`research/*`, `workflow/*`, `domain/*`, `meta/*`) are bundled inline since OpenCode has no native skills primitive — agents are self-sufficient.
- **`platforms/opencode/.opencode/commands/ciel*.md`** — 6 slash commands (`/ciel`, `/ciel-improve`, `/ciel-eval`, `/ciel-create-skill`, `/ciel-recommend`, `/ciel-update`) with OpenCode frontmatter (`agent`, `subtask`). Meta commands (`/ciel-improve`, `/ciel-eval`, `/ciel-create-skill`) noted as degraded without `claude --print` headless mode.
- **`build-platforms.sh`** — new helpers `bundle_skills_inline`, `emit_opencode_agent`, `emit_opencode_command`, `emit_opencode_plugin`, `emit_opencode_config`, `emit_opencode_agents_md`. Regex extracted as script-level variables (`CIEL_CRITICAL_FILE_RE`, `CIEL_CODE_EXT_RE`, etc.) — single source of truth shared with hooks.

### Changed

- **`platforms/opencode/AGENTS.md`** — reduced from 907-line dump (31KB) to a 3.5KB index pointing to the native primitives.
- **`platforms/opencode/opencode.json`** — now registers the `ciel.ts` plugin alongside `AGENTS.md` instructions.
- **`build-platforms.sh`** — converted `declare -A LIMITS` associative array to portable prefixed variables (`LIMIT_<name>`) for bash 3.2 compatibility (macOS default shell).

### Unchanged

No source-of-truth files (`skills/`, `agents/`, `hooks/`, `commands/`, `settings.json`) were modified — this lot only touches `platforms/opencode/` and `scripts/build-platforms.sh`.

### Follow-up

The 5 remaining platforms (Cursor, Windsurf, Codex, Kilo, LM Studio/Ollama) will each get a dedicated issue + PR restoring their native primitives. Current state on those platforms is still the compressed dump.

---

## v2.0.0 — 2026-04-17 — Skills-first total refactor

**BREAKING — total architecture rewrite aligned with Anthropic's Skills-first paradigm.**

### Context

Barry Zhang and Mahesh Murag (Anthropic, AI Engineer Code Summit): *"Stop building agents. Build Skills."* v1.x's 455-line monolithic SKILL.md violated the paradigm directly — it couldn't be selectively invoked, improved at failure granularity, or evaluated per-step. Philosophy was sound; implementation was monolithic.

### Added

- **33 specialized skills** organized in 5 categories:
  - `skills/workflow/` (13): `depth-classifier`, `quoi-framer`, `avec-quoi-versioner`, `stride-analyzer`, `pattern-fitness-check`, `evaluer-sizer`, `flux-narrator`, `faire-gatekeeper`, `security-regression-check`, `relire-critic`, `prouver-verifier`, `critiquer-auditor`, `meta-critiquer`
  - `skills/research/` (6): `research-web-sources`, `research-github-issues`, `research-forums`, `validate-source-credibility`, `synthesize-findings`, `fact-check-claims`
  - `skills/domain/` (8): `frontend-mastery`, `backend-mastery`, `database-mastery`, `security-hardening`, `api-architecture`, `observability`, `performance-engineering`, `refactoring-patterns`
  - `skills/utility/` (5): `commit-writer`, `pr-body-generator`, `issue-closer`, `changelog-updater`, `staging-verifier`
  - `skills/meta/` (4): `ciel-improve`, `skill-creator`, `skill-variant-evaluator`, `learnings-capture`
- **Self-improvement subsystem**: `/ciel-improve` analyses session transcripts → proposes patch-set for approval (never autonomous rewrite); `skill-variant-evaluator` runs binary evals via `claude --print`; `skill-creator` generates valid SKILL.md scaffolds
- **Eval harness** under `evals/`: datasets (4 seed), runners (`skill-eval.sh`, `run-evals.sh`), results/
- **Build-platforms script**: `scripts/build-platforms.sh` auto-generates Cursor/Windsurf/Codex/OpenCode/Kilo/Ollama/LM Studio artifacts from `skills/` — no more hand-maintaining per-platform files
- **4 hook events added**: `SessionStart`, `UserPromptSubmit`, `PreCompact`, `SubagentStop`, `Stop` (in addition to `PreToolUse` / `PostToolUse`)
- **3 new commands**: `/ciel-improve`, `/ciel-create-skill`, `/ciel-eval`
- **New agent**: `agents/improver.md` — long-running self-improvement meta-agent
- **New command**: `/ciel` (main entry point, was previously implicit)

### Changed

- **`skills/ciel/SKILL.md`**: rewritten from 455-line monolith to ~180-line orchestrator that routes to specialized skills. Full Guards table and extended philosophy moved to `skills/ciel/reference.md` (progressive disclosure).
- **`agents/{researcher,explorer,critic}.md`**: rewritten as thin orchestrators (~60-80 lines each). They invoke specialized skills rather than duplicating logic inline.
- **`hooks/pre-write-gate.sh`** → `hooks/pre-tool-write.sh` (renamed, updated to trigger `faire-gatekeeper` skill)
- **`hooks/post-write-relire.sh`** → `hooks/post-tool-write.sh` (renamed, updated to trigger `relire-critic` skill)
- **`settings.json`**: expanded to 7 hook events
- **`.claude-plugin/plugin.json`** + **`marketplace.json`**: bumped to 2.0.0
- **`PLUGIN.md`** + **`README.md`**: rewritten to document new architecture

### Removed

- **Old monolithic `skills/ciel/SKILL.md`** content (455 lines) — redistributed across 13 workflow skills + 6 research skills + reference.md
- **`hooks/pre-write-gate.{sh,ps1}`** — replaced by `pre-tool-write.{sh,ps1}`
- **`hooks/post-write-relire.{sh,ps1}`** — replaced by `post-tool-write.{sh,ps1}`
- **All `platforms/*` files** — now auto-regenerated; editing `skills/` is the only source of truth

### Migration (v1.x → v2.0.0)

- `/ciel <task>` behaves the same user-visible (depth classification + pipeline routing)
- `ciel-overlay.md` format unchanged — existing overlays work as-is
- Agent input formats preserved (`TASK:`, `TECHNOLOGIES:`, etc.) for compat with existing prompts
- Custom settings.json hooks require manual merge with new 7-event surface
- Platform rule files: users who edited `platforms/*` manually will see overwrites on next `build-platforms.sh`

### Metrics

- **Baseline (v1.x)**: 62.8% fix/revert ratio on 675 commits with monolithic SKILL.md
- **v2.0.0 target**: < 45% fix/revert (reference: SICA research, 17→53% improvement via self-edit + metrics)
- Eval datasets seeded (depth-classification, research-gate, flux-narration, relire-3-risques); initial scoreboard will land in v2.0.1

### Triggered by

Direct user request for a total refactor aligned with Anthropic's Skills-first paradigm. Philosophy of Ciel (the Primordial Sage from Tensura — reason before act) is preserved; only the delivery mechanism changes.

---

## v1.9.0 — 2026-04-05

**Changements** : CRITIQUER overhaul — parité output gates avec CRÉER

- **Entry**: instruction explicite "lire le diff/PR avant tout step"
- **APPRENDRE**: modèle de comportement attendu remplace "WebSearch anti-patterns" (langage CRÉER inadapté à la review); checklist de bypass signals explicite; 2 output gates ajoutés
- **COMPRENDRE**: 3 assumptions doivent être *vérifiées* (grep/blame/read), pas juste "surfacées" — distinction passive→active
- **QUESTIONNER**: 2 output gates ajoutés ("nothing considered?", "scope proportional?")
- **COMPARER**: STRIDE étendu — 6 questions explicites à cocher (Spoofing/Tampering/Repudiation/InfoDisclosure/DoS/Elevation); 3 output gates ajoutés
- **COHÉRENCE**: 3 checks concrets (grep pattern, layer boundaries, overlay thresholds) remplacent les bullets vagues
- **SIGNALER**: seuils de sévérité définis (BLOCKING = correctness/security/data loss; IMPORTANT = degraded behavior; MINOR = style; VALIDATED = confirmed correct); 3 output gates ajoutés
- **CAPITALISER**: actions concrètes (Guard ou overlay); 2 output gates ajoutés

**Problème adressé** : CRITIQUER avait 0 output gates sur 7 steps — exécutable sans produire aucune preuve. Un reviewer pouvait "compléter" CRITIQUER en 2 minutes et déclarer done.

**Métriques observées** :
- Critique de CRITIQUER (6 findings dont 3 BLOCKING) : 0 gates, STRIDE non exécuté, APPRENDRE = mauvais step, sévérités non définies, diff jamais explicitement lu, assumptions non vérifiées

**Déclenché par** : Audit capacités CRITIQUER de Ciel par CEO (2026-04-05)

---

## v1.8.0 — 2026-04-05

**Changements** (corrections structurelles — 0 nouvelles fonctionnalités, 6 fixes):
- SÉCURITÉ PASSE 4 supprimée du step 4 — elle instruisait une action post-FAIRE depuis un step pré-FAIRE (contradiction temporelle)
- Nouveau step **8b — SECURITY REGRESSION CHECK** entre FAIRE et RELIRE (Critical only) — même contenu, exécuté au bon moment
- **Before-state capture** ajouté à FAIRE (bug fix only) — capture AVANT avant d'écrire le code, satisfait l'obligation PROUVER AVANT/APRÈS
- PROUVER **Trivial allégé** : compile OK + push + no regression — CI gate et staging mandatory exclus pour les 1-line fixes
- RELIRE checklist TDD : `□ Tests written BEFORE` → `□ Tests could fail independently of implementation?` — vérifiable à n'importe quel moment
- RECHERCHE/CODEBASE boundary : `Imports/signatures` déplacé de RECHERCHE vers CODEBASE (API surface check) — clarification que RECHERCHE = externe, CODEBASE = interne
- META-CRITIQUER step 4 : grep `worktree-agent` spécifique Neiyomi → `git branch -r | wc -l` générique + note overlay

**Métriques observées** :
- Critique isolée (17 findings, 5 BLOCKING) a détecté : step 8b inaccessible depuis step 4, AVANT/APRÈS sans capture pre-FAIRE, PROUVER Trivial inutilisable, TDD check non-vérifiable à RELIRE, grep projet-spécifique dans un plugin universel

**Déclenché par** : Critique structurelle complète de SKILL.md v1.7.0 par agent critic isolé (2026-04-05)

---

## v1.7.0 — 2026-04-05

**Changements** :
- RECHERCHE output gate: version changelog check (breaking changes/deprecations for installed version)
- RECHERCHE output gate: framework philosophy now requires "HOW does this framework want me to solve this?" — not just API docs
- SÉCURITÉ PASSE 4: security regression check — grep diff for new inputs/trust boundaries/removed auth blocks
- PROUVER: CI gate — `gh run list --branch $BRANCH` mandatory before presenting report
- PROUVER: issue comment gate — staging PID + AVANT/APRÈS on linked issue BEFORE creating PR (not post-merge only)
- PROUVER: open PR hygiene — draft + CI green → convert to ready; PR > 2 days CI green → flag
- Guards: 6 new entries (security surface, CI ignored, draft PR left open, issue comment missing, version changelog missed)

**Déclenché par** : 3 retours CEO sur security rigor, PR/issue tracking, et profondeur de recherche (2026-04-05)

---

## v1.6.0 — 2026-04-05

**Changements** :
- ÉVALUER: recent-churn check — `git log --since=7days` on impacted files before proposing fix; prevents fix-of-fix chains
- FAIRE: volume gate — pause + verify each PR when 3+ created in same session
- RELIRE checklist: linter gate — explicit "0 new violations (Detekt/ESLint)" item
- PROUVER: PR body gate — `Closes #XXX` required, WIP title forbidden, PR closed check
- META-CRITIQUER: stale branch check

**Déclenché par** : Audit CRITIQUER des 25 issues + 8 PRs ouverts Neiyomi (2026-04-05)

---

## v1.3.0 — 2026-04-04

**Déclenché par** : Analyse des lacunes TDD — aucun gate ne forçait test-avant-implémentation, niveau de test implicite, failure path optionnel.

**Changements** : FLUX test level item, FAIRE test gate (RED first), RELIRE checklist TDD item, Guard TDD inversion.

---

## v1.2.0 — 2026-04-04

**Déclenché par** : Recherche 2026 (SWE-Bench Pro, SICA, MAST, SWE-EVO, AI Agent Memory 2026).

**Changements** : task decomposition gate, typed agent dispatch (MAST), assumption verification (SWE-EVO), 4-type memory model, SICA validator, self-cleaning cycle, self-update script.

---

## v1.1.0 — 2026-04-04

**Déclenché par** : Audit CRITIQUER dev-reasoning v18.3. 3 BLOCKING + 4 IMPORTANT.

**Changements** : RELIRE-A/B inline, removal gate, Guards "How it manifests" column, PROUVER attacker perspective, mini repo-map, SÉCURITÉ hygiene.

---

## v1.0.0 — 2026-04-04

**Déclenché par** : 62.8% fix/revert sur 675 commits Neiyomi avec dev-reasoning monolithique.

**Changements** : architecture 5-layer, agents OBLIGATOIRES Standard/Critical, RECHERCHE output gate (6 items), FLUX 3 items test-spécifiques.
