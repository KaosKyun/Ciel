---
name: system-design
description: "System Design — scalabilite, CAP theorem, partitionnement, load balancing, estimation back-of-envelope. A charger des qu'on conçoit un nouveau service ou une fonctionnalite majeure."
---

# System Design

## Checklist
- [ ] Estimation back-of-envelope faite (req/s, stockage, bande passante)
- [ ] Goulets d'etranglement identifies (DB, CPU, reseau, memoire)
- [ ] Strategie de partitionnement definie (sharding key, consistent hashing)
- [ ] Redondance prevue (pas de single point of failure)
- [ ] CAP theorem arbitre (CP ou AP pour ce use case ?)
- [ ] Cache layers identifies (ou et quel TTL ?)
- [ ] Async processing pour les operations lourdes (file d'attente, workers)
- [ ] Plan de montee en charge (verticale, horizontale, ou les deux ?)

## Anti-patterns
### Pas d'estimation avant de coder
**Ce qu'on voit :** endpoint POST cree sans savoir combien de req/s il va recevoir.
**Pourquoi c'est dangereux :** l'endpoint s'effondre a 100 req/s en production avec 10k utilisateurs.
**Faire plutot :** estimation back-of-envelope : "1000 req/s × 100ms de traitement = 100 workers minimum."

### Single point of failure ignore
**Ce qu'on voit :** un seul serveur, une seule DB, une seule region. Le load balancer est un SPOF.
**Pourquoi c'est dangereux :** panne = 100% du service down. Pas de comeback automatique.
**Faire plutot :** redondance sur chaque couche — multi-AZ, replicas, load balancer en HA.

### Optimisation prematuree
**Ce qu'on voit :** sharding implemente avant le premier utilisateur. Microservices pour 3 endpoints.
**Pourquoi c'est dangereux :** complexite enorme pour une charge qui n'existe pas. Temps perdu.
**Faire plutot :** monolithe modulaire. Sharding quand la DB approche ses limites (mesure, pas supposition).

## Patterns
### Back-of-envelope estimation
**Quand :** au debut de chaque nouveau service ou fonctionnalite majeure.
**Comment :** ~ req/s ÷ temps de traitement × workers. Stockage = req/s × taille × retention. Toujours ×10 pour la marge.

### Consistent hashing
**Quand :** sharding de donnees avec redistribution minimale au changement de nombre de nœuds.
**Comment :** ring de hash, chaque cle → premier nœud dans le sens horaire. Ajout/suppression d'un nœud ne re-distribue que les cles voisines.

### CQRS lite
**Quand :** les lectures sont 100× plus frequentes que les ecritures.
**Comment :** separer le modele de lecture (optimise SELECT) et d'ecriture (optimise INSERT). Pas besoin d'event sourcing complet pour commencer.
