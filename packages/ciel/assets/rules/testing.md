---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/__tests__/**"
  - "**/test/**"
  - "**/tests/**"
---

## Testing

- RED (test echoue) → GREEN (passe) → REFACTOR. Jamais de code sans test d'abord.
- Test pyramid: 70% unitaires, 20% integration, 10% E2E
- Tester le comportement observable, pas l'implementation
- Chaque test cree ses propres donnees (setup/teardown) — pas d'ordre implicite
- Bug fixes: reproduction test obligatoire avant le fix
- Pas de mock systematique — vraie DB en integration
- Arrange-Act-Assert, DAMP > DRY dans les tests

Pour anti-patterns et patterns detailles, charger le skill `testing`.
