---
paths:
  - "**/Dockerfile*"
  - "**/docker-compose*"
  - "**/.dockerignore"
  - "**/*.containerfile"
  - "**/compose*.yml"
  - "**/compose*.yaml"
---

## Dispatch
- Charge `containers` AVANT de modifier des conteneurs.
- Si le Dockerfile est pour la prod → charge aussi `appsec` + `supply-chain`.

## Regles dures (zero tolerance)
- **Jamais** de `:latest` en prod. Tag explicite ou digest SHA256.
- **Jamais** de root dans le container. USER non-root.
- **Jamais** de secret dans une couche Docker (COPY + RUN + rm = toujours dans l'historique).

## Conventions du projet
- Multi-stage builds pour separer build et runtime.
- Layer ordering : dependances (peu changeant) → code source (changeant).
- Healthcheck dans chaque container de service.
