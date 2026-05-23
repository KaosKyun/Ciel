---
paths:
  - "**/*.tf"
  - "**/*.pulumi*"
  - "**/terraform/**"
  - "**/ansible*"
---

## Infrastructure as Code

- Terraform state stocke dans un backend distant (S3, GCS) — jamais en local
- State locking active (DynamoDB, Consul) pour eviter les conflits
- Drift detection automatisee (plan regulier, policy as code)
- Secrets dans un secret manager (Vault, AWS Secrets Manager) — pas dans les variables
- Modules versionnes (tag git ou registry) — pas de source relative
- Plan review obligatoire avant apply
- Destroy protection sur les ressources critiques
- Tags/namespaces coherents pour le cost allocation
- Principe du moindre privilege IAM

Pour anti-patterns et patterns detailles, charger `iac` ou `cloud`.
