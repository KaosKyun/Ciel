---
paths:
  - "**/.github/workflows/**"
  - "**/ci.yml"
  - "**/Jenkinsfile"
  - "**/.gitlab-ci.yml"
  - "**/bitbucket-pipelines.yml"
---

## CI/CD Pipeline

**Principe :** le pipeline est une machine à feedback, pas une checklist. Objectif : réduire le temps entre commit et signal de production. Mesure les 4 DORA metrics.

- Pipeline < 5 min — sinon les devs ne l'attendent plus
- Trunk-based development : branches ≤ 1 jour, merge fréquent, petits diffs
- OIDC pour l'auth cloud — pas de secrets long-lived dans les variables
- Runners éphémères : rien ne survit entre deux builds
- Concurrency groups : un seul pipeline par branche
- Artefacts immutables et signés (hash + Cosign/Sigstore)
- Flaky test detection : quarantaine automatique si > 2% de flaky
- Tests + lint + SAST + build dans le pipeline, pas de bypass
- Secrets injectés depuis OIDC/secrets manager, pas hardcodés
- Dependency scan blocant sur critique et haute

Pour patterns détaillés, charger `cicd-pipeline` ou `devsecops`.
