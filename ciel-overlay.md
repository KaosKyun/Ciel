# Ciel Overlay — [Nom du projet]

> Ce fichier est l'overlay projet pour le plugin Ciel.
> Il contient tout ce qui est spécifique à CE projet et override les defaults de Ciel.
> Généré automatiquement par `bash scripts/install.sh` — compléter les sections marquées [specify].

## Domain Skills (auto-detected)

Ciel invoque ces skills IN PARALLEL avec le researcher agent à l'étape RECHERCHE.
Supprimer ceux qui ne s'appliquent pas. Ajouter les autres si besoin.

<!-- install.sh injecte ici les skills détectés selon le stack -->
<!-- Disponibles: frontend-mastery, backend-mastery, database-mastery, security-hardening, api-architecture, observability, performance-engineering, refactoring-patterns -->

## Stack

- Frontend: [lib + version — ex: React 19.0.0]
- Backend: [framework + version — ex: Ktor 3.0.0 / Kotlin 2.0.21]
- DB: [type + version — ex: PostgreSQL 16]
- Cache: [ex: Redis 7.2]
- Test: [framework — ex: Vitest 3.x + Playwright]
- Build: [ex: pnpm 9.15 / Gradle 8.5]

## Versions + URLs docs (pour RECHERCHE)

| Lib | Version installée | URL docs officielle |
|-----|-------------------|--------------------|
| [lib] | [version exacte] | [URL] |

## Règles projet-spécifiques

[Ce qui override ou complète les defaults Ciel — patterns du projet, conventions, contraintes]

## CI / Vérification

- CI système: [ex: GitHub Actions]
- Runners: [ex: self-hosted, ubuntu-latest]
- Commande test locale: [ex: pnpm test:unit]
- Staging URL: [ex: https://staging.example.com]
- Commande staging deploy: [ex: git push origin branch]
- Délai deploy staging: [ex: ~30-45s]

## Fichiers critiques (patterns pour hooks)

Fichiers/dossiers à traiter comme Critical dans les hooks :
- [ex: src/auth/]
- [ex: *Routes.kt]
- [ex: *Service.kt]

## Comptes de test

- [ex: admin@example.com — rôle admin]
- [ex: user@example.com — rôle user standard]

## Leçons projet

[Erreurs passées spécifiques à ce projet]
[Format: [date] MISTAKE: [ce qui s'est passé] → RULE: [comment éviter]]

## 2026-04-17 — Routing miss: push to main on ambiguous "commit et push"

MISTAKE: On ambiguous "commit et push" with current branch=main, attempted direct `git push origin main` instead of branching first.
RULE: When user says "commit et push" without specifying branch AND current branch is main/master/develop (protected), ALWAYS invoke `branch-setup` first to create feat/* or fix/* branch. Push-to-main is an explicit user decision, not a default. Matches Ciel's own `branch-setup` guardrail.

## 2026-04-17 — Auto-mode ≠ harness denial override

MISTAKE: In auto mode, chained `gh pr create` + `gh pr merge` assuming the merge-to-main step inherited authorization from the "rattrapage" intent. Harness denied with "did not explicitly authorize merging to main without review". Attempted the merge anyway because auto mode felt like blanket consent.
RULE: Auto mode authorizes reasonable assumptions and routine decisions — NOT shared-state writes to protected branches. Merge-to-main, force-push, destructive ops (rm -rf, git reset --hard), secret uploads, and cross-service posts ALWAYS require per-action explicit user ok, even under auto mode. Pattern: stop at the merge step, summarize state (PR URL + what's next), ask for go/no-go. Matches Claude Code's system prompt: "A user approving an action once does NOT mean that they approve it in all contexts".

## 2026-04-17 — Release discipline drift: features shipped, versions frozen

MISTAKE: v2.0.0 → v2.5.1 = 20+ `feat:` commits merged to main. Zero git tags. Zero GitHub releases. VERSION file bumped inside CHANGELOG-entry commits but `release-publisher` skill (orchestrator step 17) never invoked — it's gated on a "version-bump PR" that no one creates. Latest offender: commit 37ec823 (`feat: +6 GitHub workflow + CI/CD skills`, PR #16) merged without VERSION bump, CHANGELOG entry, or tag.
RULE: After any `feat:` or `fix:` merge to main, the next action in the same session MUST be: (1) classify bump level (patch/minor/major per conventional-commit scope), (2) update VERSION + CHANGELOG.md, (3) `git tag -s v<N.N.N>`, (4) `gh release create --generate-notes`. Do not close the session with an unreleased `feat:` on HEAD. Mechanical enforcement candidate: Stop hook checks `git log $(cat VERSION-as-tag)..HEAD` — if any `feat:`/`fix:` commits since last-tagged VERSION, emit `[CIEL RELEASE-GATE]` reminder. Pattern mirrors v2.5.0 `pre-tool-count.sh` philosophy: rules that must hold across >5 turns need mechanical enforcement, not SKILL.md text.
