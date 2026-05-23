---
name: release-management
description: "Release Management — semantic versioning, CHANGELOG, signed tags, release notes. A loader quand on prepare une release."
---

# Release Management

## Checklist
- [ ] La version suit le semantic versioning (MAJOR.MINOR.PATCH)
- [ ] Le CHANGELOG est a jour (Keep a Changelog format)
- [ ] Les tags Git sont signes (git tag -s)
- [ ] La release note est comprehensible par les consommateurs du projet
- [ ] Les breaking changes sont documentes explicitement
- [ ] L'artefact de release est immutable (version pin, checksum)

## Anti-patterns
### Pas de version
**Ce qu'on voit :** `"version": "1.0.0"` dans package.json depuis 2 ans. 47 commits depuis la derniere release.
**Pourquoi c'est dangereux :** impossible de savoir quelle version est en production. Les consommateurs ne peuvent pas piner une version stable.
**Faire plutot :** version bump a chaque release. Semver strict. `git tag` correspond a la version.

### CHANGELOG vide ou manuel
**Ce qu'on voit :** CHANGELOG.md avec "Initial release" depuis 6 mois.
**Pourquoi c'est dangereux :** personne ne sait ce qui a change entre les versions. Les consommateurs hesitent a upgrade.
**Faire plutot :** CHANGELOG genere depuis les conventional commits. Chaque PR ajoute automatiquement une entree. Categories : Added, Changed, Deprecated, Removed, Fixed, Security.

### Breaking change non documente
**Ce qu'on voit :** passage de MAJOR.MINOR.PATCH 1.2.3 a 1.3.0 avec un breaking change (MAJOR aurait du etre incremente).
**Pourquoi c'est dangereux :** les consommateurs font `npm update` et leur app casse. Ils ne savent pas ce qui a change.
**Faire plutot :** tout breaking change = MAJOR bump. Chaque breaking change est documente dans le CHANGELOG avec migration guide.

## Patterns
### Conventional Commits
**Quand :** tout projet.
**Comment :** `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `perf:`, `BREAKING CHANGE:`. Le CHANGELOG et le version bump sont automatises depuis les messages de commit.

### Release avec artefacts signes
**Quand :** bibliotheque open source, package critique.
**Comment :** `git tag -s v1.2.3` (signe avec GPG). `npm publish` ou `gh release create`. Checksum SHA256. SBOM genere.
