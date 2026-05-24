---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/__tests__/**"
  - "**/test/**"
  - "**/tests/**"
---

## Dispatch
- Charge `testing` AVANT d'ecrire du code source.
- Si c'est un test d'integration avec DB → charge aussi `database-design`.
- Si c'est un test E2E → charge aussi `cicd-pipeline` (le test doit passer en CI).

## Regle dure (zero tolerance)
- **RED FIRST** : ecris le test et vois-le echouer avant d'ecrire le code source. Jamais l'inverse.
- **Flaky test** : si un test echoue sans changement de code > 2% du temps → quarantaine. Jamais "relance le job".
- **Pas de mock systematique** : vraie DB en integration (testcontainers, pg_tmp). Mock seulement les frontieres lentes (HTTP externe, email).

## Conventions du projet
- Test pyramid : 70% unitaires, 20% integration, 10% E2E.
- Tester le comportement observable, pas l'implementation. Input → output.
- Arrange-Act-Assert. DAMP > DRY dans les tests (lisibilite avant factorisation).
