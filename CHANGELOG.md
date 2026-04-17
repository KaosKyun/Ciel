# Ciel — Changelog

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
