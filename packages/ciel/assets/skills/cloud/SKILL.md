---
name: cloud
description: "Cloud Architecture — AWS/GCP/Azure, compute (EC2/Lambda), stockage (S3/RDS), IAM least privilege, networking (VPC), cost optimization. A charger quand on conçoit une architecture cloud."
---

# Cloud Architecture

## Checklist
- [ ] IAM least privilege : chaque service, chaque utilisateur a les permissions minimales necessaires
- [ ] Les donnees au repos sont chiffrees (S3 SSE, RDS encryption, EBS encryption)
- [ ] Les donnees en transit sont chiffrees (TLS >= 1.2 partout)
- [ ] Auto-scaling est configure (nombre min/max de instances, metriques de scale)
- [ ] Budget alerts sont en place (facture surveillee, alerte a 80%/100%)
- [ ] Les backups sont automatises (RDS backups, S3 versioning, snapshots)
- [ ] Les logs sont centralises (CloudWatch, Stackdriver, ou outil tiers)
- [ ] Multi-AZ deployment (au moins 2 zones de disponibilite)

## Anti-patterns
### IAM AdministratorAccess
**Ce qu'on voit :** chaque nouveau service recoit une cle IAM avec `AdministratorAccess` pour etre tranquille.
**Pourquoi c'est dangereux :** si la cle fuit, l'attaquant peut tout faire : supprimer la DB, creer des instances minieres, exfiltrer les donnees.
**Faire plutot :** politiques IAM les plus restreintes possibles. `Effect: Deny` avant `Effect: Allow`. Policies gerees par infrastructure as code, pas dans la console.

### Tout dans un seul compte
**Ce qu'on voit :** developpement, staging, production dans le meme compte AWS/GCP.
**Pourquoi c'est dangereux :** un `npx eslint` compromis en dev peut supprimer la DB de prod. Les limites de service sont partagees.
**Faire plutot :** comptes separes (ou projects GCP) par environnement. Ou a minima des VPC separes avec des roles differs.

### Pas de budget alert
**Ce qu'on voit :** la facture cloud est une surprise a la fin du mois. Parfois x10.
**Pourquoi c'est dangereux :** un dev laisse tourner une instance GPU, une API tierce coute $1000/jour sans qu'on le sache.
**Faire plutot :** budget alerts a 80% et 100%. Cost anomaly detection. Tags de cout obligatoires (project, service, equipe). Revue mensuelle de la facture.

## Patterns
### Multi-AZ
**Quand :** toute charge de travail en production.
**Comment :** deployer sur au moins 2 zones de disponibilite. Le load balancer repartit le trafic. RDS Multi-AZ (standby dans une autre zone). S3 est automatiquement multi-AZ.

### Auto-scaling
**Quand :** charge variable (la plupart des apps).
**Comment :** Groupe d'auto-scaling. Metriques : CPU > 70% -> ajouter une instance. CPU < 30% -> retirer. Min/Max configures. Cooldown pour eviter les cycles rapides.

### Tags de cout
**Quand :** plusieurs equipes/projets partagent le meme compte.
**Comment :** `Project=Billing`, `Service=API`, `Environment=prod`, `Team=backend`. Obligatoires sur chaque ressource. Dashboards de cout par tag.
