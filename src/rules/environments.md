---
paths:
  - ".github/workflows/**"
  - ".github/environments/**"
  - "**/environment*"
  - "**/deploy*"
  - "**/ci*.yml"
  - "**/ci*.yaml"
  - "**/.env*"
  - ".env.example"
---

## Dispatch
- Charge `environments` AVANT de modifier la configuration de deploiement, les workflows de deploy, ou les variables d'environnement.
- Si la tache touche aux secrets → charge aussi `security` et `appsec`.
- Si la tache touche au pipeline CI/CD → charge aussi `cicd-pipeline`.

## Regles dures (zero tolerance)
- **Jamais** de secret partage entre environnements. Chaque environnement a ses propres credentials.
- **Jamais** de deploy direct en production sans gate humaine. Staging d'abord, validation, puis production.
- **Jamais** de promotion inversee (prod → staging). Le flux est toujours dev → staging → prod.

## Conventions du projet
- Au moins 2 environnements : staging/preview + production.
- GitHub Environments pour les secrets par environnement (fonctionne sans organisation).
- Staging est le jumeau de production — meme stack, meme config, donnees et echelle differentes.
- Logs et metriques centralises avec tag `env:` (staging/production).
