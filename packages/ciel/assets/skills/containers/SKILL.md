---
name: containers
description: "Containers — multi-stage builds, distroless, non-root, K8s health checks, resource limits, image immutability. À charger quand on travaille avec Docker ou Kubernetes."
---

# Containers

**Principe premier :** Un container n'est pas une VM légère — c'est un process isolé. L'image Docker est un artefact immutable, pas un serveur maintenu à coup de `docker exec`. Chaque couche ajoutée est une surface d'attaque. Le but : l'image la plus petite possible. Et ne jamais tourner en root — non-root est la baseline, pas un bonus.

## Checklist
- [ ] Multi-stage build : builder (outils) → runtime (artefacts uniquement, minimal)
- [ ] Image de base minimale : distroless ou Chainguard — pas de shell, pas de package manager
- [ ] Container non-root (`USER 1001`) — `runAsNonRoot: true` dans K8s
- [ ] Secrets injectés au runtime (K8s secrets, Vault) — pas dans l'image, pas en ARG
- [ ] Ressources limitées (CPU/memory limits AND requests) — pas de "illimité"
- [ ] Health checks : liveness, readiness, startup — les trois
- [ ] Images taguées par version ET hash de commit — jamais `:latest`

## Anti-patterns
### Container en root
**Ce qu'on voit :** Dockerfile sans `USER`. Le process tourne en root.
**Pourquoi c'est dangereux :** container compromis = root inside → escalade possible vers l'hôte. La plupart des applications n'ont jamais besoin de root. C'est un défaut historique, pas une nécessité.
**Faire plutôt :** `USER 1001:1001`. Distroless (pas de shell). `runAsNonRoot: true`, `readOnlyRootFilesystem: true` dans K8s.

### Image obèse
**Ce qu'on voit :** `FROM node:22` → image de 1.5 Go avec git, curl, npm, code source complet.
**Pourquoi c'est dangereux :** pull lent = déploiement lent = rollback lent. Surface d'attaque maximale. Coût de stockage.
**Faire plutôt :** multi-stage : builder compile → runtime minimal. `COPY --from=builder`. Distroless. Image < 100 Mo.

### `:latest` partout
**Ce qu'on voit :** `image: myapp:latest`. Impossible de savoir quelle version tourne.
**Pourquoi c'est dangereux :** non-reproductible. Si `latest` change sur le registry, le prochain pod restart aura une version différente. Rollback impossible.
**Faire plutôt :** tag sémantique + hash de commit. `myapp:v1.2.3`, `myapp:abc1234`. Immutable.

## Patterns
### Multi-stage build
**Quand :** toute image qui compile du code.
**Comment :** builder (`FROM golang:1.22 AS builder`) → compile → runtime (`FROM gcr.io/distroless/static`) → `COPY --from=builder /app/binary`. Résultat : un binaire et rien d'autre.

### K8s health checks
**Quand :** tout pod Kubernetes.
**Comment :** liveness (process vivant ?), readiness (trafic OK ?), startup (init fini ?). Sans readiness, K8s envoie du trafic avant que l'app soit prête → erreurs en boucle.
