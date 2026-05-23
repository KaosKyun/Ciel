---
name: frontend
description: "Frontend — state management as complexity spectrum, rendering strategy (SSR/CSR/SSG), bundle as UX metric, optimistic UI. À charger quand on touche à du code frontend."
---

# Frontend

**Principe premier :** Le frontend n'est pas "afficher des données HTML" — c'est gérer la complexité d'état sur un appareil qu'on ne contrôle pas. La seule métrique qui compte vraiment est le temps jusqu'à l'interaction (TTI). Tout le reste — state management, code splitting, SSR — est un moyen de réduire le TTI. Si ta stack "moderne" produit un TTI de 5 secondes, elle est moins performante qu'un site HTML vanilla de 2005. L'utilisateur ne voit pas ta stack, il voit le temps de chargement.

## Checklist
- [ ] Le state management est proportionnel à la complexité : useState → Context → Zustand → Redux (pas l'inverse)
- [ ] La stratégie de rendu est délibérée : SSR pour SEO, CSR pour apps interactives, SSG pour contenu statique
- [ ] Le bundle est surveillé : JS < 200KB, lazy loading au-dessus du fold, code splitting par route
- [ ] Lighthouse ≥ 90 sur perf + a11y + best practices — mesuré dans la CI
- [ ] Les formulaires gèrent TOUS les états : idle, loading, success, error, validation
- [ ] L'accessibilité de base est non-négociable : labels, keyboard nav, contrast minimum, ARIA sur les composants interactifs

## Anti-patterns
### State management comme religion
**Ce qu'on voit :** Redux installé pour un formulaire de contact. Store, reducers, actions, selectors, middleware — 50 fichiers pour stocker `{email, message}`.
**Pourquoi c'est dangereux :** le state management a un coût cognitif. Chaque couche ajoute de l'indirection. Pour un state local à un formulaire, useState suffit. Le bon outil est celui qui résout le problème avec le moins de code — pas celui qui est "le standard de l'industrie".
**Faire plutôt :** spectre de complexité. useState pour le state local. Context pour le state partagé par < 5 composants. Zustand pour le state global simple. Redux uniquement si tu as besoin de devtools, middleware, et normalisation de state complexes.

### useEffect comme solution à tout
**Ce qu'on voit :** des chaînes de `useEffect` qui se déclenchent les unes les autres. `useEffect(() => setB(a), [a]); useEffect(() => setC(b), [b])`. Props → state → render → effect → state → render → effect...
**Pourquoi c'est dangereux :** c'est du state management par effets de bord. Chaque render supplémentaire est une opportunité de bug. Les cascades d'effets créent des états intermédiaires incohérents visibles par l'utilisateur.
**Faire plutôt :** dériver pendant le rendu. `const derived = computeExpensive(data)` sans useEffect — React le recalcule au bon moment. `useMemo` pour les calculs coûteux, pas pour contourner un problème d'architecture.

### Bundle obèse
**Ce qu'on voit :** `import { debounce } from "lodash"` → toute la librairie lodash (70KB) dans le bundle pour une fonction de 10 lignes.
**Pourquoi c'est dangereux :** le bundle est le premier facteur du TTI. 2 Mo de JS sur une connexion 3G = 20 secondes avant que l'utilisateur puisse interagir. La moitié des utilisateurs abandonnent après 3 secondes.
**Faire plutôt :** `import debounce from "lodash/debounce"`. Bundle analyzer dans la CI (`vite-bundle-visualizer`, `next-bundle-analyzer`). Budget de bundle : si la PR dépasse +50KB, bloquer et justifier.

## Patterns
### Suspense boundaries
**Quand :** chargement asynchrone de données ou de code.
**Comment :** `<Suspense fallback={<Skeleton />}>` autour du composant asynchrone. Le composant ne gère pas son propre état de chargement — le parent le fait. Permet de composer le chargement (tout chargé → afficher, plutôt que chaque widget avec son spinner).

### Optimistic update
**Quand :** l'interface doit être perçue comme instantanée.
**Comment :** mettre à jour l'UI immédiatement comme si l'opération avait réussi. Envoyer la requête au serveur. Si succès → rien à faire. Si échec → rollback + notification d'erreur. L'utilisateur ne voit la latence que si l'opération échoue.
