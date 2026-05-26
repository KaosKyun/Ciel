---
paths:
  - ".github/**"
  - ".github/ISSUE_TEMPLATE/**"
  - ".github/workflows/**"
  - "**/pull_request_template.md"
---

## Dispatch
- Charge `github` AVANT de modifier les workflows, templates, ou la configuration GitHub.
- Si le workflow déploie → charge aussi `cicd-pipeline` et `release-management`.

## Règles dures (zero tolerance)
- **Jamais** de secret dans les workflows. OIDC ou `secrets: inherit` uniquement.
- **Jamais** de push direct sur main. PR obligatoire + review + CI verte.
- **Jamais** de PR sans issue liée (Closes #N) et description structurée.

## Conventions du projet
- Conventional Commits : `feat(scope):`, `fix(scope):`, `chore(scope):` — machine-readable.
- Branches ≤ 1 jour : `feat/`, `fix/`, `chore/`.
- PR < 400 lignes avec test plan.
- Templates d'issue (bug.yml, feature.yml) et de PR (pull_request_template.md).
