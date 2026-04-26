# Architecture CI/CD

> **Ciel utilise 6 workflows GitHub Actions pour valider, tester et déployer le projet sur 7 plateformes. Tous les workflows respectent SLSA Level 3.**

---

## Principes

Tous les workflows suivent ces règles strictes :

| Règle | Implémentation | SLSA |
|-------|---------------|------|
| **SHA-pinned actions** | `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683` | L3 |
| **Permissions minimales** | `contents: read` par défaut | L3 |
| **Concurrency avec cancel** | Annule jobs en cours sur PR | L3 |
| **Timeout** | Max 15 minutes par job | L3 |
| **SBOM** | Généré à chaque release | L3 |

---

## Les 6 workflows

### 1. CI (`ci.yml`)

**Déclencheur** : push sur `main` + PR

**5 jobs parallèles** :

| Job | Durée max | Description |
|-----|-----------|-------------|
| `lint-hooks` | 5 min | ShellCheck sur les 8 hooks |
| `test-ciel` | 5 min | Tests Node.js (plugin TypeScript) |
| `validate-config` | 3 min | Validation JSON + agents existants |
| `validate-byte-limits` | 10 min | Build platforms + validation limites |
| `build-check` | 10 min | Dry run build script |

**Jalons critiques** :
- `lint-hooks` échoue seulement sur les erreurs ShellCheck (les warnings sont acceptés)
- `validate-byte-limits` build TOUTES les platforms et vérifie chaque limite

### 2. Test Hooks (`test-hooks.yml`)

**Déclencheur** : push sur `hooks/**` + PR

**3 jobs** :

| Job | Description |
|-----|-------------|
| `test-hooks` | Test individuel de chaque hook (8 tests) |
| `test-integration` | Simulation session complète |
| `test-stop-hook-cases` | 8 cas de test pour `stop.sh` |

### 3. Platform Validation (`platform-validation.yml`)

**Déclencheur** : push sur `platforms/**` + PR

**7 jobs parallèles** — un par plateforme :

| Job | Vérification | Limite |
|-----|-------------|--------|
| `validate-cursor` | Taille fichier | ≤6 KB |
| `validate-windsurf` | Taille rules | ≤6 KB per file, ≤12 KB total |
| `validate-codex` | Taille AGENTS.md | ≤32 KB |
| `validate-opencode` | Taille plugin TS | ≤65 KB |
| `validate-kilocode` | Taille rules | ≤6 KB |
| `validate-ollama` | Syntaxe Modelfile | N/A |
| `validate-lmstudio` | JSON valide + markdown | N/A |

### 4. Skill Integrity (`skill-integrity.yml`)

**Déclencheur** : push sur `skills/**` + PR

**5 jobs** :

| Job | Vérification |
|-----|-------------|
| `validate-skill-yaml` | Frontmatter YAML présent |
| `validate-skill-size` | ≤500 lignes par skill |
| `validate-skill-urls` | Format URLs valide |
| `validate-skill-examples` | ≥50% des skills ont des exemples |
| `validate-skill-references` | `reference.md` présents |

### 5. Deploy Staging (`deploy-staging.yml`)

**Déclencheur** : push sur `main`

**2 jobs** :

| Job | Description |
|-----|-------------|
| `deploy` | Build + upload artifact |
| `health-check` | Validation structure + syntaxe |

### 6. Release (`release.yml`)

**Déclencheur** : tag `v*`

**3 jobs** :

| Job | Description |
|-----|-------------|
| `build` | Build matrix multi-platforms |
| `publish` | GitHub Release + SBOM CycloneDX |
| `notify` | Notification (simulée) |

---

## Byte Limits

Chaque plateforme a des limites de taille de fichier validées en CI :

| Platform | Fichier | Limite |
|----------|---------|--------|
| Cursor | `.cursor/rules/ciel.mdc` | ≤6 KB |
| Windsurf | `.windsurf/rules/*.md` | ≤6 KB per file |
| Windsurf (total) | Toutes les rules | ≤12 KB |
| Codex | `AGENTS.md` | ≤32 KB |
| OpenCode | `.opencode/plugins/ciel.ts` | ≤65 KB |
| Kilocode | `.kilocode/rules/ciel.md` | ≤6 KB |

En cas d'échec, le job `validate-byte-limits` affiche :
```
✗ Cursor: 7234 bytes exceeds 6144 limit
```

---

## Matrice de décision

| Changement | Workflows nécessaires |
|------------|----------------------|
| Hook modifié | `ci.yml` + `test-hooks.yml` |
| Skill modifié | `skill-integrity.yml` |
| Platform modifiée | `platform-validation.yml` |
| Tag release | `release.yml` |
| Push main | `ci.yml` + `deploy-staging.yml` |

---

## SLSA Level 3

Tous les workflows Ciel respectent SLSA Level 3 :

### SHA-pinned actions

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
```

Chaque action est pinée par SHA complet avec le tag version en commentaire.

### Permissions minimales

```yaml
permissions:
  contents: read     # read-only par défaut
```

Le workflow `release.yml` obtient `contents: write` uniquement pour la release.

### Concurrency avec cancel

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

### Timeouts

Chaque job a un `timeout-minutes` défini (3-15 min selon le job).

### SBOM

Chaque release inclut un SBOM au format CycloneDX.

---

## Commandes locales

### Avant push

```bash
# 1. Lint hooks
shellcheck hooks/*.sh

# 2. Build toutes platforms
./scripts/build-platforms.sh --target=all

# 3. Test hooks
./scripts/test-stop-hook.sh

# 4. Test plugin TS
cd .opencode && npx tsc --noEmit plugins/ciel.ts

# 5. Valider byte limits
for platform in cursor windsurf codex opencode kilocode ollama lmstudio; do
  echo "=== $platform ==="
  du -sh "platforms/$platform/"
done
```

### Test spécifique

```bash
# Test CI complète (simulée)
./scripts/build-platforms.sh --check

# Test installation
./scripts/install.sh --check-update

# Test hook spécifique
hooks/stop.sh --test
```

---

## Voir aussi

- [Guide CI/CD](../guides/how-to-debug.md) — Dépannage CI
- [Guide complet CI/CD](../../CI-CD-GUIDE.md) — Documentation complète
- [Distribution multi-plateformes](platforms.md)
