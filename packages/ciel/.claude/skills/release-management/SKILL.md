---
name: release-management
description: "Release Management — releases as contracts, semver as communication, pre-release channels (alpha/beta/rc), signed provenance, changelog as consumer signal. À charger quand on prépare une release."
---

# Release Management

**Principe premier :** Une release est un contrat avec les consommateurs. Le numéro de version n'est pas un compteur — c'est un signal. MAJOR veut dire "tu dois migrer, voici comment". MINOR veut dire "nouveau, sans risque, upgrade". PATCH veut dire "sécurité ou bug, fais-le maintenant". Si tes numéros de version ne communiquent pas ça, ils ne servent à rien. Le changelog est la partie visible de ce contrat — sans lui, les consommateurs ne savent pas ce qui a changé et n'upgraderont pas.

## Checklist
- [ ] La version suit semver strict : MAJOR (breaking API), MINOR (nouveau compatible), PATCH (bug/security)
- [ ] Chaque breaking change a un guide de migration (pas juste "changed X" — quoi changer, ligne par ligne)
- [ ] Des pre-release channels existent : alpha (instable, dev), beta (feature-complete, testable), rc (release candidate, plus de bugs connus)
- [ ] Le changelog est lisible par un humain — pas un dump de commits, pas de jargon interne
- [ ] Les artefacts sont signés ET vérifiables (Cosign/Sigstore, checksums SHA256, SBOM)
- [ ] Le tag Git est signé ET correspond exactement au commit du build (pas de tag après coup)
- [ ] Les releases sont immutables — jamais de repush d'un tag, jamais de republish d'un package

## Anti-patterns
### Version bloquée
**Ce qu'on voit :** `"version": "1.0.0"` dans package.json depuis 2 ans. 47 commits, des breaking changes, des nouvelles features — la version n'a jamais bougé.
**Pourquoi c'est dangereux :** la version ne communique plus rien. Les consommateurs ne savent pas s'ils peuvent upgrade. Certains pinent au commit, d'autres prennent `latest` et cassent. Le projet perd la confiance de son écosystème.
**Faire plutôt :** version bump à chaque release. Automatiser via conventional commits + semantic-release. Chaque merge sur main → version calculée → changelog mis à jour → release. Zéro intervention humaine.

### Changelog = dump de commits
**Ce qu'on voit :** CHANGELOG.md copié-collé depuis `git log --oneline`. "fix: bug", "wip", "cleanup", "fix test" — l'utilisateur ne comprend rien.
**Pourquoi c'est dangereux :** un changelog illisible est pire qu'inexistant. Il donne l'illusion d'information. Le consommateur doit lire le diff pour comprendre ce qui a changé — exactement ce que le changelog devait éviter.
**Faire plutôt :** changelog structuré : Added, Changed, Deprecated, Removed, Fixed, Security. Chaque entrée est une phrase compréhensible par un utilisateur du projet. Le changelog répond à : "Qu'est-ce que je dois faire pour upgrade ?"

### Pre-release sauté
**Ce qu'on voit :** `1.0.0-alpha.1` existe, puis directement `1.0.0`. Pas de beta, pas de RC. 6 mois entre alpha et stable.
**Pourquoi c'est dangereux :** les early adopters sont punis. Ils testent l'alpha, trouvent des bugs, mais n'ont jamais de version stable de leurs retours. Ils arrêtent de tester les pre-releases. La release stable sort sans validation réelle.
**Faire plutôt :** pipeline de maturité : alpha (semaine 1, cassant) → beta (semaine 2-3, testable, feedback) → rc (semaine 4, gel, uniquement bugfixes) → stable. Chaque étape a des consommateurs différents : devs internes → early adopters → tout le monde.

### Artefact mutable
**Ce qu'on voit :** `npm publish` puis `npm publish` à nouveau sur la même version parce que "j'ai oublié un fichier". Ou `git tag -d v1.2.3 && git tag v1.2.3`.
**Pourquoi c'est dangereux :** un artefact mutable détruit la reproductibilité. Le hash que tu as vérifié hier n'est plus valide aujourd'hui. Impossible de faire un audit. Les mirrors de registre ont des versions différentes. C'est un cauchemar de debugging.
**Faire plutôt :** une version = un artefact = un hash, pour toujours. Si bug → nouvelle version (1.2.4, pas 1.2.3 repush). La plupart des registres permettent de "deprecate" sans "unpublish".

## Patterns
### Conventional Commits → release automatisée
**Quand :** tout projet avec plus d'un mainteneur.
**Comment :** `feat:` → MINOR bump, `fix:` → PATCH bump, `feat!:` ou `BREAKING CHANGE:` → MAJOR bump. `semantic-release` lit l'historique de commits depuis la dernière release, calcule la version, génère le changelog, publie. Configuré une fois, oublié.

### Pre-release channels
**Quand :** projet avec breaking changes fréquents ou base d'utilisateurs qui teste les versions beta.
**Comment :** `1.0.0-alpha.1` → tags `alpha` instables. `1.0.0-beta.1` → tag `beta`, feature-complete. `1.0.0-rc.1` → tag `rc`, plus de bugs connus. `1.0.0` → tag `latest`. Les consommateurs choisissent leur niveau de risque : `npm install pkg@beta` ou `npm install pkg@latest`.

### Migration guide
**Quand :** tout MAJOR bump.
**Comment :** un fichier `MIGRATION.md` ou section dans le changelog. Format : "Avant → Après" pour chaque breaking change. Exemple de code avant, exemple après. Pourquoi le changement a été fait (pas juste "changed"). Liste des choses à vérifier après migration.
