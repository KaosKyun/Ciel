# CI/CD Guide — Ciel

> Documentation complète de la CI/CD multi-platforms pour Ciel v3.3.0+

---

## Vue d'ensemble

Ciel supporte **7 platforms** et utilise GitHub Actions pour une CI/CD complète :

| Platform | Artifact | Byte limit |
|----------|----------|------------|
| Cursor | `.cursor/rules/ciel.mdc` | ≤6KB |
| Windsurf | `.windsurf/rules/*.md` | ≤6KB rules + ≤64KB skills |
| Codex | `AGENTS.md` | ≤32KB |
| OpenCode | `.opencode/plugins/ciel.ts` | ≤65KB |
| Kilocode | `.kilocode/rules/ciel.md` | ≤6KB |
| Ollama | `Modelfile` | N/A |
| LM Studio | `ciel.preset.json` | N/A |

---

## Workflows GitHub Actions

### 1. CI (`ci.yml`)

**Déclencheur:** push sur `main` + PR

**Jobs:**
- `lint-hooks` — ShellCheck sur tous les hooks `.sh`
- `test-ciel` — Tests Node.js (`test-ciel.ts`)
- `validate-config` — Validation JSON (`opencode.json`, agents)
- `validate-typescript` — Compilation TS du plugin (`tsc --noEmit`)
- `validate-byte-limits` — Build + validation des limites par platform
- `build-check` — Dry run du build

**Durée estimée:** 5-8 minutes

### 2. Test Hooks (`test-hooks.yml`)

**Déclencheur:** push sur `hooks/**` + PR

**Jobs:**
- `test-hooks` — Test individuel de chaque hook (9 hooks)
- `test-integration` — Simulation session complète
- `test-stop-hook-cases` — 8 cas de test pour `stop.sh`

**Durée estimée:** 10-12 minutes

### 3. Platform Validation (`platform-validation.yml`)

**Déclencheur:** push sur `platforms/**` + PR

**Jobs:** (7 jobs parallèles)
- `validate-cursor` — ≤6KB
- `validate-windsurf` — ≤6KB rules + ≤12KB total
- `validate-codex` — ≤32KB + hooks.json valide
- `validate-opencode` — ≤65KB + TS compile
- `validate-kilocode` — ≤6KB
- `validate-ollama` — Modelfile syntax (FROM + SYSTEM)
- `validate-lmstudio` — preset.json valide + system-prompt.md

**Durée estimée:** 5-7 minutes (parallèle)

### 4. Skill Integrity (`skill-integrity.yml`)

**Déclencheur:** push sur `skills/**` + PR

**Jobs:**
- `validate-skill-yaml` — Frontmatter YAML présent
- `validate-skill-size` — ≤500 lignes par skill
- `validate-skill-urls` — Format URLs valide
- `validate-skill-examples` — ≥50% des skills ont des exemples
- `validate-skill-references` — reference.md présents

**Durée estimée:** 8-10 minutes

### 5. Matrix Build (`matrix-build.yml`)

**Déclencheur:** tag `v*`

**Jobs:**
- `get-version` — Récupère version depuis tag
- `build-matrix` — Build parallèle pour 7 platforms
- `verify-builds` — Vérifie tous les artifacts

**Durée estimée:** 10-15 minutes

### 6. Deploy Staging (`deploy-staging.yml`)

**Déclencheur:** push sur `main`

**Jobs:**
- `deploy` — Build + upload artifact staging
- `health-check` — Validation structure + syntaxe

**Durée estimée:** 5-7 minutes

### 7. Release (`release.yml`)

**Déclencheur:** tag `v*`

**Jobs:**
- `build` — Utilise `matrix-build.yml`
- `publish` — GitHub Release + SBOM
- `notify` — Notification (simulée)

**Durée estimée:** 15-20 minutes (inclut matrix-build)

---

## Commandes locales

### Avant push

```bash
cd /Users/neikyun/Documents/Projet/Ciel

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

# Test un hook spécifique
hooks/stop.sh --test
```

---

## Secrets requis

**Aucun secret requis** — Tous les workflows fonctionnent avec les permissions par défaut GitHub Actions.

Pour un déploiement réel (futur):
- `DEPLOY_TOKEN` — Token de déploiement staging
- `DISCORD_WEBHOOK` — Notification release
- `TWITTER_API_KEY` — Post automatique Twitter

---

## SLSA Level 3 Compliance

Tous les workflows respectent SLSA Level 3 :

✅ **SHA-pinned actions** — Toutes les actions sont pinées par SHA
```yaml
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
```

