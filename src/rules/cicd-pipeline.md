---
paths:
  - "**/.github/workflows/**"
  - "**/.gitlab-ci*"
  - "**/Jenkinsfile*"
  - "**/ci*"
  - "**/.circleci/**"
  - "**/azure-pipelines*"
---

## Dispatch
- Charge `cicd-pipeline` AVANT de modifier un pipeline CI/CD.
- Si le pipeline deploye → charge aussi `release-management`.

## Regles dures (zero tolerance)
- **Jamais** de secret dans le pipeline. OIDC ou secrets manager.
- **Jamais** de `on: push` sans filtrage de branche sur les jobs de deploy.
- **Jamais** de `--no-verify` ou `--no-gpg-sign` dans un pipeline.

## Conventions du projet
- Feedback < 5 min pour les tests unitaires, < 15 min pour l'integration.
- Matrix builds pour tester plusieurs versions.
- Runners ephemeres — pas d'etat persistant entre les jobs.
