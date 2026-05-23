---
paths:
  - "**/services/**"
  - "**/middleware/**"
  - "**/server*"
---

## Backend

- Timeout explicite sur chaque appel externe (DB, API, queue) — pas d'infini
- Graceful shutdown: SIGTERM → drain des requetes → close DB → exit
- Health check: `GET /health` → `{status: "ok", db, uptime}`
- Erreurs structurees : `{error: {code, message, details}}` — jamais `200 OK {error: "..."}`
- Background jobs idempotents avec retry + dead letter queue
- Connection pooling sur DB, Redis, HTTP clients
- Rate limiting sur endpoints publics
- CORS, helmet, compression configures
- Input validation a la frontiere de l'app (jamais dans la logique metier)

Pour anti-patterns et patterns detailles, charger le skill `backend`.
