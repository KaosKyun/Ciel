# Ciel Overlay — Ciel Plugin

> Ce fichier est l'overlay projet pour le plugin Ciel.
> Il contient tout ce qui est spécifique à CE projet et override les defaults de Ciel.

---

## Stack exacte

- **Frontend:** N/A (plugin backend)
- **Backend:** TypeScript 5.x (plugin OpenCode)
- **Langage:** TypeScript 5.5, Bash 5.x, PowerShell 7.x
- **DB:** N/A
- **Cache:** in-memory (fichiers temporaires /tmp)
- **Test:** Node.js test runner + shell scripts
- **Build:** npm 10, bash scripts

---

## URLs de documentation

| Lib | Version installée | URL docs officielle |
|-----|-------------------|--------------------|
| TypeScript | 5.5.x | https://www.typescriptlang.org/docs/ |
| Node.js | 20.x | https://nodejs.org/docs/latest/ |
| OpenCode | latest | https://opencode.ai/docs/ |
| Claude Code | latest | https://claude.ai/docs/ |

---

## Fichiers critiques (patterns pour hooks)

Fichiers/dossiers à traiter comme **Critical** dans les hooks :

- `.opencode/plugins/ciel.ts` — Plugin principal OpenCode (v5)
- `.claude/settings.json` — Hooks Claude Code
- `.claude/hooks/*.sh` — Scripts d'automation Claude Code (4 hooks)
- `.claude/agents/*.md` — Définitions agents Claude Code
- `hooks/*` — Scripts d'automation (8 hooks)
- `skills/ciel/` — Orchestrator principal
- `skills/workflow/` — Pipeline CRÉER/CRITIQUER
- `skills/security/` — Security hardening
- `skills/meta/` — Self-improvement subsystem
- `agents/ciel-*.md` — Définitions des agents

---

## Commandes CI / Vérification

- **CI système:** GitHub Actions
- **Runners:** ubuntu-latest
- **Build local:** `cd .opencode && npm install`
- **Test local:** `cd .opencode && npx tsx test-ciel.ts`
- **Lint:** `shellcheck hooks/*.sh .claude/hooks/*.sh`
- **Type check dans le plugin:** activer OPENCODE_EXPERIMENTAL_LSP_TOOL=true pour le navigateur LSP
- **Staging URL:** https://staging.ciel-plugin.dev (simulé)
- **Deploy staging:** `git push origin main`
- **Délai deploy:** ~1-2 minutes

### Workflows GitHub Actions

