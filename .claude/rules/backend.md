---
paths:
  - "**/services/**"
  - "**/*Service*"
  - "**/*Server*"
  - "**/server*"
---

## Dispatch
- Charge `backend` AVANT d'ecrire du code backend.
- Si le service appelle une DB → charge aussi `database-design`.
- Si le service gere des donnees utilisateur → charge aussi `appsec`.

## Regles dures (zero tolerance)
- **Jamais** avaler les erreurs. Soit gerer (retry, fallback), soit laisser remonter.
- **Jamais** de `process.exit(0)` sur SIGTERM. Graceful shutdown : stop accepter → drainer → close → exit.
- **Jamais** de connexion unique DB/Redis. Connection pooling obligatoire.

## Conventions du projet
- Chaque endpoint a un timeout explicite.
- Health check : liveness ≠ readiness.
- Erreurs structurees en prod, jamais de stack trace.
