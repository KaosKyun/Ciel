---
name: cloud
description: "Cloud — IAM least privilege comme principe zero, multi-account, cost optimization, auto-scaling, managed services vs DIY. À charger quand on conçoit une architecture cloud."
---

# Cloud

**Principe premier :** Le cloud n'est pas "des serveurs chez Amazon" — c'est un modèle de responsabilité partagée où la sécurité est programmatique. La console AWS/GCP n'est PAS ton interface de gestion — c'est une porte dérobée pour le debugging. Tout doit être Infrastructure as Code. Le principe zéro est IAM least privilege : chaque service, chaque humain, chaque pipeline a EXACTEMENT les permissions nécessaires et rien de plus. Une permission de trop = une surface d'attaque inutile. Le second principe est que le cloud est un abonnement, pas un achat — chaque ressource qui tourne coûte de l'argent, 24/7.

## Checklist
- [ ] IAM least privilege : chaque rôle/service a les permissions minimales — revu trimestriellement
- [ ] Infrastructure as Code (Terraform/Pulumi/CloudFormation) — zéro ressource créée à la main
- [ ] Environnements séparés (comptes/projects différents) — la dev ne touche pas la prod
- [ ] Données chiffrées au repos (S3 SSE, RDS encryption, EBS encryption) et en transit (TLS)
- [ ] Auto-scaling configuré avec min/max et métriques pertinentes
- [ ] Budget alerts à 80% et 100% + cost anomaly detection
- [ ] Multi-AZ sur toute charge de production — une AZ peut tomber

## Anti-patterns
### IAM AdministratorAccess partout
**Ce qu'on voit :** chaque service, chaque dev, chaque pipeline a `AdministratorAccess` "pour pas être bloqué". Une clé IAM qui fuit = accès root au compte.
**Pourquoi c'est dangereux :** IAM n'est pas un obstacle — c'est la SEULE chose qui empêche un attaquant (ou un bug) de supprimer toute ton infrastructure. Un `terraform destroy` accidentel avec des droits admin = tout est perdu. Sans IAM strict, le blast radius d'une fuite de credentials est le compte entier.
**Faire plutôt :** politiques IAM minimales. `s3:GetObject` sur CE bucket, pas `s3:*`. `ec2:Describe*` pour le monitoring, pas `ec2:TerminateInstances`. Policies gérées en Terraform, pas dans la console. Revue trimestrielle avec IAM Access Analyzer.

### Tout dans le même compte
**Ce qu'on voit :** dev, staging, prod dans le même compte AWS. Le stagiaire teste un script qui supprime toutes les instances.
**Pourquoi c'est dangereux :** sans isolation de blast radius, un incident en dev peut détruire la production. Les limites de service (1000 instances, 100 DBs) sont partagées. Les coûts sont mélangés — impossible de savoir ce que coûte la prod vs la dev.
**Faire plutôt :** comptes séparés par environnement. AWS Organizations ou GCP Folders. Accès cross-account pour les besoins légitimes, jamais l'inverse.

### Facture = surprise de fin de mois
**Ce qu'on voit :** personne ne regarde les coûts cloud. Un dev lance une instance GPU p3.16xlarge pour tester. Facture x10 à la fin du mois.
**Pourquoi c'est dangereux :** le cloud facture à l'usage, 24/7. Chaque ressource oubliée coûte. Sans monitoring des coûts, tu découvres les problèmes quand la facture arrive — 30 jours trop tard.
**Faire plutôt :** budget alerts à 80% et 100%. Tags de coût obligatoires (project, team, environment). Revue mensuelle. Instances non utilisées automatiquement arrêtées (Dev/Staging la nuit, week-end).

## Patterns
### IAM least privilege
**Quand :** toute ressource cloud.
**Comment :** chaque rôle a `Effect: Allow` uniquement sur les actions et ressources nécessaires. Pas de wildcard `Resource: "*"`. Pas de `Action: "*"`. Utiliser des conditions (IP source, MFA, tags). Partir de zéro et ajouter ce qui est nécessaire, pas l'inverse.

### Multi-AZ
**Quand :** toute charge de production.
**Comment :** déployer sur au moins 2 zones de disponibilité. Load balancer répartit. RDS Multi-AZ (standby dans une autre AZ, failover automatique). Si une AZ tombe, le service continue. Coût : ~2× l'infra, mais l'alternative c'est le downtime.
