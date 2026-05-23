---
name: iac
description: "IaC — l'infrastructure comme code, pas comme clics. State management, drift detection, modules, immutabilite. A charger quand on definit ou modifie l'infrastructure."
---

# Infrastructure as Code

**Principe premier :** L'infrastructure n'est pas une liste de ressources a creer — c'est un programme dont le state est la verite. La console est un outil de debugging, pas de gestion. Chaque clic est une dette qui sera oubliee et qui cassera au pire moment. Le vrai benefice de l'IaC n'est pas la vitesse de creation (la console est plus rapide pour 1 instance) — c'est la repetabilite : meme code → meme infra, dans 6 mois, par un autre humain, sans surprise. Le state file est ton inventaire physique — si tu le perds, tu reconstruis ou tu importes, mais tu ne devines pas.

## Checklist
- [ ] Toute l'infrastructure est dans le code — zero ressource creee a la main (verifie avec drift detection)
- [ ] Le state est stocke dans un backend securise (S3 + DynamoDB lock, Terraform Cloud, Pulumi SaaS) — jamais en local
- [ ] Les modules sont versionnes (tag git, pas `source = "../common"`)
- [ ] Les ressources sont immutables — on remplace, on ne modifie pas en place
- [ ] Les secrets sont referencees depuis un secret manager, pas en clair dans le code
- [ ] Le plan est toujours sauvegarde (`terraform plan -out=plan.out`) et applique depuis le meme fichier
- [ ] Drift detection tourne regulierement (hebdomadaire ou dans la CI) — alerter si ecart

## Anti-patterns
### Console comme outil principal
**Ce qu'on voit :** l'equipe cree les ressources a la main "parce que c'est plus rapide". 6 mois plus tard, 200 ressources non trackees, configuration inconnue.
**Pourquoi c'est dangereux :** la console ne laisse pas de trace. Pas de review possible. Pas de rollback. Impossible de reproduire l'environnement. Le disaster recovery devient un puzzle.
**Faire plutot :** toute ressource est definie dans le code. Si une ressource existe deja, l'importer (`terraform import`) puis la gerer en code. La console est en read-only.

### State local
**Ce qu'on voit :** `terraform.tfstate` dans le repo ou sur le laptop du dev. "C'est bon, je l'ai en local."
**Pourquoi c'est dangereux :** le laptop meurt, le state est perdu. Deux devs appliquent en parallele → corruption. Le state contient des donnees sensibles (passwords, private keys) → fuite.
**Faire plutot :** backend distant avec locking (S3 + DynamoDB). Chaque `apply` verifie le lock. Le state est chiffre. Les secrets sont marques `sensitive` dans le code, pas extraits du state.

### Module monolithe
**Ce qu'on voit :** un seul module `main.tf` de 2000 lignes qui gere tout : reseau, compute, DB, DNS, IAM. Chaque changement fait peur.
**Pourquoi c'est dangereux :** blast radius maximal. Un changement de DNS peut detruire la DB si le state est corrompu. La revue est impossible. Le `terraform plan` prend 10 minutes.
**Faire plutot :** infrastructure decomposee en modules independants. Reseau dans un state, compute dans un autre, DB dans un autre. Chaque module a son propre cycle de vie. Les dependances sont explicites (data sources, remote state).

## Patterns
### Immutabilite
**Quand :** toute ressource modifiable (instances, conteneurs, lambdas).
**Comment :** `create_before_destroy = true`. On cree la nouvelle ressource, on valide, puis on detruit l'ancienne. Pas de modification en place. Le code est la verite — si le code change, la ressource est remplacee.

### Drift detection
**Quand :** toute equipe de plus d'une personne.
**Comment :** `terraform plan -detailed-exitcode` ou `pulumi refresh --diff` dans la CI chaque semaine. Si drift → ticket automatique. Corriger la cause (console ? script maison ?) pas juste l'effet.

### GitOps
**Quand :** deploiement continu de l'infrastructure.
**Comment :** le repo git est la source de verite. Un merge sur main declenche le plan, puis l'apply. Pas de `terraform apply` depuis un laptop. Le pipeline a les permissions IAM minimales (OIDC).
