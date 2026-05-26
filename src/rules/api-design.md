---
paths:
  - "**/routes/**"
  - "**/*Routes*"
  - "**/*Controller*"
  - "**/*Handler*"
  - "**/openapi*"
  - "**/swagger*"
---

## Dispatch
- Charge `api-design` AVANT d'ecrire ou modifier un endpoint.
- Si l'endpoint gere des donnees utilisateur → charge aussi `appsec`.

## Regles dures (zero tolerance)
- **Jamais** de breaking change sans nouvelle version ou deprecation window explicite.
- **Jamais** de `200 OK` avec erreur dans le corps. Codes HTTP standard.
- **Jamais** de pagination offset-based. Cursor-based uniquement.

## Conventions du projet
- Erreurs structurees : `{error: {code, message, details}}`.
- Mutations POST/PUT/DELETE avec `Idempotency-Key`.
- Rate limiting avec headers standards : `Retry-After`, `X-RateLimit-*`.