| Workflow | Fichier | Déclencheur | Purpose |
|----------|---------|-------------|---------|
| **CI** | `.github/workflows/ci.yml` | push main + PR | Lint hooks, test Node.js, validate config, byte limits, TypeScript |
| **Test Hooks** | `.github/workflows/test-hooks.yml` | push hooks/ + PR | Test individuel + integration des hooks (8 cas) |
| **Platform Validation** | `.github/workflows/platform-validation.yml` | push platforms/** | Validation 7 platforms (Cursor, Windsurf, Codex, OpenCode, Kilocode, Ollama, LM Studio) |
| **Skill Integrity** | `.github/workflows/skill-integrity.yml` | push skills/** | Validation YAML frontmatter, taille ≤500 lignes, URLs |
| **Matrix Build** | `.github/workflows/matrix-build.yml` | tag v* | Build parallèle multi-platforms pour release |
| **Deploy Staging** | `.github/workflows/deploy-staging.yml` | push main | Déploiement staging automatique + health check |
| **Release** | `.github/workflows/release.yml` | tag v* | Release GitHub + SBOM + artifacts multi-platforms |

---

## Comptes de test

N/A — Plugin de développement, pas de comptes utilisateurs

---

## Secrets (sensitive: true)

> Les sections marquées `sensitive: true` sont automatiquement redactées par le plugin avant injection dans le prompt système.

Aucun secret requis pour la CI actuelle.

---

## Leçons projet

> Format: `[date] MISTAKE: [ce qui s'est passé] → RULE: [comment éviter]`

- `[2026-04] MISTAKE: hooks non testés avant merge → RULE: Toujours exécuter test-hooks.yml en local avant push`
- `[2026-04] MISTAKE:忘记更新 VERSION 文件 → RULE: Mettre à jour VERSION avant de créer un tag release`
- `[2026-04] MISTAKE: Ciel v4 pipeline trop procédural, sans ASK window → RULE: Ciel v5 a 16 étapes avec ASK (question tool) + DIVERGE + ADR + MEMOIRE + META renforcé`
- `[2026-04] MISTAKE: exploration sans intention → RULE: Ciel v5 explorer recoit INTENTION (pas la solution), utilise LSP + git history pour scent-following`
- `[2026-04] MISTAKE: feedback humain obei aveuglement → RULE: Ciel critic v5 mode FEEDBACK analyse et categorise (ACCEPT/CHALLENGE/INVESTIGATE/DEFER)`
- `[2026-04] MISTAKE: pas de carte persistante du projet → RULE: .ciel/map.json charge a chaque session, mis a jour apres chaque exploration`
- `[2026-04] MISTAKE: Claude Code et OpenCode traites differemment → RULE: philosophie Ciel invariante, implementation specifique a chaque harness`

---

## Règles projet-spécifiques

> Ce qui override ou complète les defaults Ciel — patterns du projet, conventions, contraintes

- **SHA-pinned actions uniquement** — Toutes les GitHub Actions doivent être pinées par SHA (SLSA L3)
- **Permissions minimales** — `contents: read` par défaut, écrire uniquement si nécessaire
- **Timeout sur chaque job** — Maximum 15 minutes par job
- **Concurrency avec cancel** — Annuler les jobs en cours sur PR
- **Hooks shell validés** — Tous les scripts `.sh` doivent passer `shellcheck`
- **Documentation à jour** — CHANGELOG.md doit être mis à jour avant chaque release
- **Tests avant implémentation** — Suivre le workflow FAIRE (test-first RED)
- **ASK avant d'assumer** — Utiliser le `question` tool d'OpenCode pour clarifier les ambiguites (ASK window)
- **LSP tool disponible** — `OPENCODE_EXPERIMENTAL_LSP_TOOL=true` active le LSP pour explorer avec goToDefinition
- **SPIKE mode** — `.ciel/exploration.active` pour les prototypes, gates assouplies
- **Byte limits strictes** — Chaque platform a ses limites (6KB-65KB), validation CI bloquante
- **7 platforms supportées** — Cursor, Windsurf, Codex, OpenCode, Kilocode, Ollama, LM Studio

---

## Structure du projet

```
Ciel/
├── .github/workflows/     # CI/CD (7 workflows)
│   ├── ci.yml             # CI principale (6 jobs + validation Claude Code)
│   ├── test-hooks.yml     # Test hooks (3 jobs)
│   ├── platform-validation.yml # Validation 7 platforms
│   ├── skill-integrity.yml # Validation skills
│   ├── matrix-build.yml   # Build parallèle release
│   ├── deploy-staging.yml # Déploiement staging
│   └── release.yml        # Release GitHub
├── .opencode/             # Configuration OpenCode (v5)
│   ├── agents/            # 5 agents (ciel, ciel-researcher, ciel-explorer, ciel-critic, ciel-improver)
│   ├── commands/          # 8 commandes slash
│   └── plugins/           # ciel.ts (plugin principal v5)
├── .claude/               # Configuration Claude Code (v5)
│   ├── agents/            # 4 subagents (ciel-researcher, ciel-explorer, ciel-critic, ciel-improver)
│   ├── hooks/             # 4 hooks (check-test-first, block-destructive, track-file, meta-critiquer)
│   ├── settings.json      # Hooks configuration
│   └── rules/             # Path-scoped rules (à venir)
├── .ciel/                 # État persistant Ciel
│   ├── map.json           # Carte du projet
│   ├── memory.json        # Mémoire cross-session
│   ├── parking.md         # Découvertes fortuites
│   └── learnings.md       # Leçons apprises
├── CLAUDE.md              # Instructions Claude Code (importe AGENTS.md)
├── AGENTS.md              # Instructions OpenCode (v5) + philosophie
├── ciel-overlay.md        # Overlay projet
├── agents/                # Définitions agents (source)
├── commands/              # Commandes slash (source)
├── hooks/                 # 8 hooks bash/powershell
├── skills/                # ~50 compétences Ciel
├── scripts/               # Installation, build, tests
│   ├── install.sh         # Installateur universel
│   ├── build-platforms.sh # Build multi-platforms
│   └── test-stop-hook.sh  # Test hooks (8 cas)
├── evals/                 # Self-improvement harness
└── platforms/             # Builds multi-platforms (7 platforms)
    ├── cursor/
    ├── windsurf/
    ├── codex/
    ├── opencode/
    ├── kilocode/
    ├── ollama/
    └── lmstudio/
```

---

## Version courante

Voir fichier `VERSION` à la racine.

## Leçons projet

[2026-04-26] MISTAKE: les fichiers `.opencode/` (plugins/agents/commands) étaient supprimés du working tree mais toujours trackés dans git → RULE: toujours vérifier `git status` pour détecter les fichiers trackés supprimés accidentellement du working tree

[2026-04-26] MISTAKE: le script `install.sh` copiait les fichiers OpenCode depuis `$SRC_DIR/.opencode/` mais les templates de distribution sont dans `$SRC_DIR/platforms/opencode/.opencode/` → RULE: l'install script doit copier depuis `platforms/opencode/.opencode/` (templates built), pas depuis `.opencode/` (propre config du projet Ciel)

[2026-04-26] MISTAKE: le script `install.sh` générait un `opencode.json` minimal sans définitions d'agents → RULE: le `opencode.json` généré par install.sh doit inclure les 5 agents (ciel + 4 subagents) pour que le pipeline marche out-of-the-box
