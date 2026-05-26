---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/terraform/**"
  - "**/*.bicep"
  - "**/cloudformation/**"
  - "**/pulumi/**"
---

## Dispatch
- Charge `iac` AVANT de definir ou modifier de l'infrastructure.
- Si l'infra deploie en cloud → charge aussi `cloud`.
- Si secrets ou IAM impliques → charge aussi `security`.

## Regles dures (zero tolerance)
- **Jamais** de secret en clair dans le code IaC — reference depuis un secret manager.
- **Jamais** de state local ou commite — backend distant chiffre AVEC locking (S3+DynamoDB, TF Cloud, Pulumi SaaS).
- **Jamais** de ressource creee a la main (console) — tout en code, sinon `import`. Console en read-only.
- **Jamais** d'`apply` depuis un laptop en prod — pipeline avec OIDC et permissions minimales.

## Conventions du projet
- Immutabilite : `create_before_destroy`, on remplace, on ne modifie pas en place.
- Modules versionnes (tag git), decoupes par cycle de vie (reseau / compute / DB separes).
- Drift detection en CI (hebdo) ; tout ecart → ticket, corriger la cause pas l'effet.
- `plan -out` sauvegarde et applique depuis le meme fichier.
