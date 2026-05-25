---
description: ---
subtask: false
---

---
description: Release a new Ciel version — bump versions, tag, publish to GitHub and npm.
---

# /ciel-release — Release a new Ciel version

Publie une nouvelle version de Ciel : bump version, commit, tag, GitHub Release, npm publish.

Usage: `/ciel-release <patch|minor|major>`

## Steps

1. **Bump versions** — les DEUX fichiers :
   - `VERSION` (racine)
   - `packages/ciel/package.json` (`version` field)

2. **Commit + tag :**
   ```bash
   git add VERSION packages/ciel/package.json
   git commit -m "chore: bump to v<version>"
   git tag -a v<version> -m "v<version>"
   git push && git push origin v<version>
   ```

3. **Release GitHub :**
   ```bash
   gh release create v<version> --title "v<version>" --notes "<release notes>"
   ```

4. **Vérifier le publish npm :**
   ```bash
   gh run list --workflow publish-npm.yml --limit 3
   npm view @neikyun/ciel version
   ```

## Règles

- **Toujours** bump `packages/ciel/package.json` ET `VERSION` — jamais un seul. Le workflow npm lit le package.json, pas le VERSION racine.
- Si le tag existe déjà, le supprimer avant de re-tagger :
  ```bash
  gh release delete v<version> --yes
  git push origin --delete v<version>
  git tag -d v<version>
  ```
- Vérifier `git status` avant de commencer — pas de fichiers sales.
- Le CHANGELOG.md devrait être à jour avant la release (mais n'est pas bloquant).

## Dépannage

| Symptome | Fix |
|----------|-----|
| `npm error You cannot publish over the previously published versions` | Le package.json n'a pas été bumpé — vérifier `packages/ciel/package.json` |
| Tag push rejeté | Le tag existe déjà en remote — le supprimer puis re-pousser |
| Workflow GitHub fail | `gh run view <id> --log-failed` pour voir l'erreur |
