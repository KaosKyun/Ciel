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

- `.claude/hooks/*.sh` — Hooks Claude Code
- `.claude/settings.json` — Configuration hooks
- `.claude/agents/*.md` — Definitions agents
- `hooks/*` — Scripts d'automation
- `skills/` — Skills domaine (~50)
- `src/plugin/index.ts` — Plugin principal

---

## Commandes CI / Vérification

- **Build:** `npm run build` (packages/ciel/)
- **Test:** `npm test` (packages/ciel/)
- **Lint:** `shellcheck hooks/*.sh .claude/hooks/*.sh`

### Workflows GitHub Actions

| Workflow | Declencheur | Purpose |
|----------|-------------|---------|
| **CI** | push main + PR | Build, test, validate |
| **Publish NPM** | tag v* | Publie @neikyun/ciel sur npm |

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

- **SHA-pinned actions** — GitHub Actions pinées par SHA (SLSA L3)
- **Permissions minimales** — `contents: read` par défaut
- **Hooks shell validés** — `shellcheck` obligatoire
- **Tests avant implémentation** — Test-first RED

---

## Structure du projet

```
Ciel/
├── .github/workflows/     # CI/CD
├── .claude/               # Configuration Claude Code
│   ├── agents/            # Subagents (ciel-researcher, explorer, critic, improver)
│   ├── hooks/             # Hooks (user-prompt-submit, dispatch gate, etc.)
│   └── skills/            # Skills domaine (~50)
├── hooks/                 # Source hooks
├── packages/ciel/         # Package npm @neikyun/ciel
│   ├── src/               # Source TypeScript
│   ├── assets/            # Hooks/skills pour distribution
│   └── test/              # Tests
├── CLAUDE.md              # Instructions projet
├── VERSION                # Version courante
└── ciel-overlay.md        # Ce fichier
```

---

## Version courante

Voir fichier `VERSION` à la racine.
