---
name: iac
description: "Infrastructure as Code — Terraform/Pulumi/Ansible, state management, drift detection, modules. A charger quand on definit ou modifie l'infrastructure par code."
---

# Infrastructure as Code

## Checklist
- [ ] L'infrastructure est entierement definie dans le code (pas de clics dans la console)
- [ ] Le state est stocke dans un backend securise (S3 + DynamoDB lock, Terraform Cloud)
- [ ] Les modules sont reutilisables (pas de copier-coller de ressources)
- [ ] Les variables sensibles sont dans un vault (pas en clair dans les fichiers .tfvars)
- [ ] Les environnements (dev/staging/prod) sont strictement identiques en configuration (taille variable, pas structure)
- [ ] `terraform plan` ou equivalent est dans la CI (detection de drift)
- [ ] Les tags ou labels sont obligatoires sur chaque ressource

## Anti-patterns
### Console cloud comme unique interface
**Ce qu'on voit :** les ressources sont creees manuellement dans la console AWS/GCP/Azure.
**Pourquoi c'est dangereux :** impossible de reproduire l'environnement. Staging et prod divergent. Si le compte est supprime, tout est perdu.
**Faire plutôt :** tout est dans Terraform/Pulumi. La console est read-only (consultation). Toute modification passe par `terraform apply` dans la CI.

### State local
**Ce qu'on voit :** `terraform { backend "local" {} }`. Le fichier `terraform.tfstate` est dans le .gitignore.
**Pourquoi c'est dangereux :** si la machine de dev est perdue, le state est perdu. Impossible de savoir ce qui est deploye. Deux devs peuvent ecraser le state de l'autre.
**Faire plutôt :** backend S3 (ou GCS/Azure Storage) avec DynamoDB pour le locking. Le state est partage et verrouille pendant les operations.

### Secrets en clair
**Ce qu'on voit :** `db_password = "super-secret-123"` dans `variables.tf` ou `prod.tfvars`.
**Pourquoi c'est dangereux :** le mot de passe est dans le repo Git, visible par tous les devs, dans l'historique.
**Faire plutôt :** secret store (AWS Secrets Manager, HashiCorp Vault, SOPS). `data.aws_secretsmanager_secret.db_password`. Rotation automatique.

## Patterns
### State backend securise
**Quand :** toute equipe utilisant Terraform.
**Comment :** S3 bucket + DynamoDB table. `terraform init` configure le backend. Le locking empeche les ecritures concurrentes.

### Module reutilisable
**Quand :** la meme configuration est utilisee dans plusieurs environnements ou projets.
**Comment :** module `vpc` avec variables `cidr_block`, `environment`. Utilise avec `module "vpc_prod" { source = "./modules/vpc" cidr_block = "10.0.0.0/16" environment = "prod" }`.

### Drift detection
**Quand :** infrastructure en production.
**Comment :** `terraform plan` lance dans la CI tous les jours ou a chaque commit. Si le plan montre des changements non attendus → alerte : drift detecte.
