---
name: frontend
description: "Frontend — React/Vue/Svelte, state management, routing, SSR/CSR, bundle size, lighthouse, accessibilite. A charger des qu'on touche a du code frontend."
---

# Frontend

## Checklist
- [ ] Le state management est choisi selon la complexite (useState → Context → Zustand → Redux)
- [ ] Le rendu est adapte : SSR pour SEO, CSR pour apps interactives, SSG pour contenu statique
- [ ] Les composants sont splittes par responsabilite (pas de composant de 500 lignes)
- [ ] Les props sont typees (TypeScript — pas de `any` sauf exception justifiee)
- [ ] Le bundle est optimise : lazy loading, code splitting, tree shaking
- [ ] Le lighthouse score est ≥ 90 (perf + a11y + best practices)
- [ ] Les formulaires gerent : loading, error, success, validation
- [ ] L'accessibilite de base est respectee : labels, keyboard nav, contrast, ARIA

## Anti-patterns
### State management premature
**Ce qu'on voit :** Redux installe pour un formulaire de contact. 50 fichiers pour gerer un state trivial.
**Pourquoi c'est dangereux :** boilerplate massif pour zero benefice. Les devs perdent du temps a naviguer entre reducers/actions/selectors.
**Faire plutot :** useState jusqu'a ce que le state soit partage par ≥ 3 composants eloignes. Puis Context. Puis Zustand. Redux seulement pour des apps complexes avec besoin de devtools et middleware.

### useEffect pour tout
**Ce qu'on voit :** `useEffect(() => { setDerived(data) }, [data])` partout. Des cascades de useEffects qui se declenchent mutuellement.
**Pourquoi c'est dangereux :** rendus en cascade, state inconsistent, bugs subtils de timing.
**Faire plutot :** deriver le state pendant le rendu quand c'est possible. `const derived = computeDerived(data)` directement, pas dans un useEffect.

### Bundle non surveille
**Ce qu'on voit :** `import { something } from "heavy-lib"` — la lib entiere est dans le bundle, pas juste `something`.
**Pourquoi c'est dangereux :** 2 Mo de JS pour une landing page. 5 secondes de chargement sur 3G.
**Faire plutot :** `import("heavy-lib").then(m => m.something)` (dynamic import). Analyser le bundle avec `vite-bundle-visualizer` ou `next-bundle-analyzer`.

## Patterns
### Suspense boundaries
**Quand :** chargement asynchrone de composants (data fetching, lazy loading).
**Comment :** wrapper `<Suspense fallback={<Skeleton />}>` autour du composant asynchrone. Evite les `if (loading) return <Spinner>` dans chaque composant.

### Compound components
**Quand :** un composant a plusieurs sous-composants qui partagent un state implicite. Ex: `<Select><Option/></Select>`.
**Comment :** le parent gere le state, les enfants lisent le contexte. API propre sans prop drilling.

### Optimistic update
**Quand :** l'interface doit etre instantanee meme si le serveur est lent.
**Comment :** mettre a jour l'UI immediatement (comme si l'operation avait reussi). Si le serveur echoue → rollback + erreur.
