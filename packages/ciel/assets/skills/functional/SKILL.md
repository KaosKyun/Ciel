---
name: functional
description: "Programmation Fonctionnelle — immutabilite, fonctions pures, composition, monade, curry, pattern matching. A charger quand on utilise un style fonctionnel."
---

# Programmation Fonctionnelle

## Checklist
- [ ] Les fonctions sont pures : meme entree → meme sortie, pas d'effet de bord
- [ ] Les donnees sont immutables (pas de mutation, pas de `let`, pas de push/splice)
- [ ] Les effets de bord sont isoles en bordure du systeme (IO en fin de pipeline)
- [ ] La composition est utilisee (`pipe`, `compose`, `>>`) — pas d'appels imbriques
- [ ] Les types optionnels sont geres (Option/Maybe) — pas de null/undefined
- [ ] Les erreurs sont representees par le type (Either/Result) — pas de try/catch
- [ ] Les collections sont manipulees sans boucles (map, filter, reduce, flatMap)

## Anti-patterns
### Boucle imperatives
**Ce qu'on voit :** `let result = []; for (let i = 0; i < items.length; i++) { if (items[i].active) { result.push(items[i].name); } }`.
**Pourquoi c'est dangereux :** l'index `i` est un state mutable. La boucle est difficile a paralleliser. L'intention est cachee derriere le mecanisme.
**Faire plutot :** `items.filter(i => i.active).map(i => i.name)` — declaratif, immutable, intention claire. Parallelisable (map/filter n'ont pas d'ordre).

### Mutation globale
**Ce qu'on voit :** un module qui fait `state.cache.set(key, value)` directement, modifiant un etat global.
**Pourquoi c'est dangereux :** le state est modifie depuis n'importe ou. Le comportement est imprevisible. Le debugging est un cauchemar.
**Faire plutot :** passage explicite de l'etat. `const newState = updateCache(state, key, value)`. L'etat est une valeur pas une variable.

### try/catch partout
**Ce qu'on voit :** `try { const user = await getUser(id); } catch (e) { handleError(e); }` — attrape et propage sans type.
**Pourquoi c'est dangereux :** l'erreur n'est pas representee dans le type de retour. L'appelant ne sait pas que la fonction peut echouer. L'erreur peut etre oubliee.
**Faire plutot :** `const result: Result<User, Error> = await getUser(id)` — le type dit que l'appel peut echouer. L'appelant DOIT gerer les deux cas.

## Patterns
### Pipeline de transformation
**Quand :** transformation de donnees complexes.
**Comment :** `pipe(input, step1, step2, step3)` ou `input |> step1 |> step2 |> step3`. Chaque etape est une fonction pure. La derniere etape produit l'effet de bord (IO, affichage).

### Either/Result pour les erreurs
**Quand :** fonction qui peut echouer.
**Comment :** `Either<Error, T>` ou `Result<T, E>`. Le type represente l'echec. L'appelant matche sur `Left` (erreur) ou `Right` (succes). Pas de throw dans le code metier.
