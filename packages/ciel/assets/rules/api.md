---
paths:
  - "**/api/**"
  - "**/routes/**"
  - "**/*Controller*"
  - "**/*Endpoint*"
  - "**/*Route*"
---

## API Design

- Endpoints versionnes (/v1/ ou header Accept-Version)
- Pagination cursor-based (pas offset) — `?cursor=abc&limit=50`
- Erreurs structurees : `{error: {code, message, details}}`
- Mutations (POST/PUT/DELETE) requierent header `Idempotency-Key`
- Rate limiting sur tous les endpoints publics
- Pas de breaking change sans nouvelle version
- OpenAPI / schema documente

Pour anti-patterns et patterns detailles, charger le skill `api-design`.