✅ **Permissions minimales** — `contents: read` par défaut
```yaml
permissions:
  contents: read
```

✅ **Concurrency avec cancel** — Annule jobs stalés sur PR
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

✅ **Timeout sur chaque job** — Maximum 15 minutes
```yaml
timeout-minutes: 15
```

✅ **SBOM généré** — Chaque release inclut un SBOM CycloneDX

---

## Byte Limits

Chaque platform a des limites strictes validées en CI :

| Platform | Limite | Fichier | Validation |
|----------|--------|---------|------------|
| Cursor | 6KB | `.cursor/rules/ciel.mdc` | `wc -c ≤ 6144` |
| Windsurf | 6KB | `.windsurf/rules/*.md` | `wc -c ≤ 6144` par fichier |
| Windsurf | 12KB | Total rules | `sum ≤ 12288` |
| Codex | 32KB | `AGENTS.md` | `wc -c ≤ 32768` |
| OpenCode | 65KB | `plugins/ciel.ts` | `wc -c ≤ 65536` |
| Kilocode | 6KB | `.kilocode/rules/ciel.md` | `wc -c ≤ 6144` |

**En cas d'échec:**
```
✗ Cursor: 7234 bytes exceeds 6144 limit
```

**Solution:** Réduire la taille du fichier ou optimiser le contenu.

---

## Debugging un échec CI

### 1. Lint hooks échoue

```bash
# Identifier le hook problématique
shellcheck hooks/failing-hook.sh

# Corriger et re-test
shellcheck -e SC1091 hooks/failing-hook.sh
```

### 2. Byte limit échoue

```bash
# Vérifier la taille actuelle
wc -c platforms/cursor/.cursor/rules/ciel.mdc

# Optimiser le fichier
# - Réduire commentaires
# - Utiliser abréviations
# - Déplacer contenu vers skills/
```

### 3. TypeScript échoue

```bash
# Compiler localement
cd .opencode
npx tsc --noEmit plugins/ciel.ts

# Corriger les erreurs
# - Types manquants
# - Imports incorrects
```

### 4. Platform validation échoue

```bash
# Rebuild la platform
./scripts/build-platforms.sh --target=cursor

# Vérifier l'artifact
ls -la platforms/cursor/
```

---

## Ajouter un nouveau test

### Exemple: Ajouter un test de hook

1. Créer le fichier de test dans `scripts/`
2. Ajouter un job dans `test-hooks.yml`
3. Tester localement avant push

```yaml
# .github/workflows/test-hooks.yml
test-new-hook:
  name: Test New Hook
  runs-on: ubuntu-latest
  timeout-minutes: 5
  steps:
    - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
    - name: Test new-hook.sh
      run: |
        chmod +x hooks/new-hook.sh
        hooks/new-hook.sh --test
```

---

## Matrice de décision

| Changement | Workflows à exécuter |
|------------|---------------------|
| Modification hook | `ci.yml` + `test-hooks.yml` |
| Modification skill | `skill-integrity.yml` |
| Modification platform | `platform-validation.yml` |
| Tag release | `release.yml` + `matrix-build.yml` |
| Push main | `ci.yml` + `deploy-staging.yml` |

---

## Historique des versions

- **v3.3.0** (2026-04) — CI/CD complète multi-platforms (7 workflows)
- **v3.2.0** (2026-03) — 4 workflows de base
- **v3.1.0** (2026-02) — CI initiale (ci.yml uniquement)

---

## Références

### Actions GitHub tierces

| Action | SHA | Version | Purpose | URL |
|--------|-----|---------|---------|-----|
| `softprops/action-gh-release` | `9d7c94cfd0a1f3ed45544c887983e9fa900f0564` | v2.0.4 | Création releases GitHub | https://github.com/softprops/action-gh-release |

**Note sur les permissions :** `softprops/action-gh-release` nécessite `contents: write` pour créer la release et uploader les assets. Les permissions `attestations: write` et `id-token: write` sont utilisées pour les attestations SLSA Level 3 (optionnel, peut être désactivé si non requis).

### Outils recommandés

| Outil | Purpose | URL |
|-------|---------|-----|
| `lychee` | Link checker pour validation URLs | https://github.com/lycheeverse/lychee |
| `shellcheck` | Linter pour scripts shell | https://www.shellcheck.net/ |
| `pin-github-action` | Pinner les actions par SHA | https://github.com/mheap/pin-github-action |

### Standards

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [SLSA Framework](https://slsa.dev/spec/v1.0/levels)
- [CycloneDX SBOM](https://cyclonedx.org/)
- [Sigstore Cosign](https://docs.sigstore.dev/cosign/)
