---
name: functional
description: "Programmation Fonctionnelle — immutabilite, fonctions pures, composition, Result/Option, pattern matching. A charger quand on utilise un style fonctionnel."
---

# Programmation Fonctionnelle

**Principe premier :** La programmation fonctionnelle n'est pas "utiliser `map` et `filter`" — c'est un contrat avec toi-meme : tu ne modifieras pas l'etat existant. Ce contrat elimine une classe entiere de bugs (les mutations surprises, les races conditions sur l'etat mutable, les effets de bord caches). Une fonction pure est un sous-programme qui ne depend QUE de ses parametres et ne produit QUE sa valeur de retour. Pas de `this`, pas de variable globale, pas d'appel DB cache. Le prix a payer : tout copier est plus lent, et certains algorithmes sont plus naturels en imperatif. Le benefice : une fonction pure est testable, parallelisable, et raisonnable isolement — pas besoin de lire 10 fichiers pour comprendre ce qu'elle fait.

## Checklist
- [ ] Les fonctions sont pures : meme entree → meme sortie, pas d'effet de bord (DB, HTTP, file)
- [ ] Les donnees sont immutables — pas de `push`, `splice`, `delete`, `sort()` in-place
- [ ] Les erreurs sont modelisees comme des valeurs (Result<T, E>, Option<T>) — pas d'exceptions non gerees
- [ ] La composition remplace l'heritage : `compose(f, g)(x)` plutot que `class B extends A`
- [ ] Les effets de bord sont pousses aux bords du systeme (entree/sortie) — le cœur est pur
- [ ] Le pattern matching est utilise pour les unions discriminantes — pas de `if (type === "...")` en chaine
- [ ] Pas de `null` — utiliser `Option<T>` (Some/None) pour les valeurs optionnelles

## Anti-patterns
### FP = utiliser des callbacks
**Ce qu'on voit :** `array.map(x => x * 2).filter(x => x > 5)` et l'equipe pense "on fait de la FP". Mais tout le reste est mutable et impur.
**Pourquoi c'est dangereux :** la FP n'est pas une liste d'operations sur tableau — c'est une discipline sur l'etat et les effets de bord. Utiliser `map` sans immutabilite, c'est mettre un autocollant "functional" sur du code imperatif. Les vrais bugs sont toujours dans les mutations partagees.
**Faire plutot :** commencer par l'immutabilite (c'est le plus gros gain). Ensuite pousser les effets de bord aux bords. Enfin, modeliser les erreurs comme valeurs. Les `map`/`filter`/`reduce` viendront naturellement.

### Exception pour le flux de controle
**Ce qu'on voit :** `throw new UserNotFoundError()` dans un service, `catch (e) { if (e instanceof UserNotFoundError)... }` 3 couches plus haut.
**Pourquoi c'est dangereux :** l'exception casse le contrat de la fonction. La signature dit `User → UserProfile` mais en realite la fonction peut throw. Le compilateur ne verifie pas les exceptions (dans la plupart des langages). Le flux de controle devient implicite et non type.
**Faire plutot :** retourner `Result<UserProfile, UserNotFoundError>`. L'appelant est force de gerer les deux cas. Le flux de controle est explicite et type. Pattern matching : `match result { Ok(profile) => ..., Err(UserNotFound) => ... }`.

### Immutabilite = tout copier naivement
**Ce qu'on voit :** `return { ...state, items: [...state.items, newItem] }` dans un reducer Redux avec 10000 items. Chaque update copie tout le tableau.
**Pourquoi c'est dangereux :** l'immutabilite naive est O(n) en memoire et en temps. Pour une liste de 100000 elements, 100 updates/s = 10 millions de copies = memoire explose. L'equipe conclut "la FP c'est lent" alors que c'est juste l'implementation.
**Faire plutot :** structures de donnees persistantes (Immutable.js, Immer avec structural sharing). Elles partagent la memoire entre les versions. O(log n) ou O(1) pour la plupart des operations. L'immutabilite n'est pas lente — la copie naive l'est.

## Patterns
### Result/Either type
**Quand :** toute operation qui peut echouer pour une raison connue (validation, lookup, parsing).
**Comment :** `type Result<T, E> = Ok<T> | Err<E>`. L'appelant pattern-match sur le resultat. Tous les chemins sont types et verifies. Pas de `try/catch` pour le flux normal. Les erreurs font partie du contrat de la fonction.

### Sandwitch fonctionnel (IO sandwich)
**Quand :** une operation qui doit lire des donnees, les transformer, et ecrire le resultat.
**Comment :** (1) Lire toutes les donnees necessaires (IO, impur), (2) transformation pure en memoire (cœur, pur), (3) ecrire le resultat (IO, impur). Les entrees/sorties sont aux bords, le cœur est pur et testable sans mocks.
