---
paths:
  - "**/*.{tsx,jsx,vue,svelte}"
  - "**/components/**"
  - "**/pages/**"
---

## Frontend

- Bundle size: pas de lib entiere si 1 fonction suffit (eviter moment.js, lodash entier)
- Lighthouse: Performance > 90, Accessibility > 95, Best Practices > 90
- SSR/CSR: pas de flash de contenu non rendu, SEO si page publique
- State: pas de prop drilling > 2 niveaux, utiliser Context/Zustand/Redux
- Images: lazy loading, WebP, srcset, dimensions explicites (pas de CLS)
- Forms: validation cote client ET serveur, etats loading/error/success
- Pas de `dangerouslySetInnerHTML` sans sanitization (DOMPurify)
- Accessibilite: labels sur les inputs, roles ARIA, navigation clavier
- Les cles de liste sont stables et uniques (pas d'index)

Pour anti-patterns et patterns detailles, charger le skill `frontend`.
