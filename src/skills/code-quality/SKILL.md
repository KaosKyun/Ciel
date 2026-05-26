---
name: code-quality
description: "Code Quality — linting, formatage, analyse statique, dette technique, conventions, complexite cyclomatique. A charger quand on parle de qualite ou standards de code."
---

# Code Quality

**Principe premier :** La qualite du code ne se mesure pas en "proprete" esthetique — elle se mesure en temps de comprehension pour le prochain developpeur. Un code "sale" mais compris en 30 secondes est meilleur qu'un code "propre" qui prend 10 minutes a decoder. Le linter et le formatter existent pour ELIMINER les debats de style, pas pour les multiplier. Si une regle de linting genere des discussions en code review, elle est contre-productive — desactive-la. Le standard de qualite n'est pas la perfection, c'est la consistance : le code doit avoir l'air ecrit par une seule personne, meme si l'equipe a 10 developpeurs.

## Checklist
- [ ] Le projet a un linter (ESLint, Biome, Ruff, Clippy) avec des regles strictes mais non controversees
- [ ] Le formatage est automatise (Prettier, dprint, gofmt) — zero debat de style en code review
- [ ] La complexite cyclomatique est limitee (max 15-20 par fonction) et mesuree dans la CI
- [ ] Les fichiers sont limits en taille (max 300-500 lignes) — au-dela, splitter
- [ ] Les commentaires expliquent le POURQUOI, pas le QUOI (le code dit deja QUOI)
- [ ] Le code mort est supprime, pas commente — git garde l'historique
- [ ] La duplication est toleree jusqu'a 3 occurrences — abstraire au 4e usage, pas au 2e (Rule of Three)

## Anti-patterns
### Linting maximaliste
**Ce qu'on voit :** 200 regles ESLint activees. `no-console`, `no-param-reassign`, `max-lines-per-function: 20`, `no-else-return`. Chaque commit declenche 15 erreurs qui ne sont PAS des bugs.
**Pourquoi c'est dangereux :** le linter n'est plus un outil — c'est un obstacle. Les devs le contournent (`eslint-disable` partout), le resultat est pire que pas de linter du tout. La fatigue du linter cree une culture ou les avertissements sont ignores.
**Faire plutot :** regles qui attrapent des BUGS, pas des preferences : `no-undef`, `no-unused-vars` (erreur, pas warning), `no-unsafe-*`. Formatage automatique, pas manuel. Tout le reste : warning ou off. L'objectif est zero faux positifs, pas un score de linting eleve.

### Refactoring sans filet
**Ce qu'on voit :** "je refactore cette classe pour la rendre plus propre." 2 semaines plus tard, 40 fichiers modifies, fonctionnalites cassees, aucun test ajoute.
**Pourquoi c'est dangereux :** le refactoring sans tests n'est pas du refactoring — c'est de la reecriture. Sans filet, chaque changement est un risque. Le "clean code" qui casse la production n'est pas propre — il est dangereux.
**Faire plutot :** tests AVANT refactoring. Si le code n'a pas de tests, en ecrire (characterization tests). Refactoring en petits pas, commit par commit. Si un test casse, revert immediatement.

### Abstraction prematuree (DRY abuse)
**Ce qu'on voit :** deux fonctions de 3 lignes qui se ressemblent → abstraction dans une classe mere. La 3e utilisation arrive, difference subtile → `if (specialCase)`. 4e utilisation → 4 parametres de configuration. L'abstraction est devenue plus complexe que le code duplique.
**Pourquoi c'est dangereux :** le mauvais DRY crée du couplage. Une abstraction prematuree lie ensemble des concepts qui evoluent differemment. Le cout de changer l'abstraction (tous les appels) depasse le cout de la duplication (2-3 endroits).
**Faire plutot :** Rule of Three : dupliquer jusqu'a 3 fois. A la 3e occurrence, abstraire. L'abstraction a maintenant 3 cas reels pour etre testee. Si la 4e occurrence ne rentre pas, l'abstraction etait prematuree — splitter.

## Patterns
### Boy Scout Rule
**Quand :** maintenance quotidienne.
**Comment :** "laisse le code plus propre que tu ne l'as trouve." Un petit nettoyage a chaque commit : renommer une variable, extraire une fonction, supprimer du code mort. Pas de refactoring massif — des micro-ameliorations continues.

### Static analysis in CI
**Quand :** toute PR.
**Comment :** le linter + l'analyse statique tournent dans la CI. Bloquant sur les regles de securite et de bug. Non-bloquant (annotation dans la PR) pour les suggestions de style. Exemple : `eslint --max-warnings 0` pour les regles d'erreur, `--quiet` pour le reste.
