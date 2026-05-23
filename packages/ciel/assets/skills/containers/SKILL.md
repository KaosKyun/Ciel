---
name: containers
description: "Containers — Docker multi-stage builds, distroless, K8s pods/deployments/services, Helm, security. A charger quand on travaille avec Docker ou Kubernetes."
---

# Containers

## Checklist
- [ ] Le Dockerfile utilise multi-stage build (builder + runtime separate)
- [ ] L'image de base est minimale (Alpine, distroless, chainguard)
- [ ] Le container ne tourne pas en root (`USER 1001` ou equivalent)
- [ ] Les secrets sont injectes au runtime (pas dans l'image Docker)
- [ ] Les images sont scannees (CVE, Trivy, Docker Scout)
- [ ] Les resources sont limitees (CPU/memory limits en K8s ou Docker)
- [ ] Les healthchecks sont definis (Docker HEALTHCHECK, K8s liveness/readiness)
- [ ] Les couches Docker sont optimisees (ordre stable → volatile, .dockerignore)

## Anti-patterns
### Container en root
**Ce qu'on voit :** Dockerfile sans instruction `USER`. Le process tourne avec les droits root dans le container.
**Pourquoi c'est dangereux :** si le container est compromis, l'attaquant a les droits root. Escalade possible vers l'hote.
**Faire plutôt :** `RUN addgroup -S app && adduser -S app -G app` puis `USER app:app`. Distroless si possible (pas de shell).

### Image geante
**Ce qu'on voit :** Dockerfile en une etape : `FROM node:22-slim` + `COPY node_modules` (1.2 Go).
**Pourquoi c'est dangereux :** image volumineuse → telechargement lent, deploiement lent, plus de surface d'attaque.
**Faire plutôt :** multi-stage : `FROM node:22 AS builder` (node_modules, build) → `FROM node:22-slim` (copie uniquement les artefacts). Distroless pour le runtime. Image finale < 100 Mo.

### Tout dans un seul manifeste K8s
**Ce qu'on voit :** un fichier YAML de 500 lignes avec Deployment + Service + ConfigMap + Ingress.
**Pourquoi c'est dangereux :** difficile a lire, impossible a tester separement, pas de reutilisabilite.
**Faire plutôt :** un fichier par ressource OU un chart Helm. Helm permet de parametrer, versionner, et deployer avec `helm upgrade --install`.

## Patterns
### Multi-stage build
**Quand :** toute image Docker qui compile du code.
**Comment :** etape 1 (builder) : outils de build, dependances de dev. Etape 2 (runtime) : minimal, seulement les binaires. `COPY --from=builder /app/dist /app/dist`.

### K8s health checks
**Quand :** toute application dans Kubernetes.
**Comment :** liveness probe (le container est-il vivant ?), readiness probe (le container accepte-t-il du trafic ?), startup probe (le container a-t-il fini de demarrer ?).

### .dockerignore
**Quand :** tout projet Docker.
**Comment :** ignorer node_modules, .git, *.md, logs, .env. Reduce le contexte envoye au daemon Docker, accelere les builds.
