---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
  - "**/*.vue"
  - "**/*.svelte"
  - "**/*.css"
  - "**/*.scss"
  - "**/components/**"
  - "**/pages/**"
---

## Dispatch
- Charge `frontend` AVANT d'ecrire du code frontend.
- Si le composant gere l'auth → charge aussi `appsec`.

## Regles dures (zero tolerance)
- **Jamais** de state management disproportionne : useState → Context → Zustand → Redux (pas l'inverse).
- **Jamais** de `useEffect` en cascade. Deriver pendant le rendu.
- **Jamais** de bundle > 200KB sans code splitting par route.

## Conventions du projet
- Lighthouse ≥ 90 sur perf + a11y + best practices — mesure dans la CI.
- Accessibilite de base non-negociable : labels, keyboard nav, contrast, ARIA.
- Formulaires : idle, loading, success, error, validation — tous les etats geres.
