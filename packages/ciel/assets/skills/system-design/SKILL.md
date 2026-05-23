---
name: system-design
description: "System Design — estimation back-of-envelope, CAP theorem, scalability patterns, load balancing, caching layers. À charger quand on conçoit un nouveau service ou une fonctionnalité majeure."
---

# System Design

**Principe premier :** Le system design n'est pas "choisir les bonnes technologies" — c'est identifier les contraintes et les accepter. Chaque décision d'architecture est un trade-off : consistency vs availability, latence vs throughput, simplicité vs flexibilité. Si tu ne peux pas nommer ce que tu sacrifies, tu n'as pas vraiment designé. La compétence clé n'est pas de connaître les patterns — c'est de savoir estimer (back-of-envelope) pour ne pas résoudre un problème qui n'existe pas.

## Checklist
- [ ] Estimation back-of-envelope faite avant tout choix d'architecture (req/s, stockage, bande passante)
- [ ] Le CAP theorem est arbitré : ce système doit-il être CP ou AP ? Pourquoi ?
- [ ] Chaque couche a une stratégie de scale (vertical, horizontal, ou sharding)
- [ ] Les single points of failure sont identifiés et éliminés (ou assumés avec un plan de recovery)
- [ ] Le caching est placé là où il réduit la latence, pas là où il est facile à implémenter
- [ ] Les opérations lourdes sont async (file d'attente, workers) — l'utilisateur ne bloque pas
- [ ] Le plan de capacity planning existe : à quel seuil on passe au niveau supérieur ?

## Anti-patterns
### Designer pour Google
**Ce qu'on voit :** sharding, event sourcing, CQRS, 12 microservices — pour 100 utilisateurs.
**Pourquoi c'est dangereux :** la complexité que tu construis aujourd'hui est la dette que tu paieras demain. Chaque couche ajoute des points de défaillance. Le design doit correspondre à l'échelle RÉELLE, pas à l'échelle rêvée.
**Faire plutôt :** estimation back-of-envelope. "100 req/s × 50ms = 5 workers suffisent. Une DB avec read replicas tient 10 000 req/s. Pas besoin de sharding avant 100k req/s." Le design évolue avec la charge.

### Single point of failure ignoré
**Ce qu'on voit :** un load balancer, une DB, une région. "On verra quand ça tombera."
**Pourquoi c'est dangereux :** tout tombe. La question n'est pas SI mais QUAND. Un SPOF qui tombe = 100% du service down. Le MTTR est infini jusqu'à ce que quelqu'un le répare manuellement.
**Faire plutôt :** redondance sur chaque couche. Multi-AZ, replicas, failover automatique. Si un composant ne peut pas être redondant, documenter explicitement pourquoi et quel est le plan de recovery.

### Pas d'estimation avant de coder
**Ce qu'on voit :** un endpoint POST créé sans savoir combien de req/s il va prendre. L'équipe code, déploie, ça tient 50 req/s. Les utilisateurs arrivent, ça s'effondre.
**Pourquoi c'est dangereux :** sans estimation, tu navigues sans carte. Le choix d'architecture (monolithe vs microservices, SQL vs NoSQL) dépend des ordres de grandeur. Si tu ne sais pas si c'est 10 ou 10 000 req/s, tu ne peux pas designer.
**Faire plutôt :** estimation en 5 min : req/s attendues × pics, taille de payload × volume de données, latence acceptable. Des ordres de grandeur, pas des prédictions précises. Si les ordres de grandeur changent d'un facteur 10, le design change.

## Patterns
### Back-of-envelope estimation
**Quand :** avant tout choix d'architecture.
**Comment :** 3 calculs. (1) Throughput : req/s ÷ temps de traitement = workers nécessaires. (2) Storage : req/s × taille par req × rétention = volume disque. (3) Network : req/s × taille de réponse = bande passante. Toujours ×10 pour la marge. Si les chiffres sont petits, rester simple.

### Consistent hashing
**Quand :** sharding avec redistribution minimale quand on ajoute/supprime un nœud.
**Comment :** ring de hash. Chaque clé → premier nœud dans le sens horaire. Ajout d'un nœud ne redistribue que les clés voisines (pas tout le keyspace). Utilisé par CDN, caches distribués, partitions DB.

### Backpressure
**Quand :** un producteur est plus rapide que le consommateur.
**Comment :** ne pas accepter plus de travail qu'on peut traiter. Rate limiting à l'entrée. Queue avec capacité max. Refuser explicitement (429/503) plutôt qu'accepter et timeout. La backpressure se propage — si le worker est plein, l'API refuse, le client doit retry avec backoff.
