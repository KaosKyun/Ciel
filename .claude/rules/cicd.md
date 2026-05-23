---
paths:
  - "**/.github/workflows/**"
  - "**/ci.yml"
  - "**/Jenkinsfile"
  - "**/.gitlab-ci.yml"
  - "**/bitbucket-pipelines.yml"
---

## CI/CD Pipeline

- Matrix builds pour tester plusieurs versions (Node 18/20/22)
- Cache les dependances entre les runs (node_modules, pip, maven)
- Utiliser OIDC pour l'auth cloud — pas de secrets longue duree dans les pipelines
- Verifier les signatures des artifacts (SLSA, provenance)
- Secrets injectes depuis le secret manager, pas hardcodes
- Scanner les dependances (npm audit, pip audit, trivy)
- Tests + lint + build dans le pipeline, pas de bypass
- Timeout explicite sur chaque job

Pour anti-patterns et patterns detailles, charger `cicd-pipeline` ou `devsecops`.
