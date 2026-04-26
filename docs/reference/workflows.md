# Référence des workflows CI/CD

> **Les 6 workflows GitHub Actions — déclencheurs, jobs, sorties.**

---

## 1. CI (`ci.yml`)

**Fichier** : `.github/workflows/ci.yml` (238 lignes)

**Déclencheur** : push sur `main` + pull_request vers `main`

**Permissions** : `contents: read`

**Concurrency** : `cancel-in-progress: true` (pour PR)

### Jobs

#### `lint-hooks`

| Champ | Valeur |
|-------|--------|
| **runs-on** | ubuntu-latest |
| **timeout-minutes** | 5 |
| **Étapes** | Checkout → Install ShellCheck → Validate shell scripts |

**Logique** : shellcheck sur tous les fichiers `hooks/*.sh`. Échoue seulement sur les erreurs (exit code ≥ 2), les warnings sont acceptés (exit code 1).

#### `test-ciel`

| Champ | Valeur |
|-------|--------|
| **runs-on** | ubuntu-latest |
| **timeout-minutes** | 5 |
| **Étapes** | Checkout → Setup Node.js 20 → `npm ci` → `npx tsx test-ciel.ts` |

#### `validate-config`

| Champ | Valeur |
|-------|--------|
| **runs-on** | ubuntu-latest |
| **timeout-minutes** | 3 |
| **Étapes** | Checkout → jq validation opencode.json → agent files existence check |

**Vérifie** : `opencode.json` est valide JSON + 5 agents `.opencode/agents/ciel-*.md` existent.

#### `validate-byte-limits`

| Champ | Valeur |
|-------|--------|
| **runs-on** | ubuntu-latest |
| **timeout-minutes** | 10 |
| **Étapes** | Checkout → Setup Node.js → `npm ci` → Build platforms → Validate byte limits |

**Vérifie les limites** :
- Cursor : ≤6 KB (`platforms/cursor/.cursor/rules/ciel.mdc`)
- Windsurf : ≤6 KB per file (`platforms/windsurf/.windsurf/rules/*.md`)
- Codex : ≤32 KB (`platforms/codex/AGENTS.md`)
- OpenCode : ≤65 KB (`platforms/opencode/.opencode/plugins/ciel.ts`)
- Kilocode : ≤6 KB (`platforms/kilocode/.kilocode/rules/ciel.md`)

#### `build-check`

| Champ | Valeur |
|-------|--------|
| **runs-on** | ubuntu-latest |
| **timeout-minutes** | 10 |
| **Étapes** | Checkout → `./scripts/build-platforms.sh --dry-run` |

---

## 2. Test Hooks (`test-hooks.yml`)

**Déclencheur** : push sur `hooks/**` + pull_request

**Jobs** : `test-hooks` (individuel), `test-integration` (simulation session), `test-stop-hook-cases` (8 cas)

---

## 3. Platform Validation (`platform-validation.yml`)

**Déclencheur** : push sur `platforms/**` + pull_request

**Jobs parallèles** (7) : chaque plateforme est validée individuellement.

| Job | Vérification | Commande |
|-----|-------------|----------|
| `validate-cursor` | Taille ≤6 KB | `wc -c < cursor/ciel.mdc` |
| `validate-windsurf` | Taille ≤6 KB per file | `for f in windsurf/rules/*.md; do wc -c < $f; done` |
| `validate-codex` | Taille ≤32 KB | `wc -c < codex/AGENTS.md` |
| `validate-opencode` | Taille ≤65 KB + TS compile | `wc -c + tsc --noEmit` |
| `validate-kilocode` | Taille ≤6 KB | `wc -c < kilocode/ciel.md` |
| `validate-ollama` | Syntaxe Modelfile | `grep -q "^FROM\|^SYSTEM" Modelfile` |
| `validate-lmstudio` | JSON + markdown | `jq . preset.json && test -f system-prompt.md` |

---

## 4. Skill Integrity (`skill-integrity.yml`)

**Déclencheur** : push sur `skills/**` + pull_request

**Jobs** :

| Job | Vérification |
|-----|-------------|
| `validate-skill-yaml` | Frontmatter YAML présent (`head -5 SKILL.md \| grep -q "^---$"`) |
| `validate-skill-size` | ≤500 lignes (`wc -l < SKILL.md`) |
| `validate-skill-urls` | URLs bien formées |
| `validate-skill-examples` | ≥50% des skills ont des exemples |
| `validate-skill-references` | `reference.md` présent |

---

## 5. Deploy Staging (`deploy-staging.yml`)

**Déclencheur** : push sur `main`

**Jobs** :
- `deploy` — Build + upload artifact
- `health-check` — Validation structure + syntaxe

---

## 6. Release (`release.yml`)

**Déclencheur** : tag `v*`

**Permissions** : `contents: write` (nécessaire pour release)

**Jobs** :
- `build` — Build matrix multi-platforms
- `publish` — GitHub Release + SBOM CycloneDX
- `notify` — Notification (simulée)

---

## SLSA Level 3 Compliance

| Critère | Statut | Preuve |
|---------|--------|--------|
| SHA-pinned actions | ✅ | `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683` |
| Permissions minimales | ✅ | `contents: read` par défaut |
| Concurrency cancel | ✅ | `cancel-in-progress: true` sur PR |
| Timeouts | ✅ | Max 15 min par job |
| SBOM | ✅ | CycloneDX à chaque release |

---

## Voir aussi

- [Architecture CI/CD](../explanation/ci-cd.md)
- [Distribution multi-plateformes](../explanation/platforms.md)
- [Guide CI/CD complet](../../CI-CD-GUIDE.md)
