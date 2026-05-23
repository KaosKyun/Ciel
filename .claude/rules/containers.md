---
paths:
  - "**/Dockerfile*"
  - "**/docker-compose*"
  - "**/*.k8s*"
  - "**/kubernetes/**"
---

## Containers

- Multi-stage builds — separer build et runtime, image finale minimale
- Distroless ou Alpine comme base, pas ubuntu:latest
- USER non-root (pas de USER root)
- HEALTHCHECK defini dans le Dockerfile
- Tags d'image immuables (sha256 ou version specifique) — pas de `:latest` en prod
- Secrets montes en volume tmpfs, pas dans les layers de l'image
- Resource limits (CPU/memory) definis dans le deployment
- Pas de `docker run` manuel en prod — orchestrateur (k8s, ECS, compose)
- Liveness + readiness probes sur chaque conteneur

Pour anti-patterns et patterns detailles, charger `containers`.
