---
name: system-design
description: "System Design — estimation back-of-envelope, CAP theorem, trade-offs, scalability patterns, load balancing, caching layers. A charger quand on concoit un nouveau service."
---

# System Design

**Principe premier :** Le system design n'est pas "choisir les bonnes technologies" — c'est identifier les contraintes et les accepter. Chaque decision d'architecture est un trade-off : consistency vs availability, latence vs throughput, simplicite vs flexibilite. Si tu ne peux pas nommer ce que tu sacrifies, tu n'as pas vraiment designe. La competence cle n'est pas de connaitre les patterns — c'est de savoir estimer (back-of-envelope) pour ne pas resoudre un probleme qui n'existe pas.

## Checklist
- [ ] Estimation back-of-envelope faite avant tout choix d'architecture (req/s, stockage, bande passante)
- [ ] Le CAP theorem est arbitre : ce systeme doit-il etre CP ou AP ? Pourquoi ?
- [ ] Chaque couche a une strategie de scale (vertical, horizontal, ou sharding)
- [ ] Les single points of failure sont identifies et elimines (ou assumes avec un plan de recovery)
- [ ] Le caching est place la ou il reduit la latence, pas la ou il est facile a implementer
- [ ] Les operations lourdes sont async (file d'attente, workers) — l'utilisateur ne bloque pas
- [ ] Le plan de capacity planning existe : a quel seuil on passe au niveau superieur ?

## Trade-offs : les 3 choix structurants

### SQL vs NoSQL

| | SQL (PostgreSQL, MySQL) | NoSQL (DynamoDB, MongoDB) |
|--|-------------------------|---------------------------|
| **Modele** | Schema fixe, relations, JOINs | Schema flexible, pas de JOINs |
| **Scale** | Vertical puis read replicas | Horizontal natif (sharding) |
| **Quand choisir** | Relations complexes, transactions ACID, reporting | Acces par cle connu, schema variable, scale horizontal obligatoire |
| **Piege** | Les migrations deviennent le bottleneck | Tu decouvres que t'as besoin de JOINs → impossible |
| **Ne JAMAIS faire** | `SELECT * FROM orders JOIN ... JOIN ... JOIN ...` sur 10M rows | Utiliser NoSQL "au cas ou" sans avoir mesure le besoin de scale |

### Sync vs Async

| | Sync (HTTP/gRPC) | Async (queues/events) |
|--|------------------|----------------------|
| **Consistance** | Immediate (le client sait tout de suite) | Eventuelle (le client sait plus tard) |
| **Couplage** | Le caller attend le callee | Decouple temporellement |
| **Quand choisir** | L'utilisateur attend la reponse | Operation lourde, notification, propagation |
| **Piege** | Le timeout tue tout (si B est lent, A est lent) | Debugging : ou est l'event ? Qui l'a traite ? |

### Monolithe vs Microservices

| | Monolithe | Microservices |
|--|----------|--------------|
| **Deploy** | 1 artefact | N artefacts independants |
| **Scale** | Tout ou rien | Par service (le checkout scale, pas l'auth) |
| **Complexite** | Dans le code (couplage) | Dans le reseau (latence, serialisation, erreurs) |
| **Quand choisir** | Equipe < 20, domaine stable, pas de besoin de scale independant | Equipes autonomes (> 5 equipes), modules qui scalent differemment |
| **Piege** | Le monolithe devient un "big ball of mud" (pas de frontieres internes) | 12 services pour 3 devs : le cout de coordination > benefices |
| **Regle** | Commencer monolithe modulaire. Extraire en service UNIQUEMENT quand la douleur est prouvee. |

## Anti-patterns
### Designer pour Google
**Ce qu'on voit :** sharding, event sourcing, CQRS, 12 microservices — pour 100 utilisateurs.
**Pourquoi c'est dangereux :** la complexite que tu construis aujourd'hui est la dette que tu paieras demain. Chaque couche ajoute des points de defaillance.
**Faire plutot :** estimation back-of-envelope. "100 req/s x 50ms = 5 workers suffisent. Une DB avec read replicas tient 10 000 req/s. Pas besoin de sharding avant 100k req/s." Le design evolue avec la charge.

### Single point of failure ignore
**Ce qu'on voit :** un load balancer, une DB, une region. "On verra quand ca tombera."
**Pourquoi c'est dangereux :** tout tombe. Un SPOF qui tombe = 100% du service down.
**Faire plutot :** redondance sur chaque couche. Multi-AZ, replicas, failover automatique. Si un composant ne peut pas etre redondant, documenter explicitement pourquoi.

### Pas d'estimation avant de coder
**Ce qu'on voit :** un endpoint cree sans savoir combien de req/s il va prendre. En production, ca s'effondre.
**Pourquoi c'est dangereux :** sans estimation, le choix d'architecture est arbitraire. SQL vs NoSQL, sync vs async — ces decisions dependent des ordres de grandeur.
**Faire plutot :** estimation en 5 min : req/s x pics, taille payload x volume, latence acceptable. Des ordres de grandeur. Si les ordres changent d'un facteur 10, le design change.

## Patterns
### Back-of-envelope estimation
**Quand :** avant tout choix d'architecture.
**Comment :** 3 calculs. (1) Throughput : req/s / temps de traitement = workers necessaires. (2) Storage : req/s x taille par req x retention = volume disque. (3) Network : req/s x taille de reponse = bande passante. Toujours x10 pour la marge. Si les chiffres sont petits, rester simple.

**Mise en place :** (1) Lister les endpoints/operations. (2) Estimer les req/s en pic. (3) Multiplier par la taille de payload. (4) Verifier que chaque couche (LB, app, DB, cache) tient ces chiffres. (5) Documenter les seuils de passage a l'echelle superieure (ex: a 1000 req/s → add read replica).

### Consistent hashing
**Quand :** sharding avec redistribution minimale quand on ajoute/supprime un nœud.
**Comment :** ring de hash. Chaque cle → premier nœud dans le sens horaire. Ajout d'un nœud ne redistribue que les cles voisines (pas tout le keyspace).

**Mise en place :** (1) Choisir une fonction de hash (SHA-256, MD5 tronque). (2) Placer les nœuds sur le ring. (3) Pour chaque cle, hash → premier nœud dans le sens horaire. (4) Pour la redondance, chaque cle va sur N nœuds consecutifs (replication). (5) Ajouter/supprimer un nœud ne deplace que ~K/N cles. Utilise par CDN, caches distribues, partitions DB.

### Backpressure
**Quand :** un producteur est plus rapide que le consommateur.
**Comment :** refuser explicitement (429/503) plutot qu'accepter et timeout. Rate limiting a l'entree. Queue avec capacite max.

**Mise en place :** (1) Definir la capacite max (ex: 1000 requetes concurrentes). (2) Rate limiter a l'entree (token bucket, sliding window). (3) Queue bornee (taille max, pas infinie). (4) Si file pleine → 429. (5) Le client retry avec exponential backoff + jitter. La backpressure se propage — si le worker est plein, l'API refuse, le client ralentit.

### Cache layers (ou placer le cache)
**Quand :** latence a reduire sur un chemin critique.
**Comment :** cache navigateur (Cache-Control headers) → CDN (edge cache) → cache applicatif (Redis) → DB. Chaque couche reduit la latence et la charge sur la couche suivante.
- **Avantages :** reduction drastique de la latence (DB: 10ms, Redis: 1ms, CDN: 0ms pour le client)
- **Desavantages :** stale data, invalidation complexe, memoire = cout
- **Mise en place :** (1) Identifier la hot path. (2) Mesurer la latence actuelle par couche. (3) Ajouter le cache le plus proche du client d'abord (CDN > Redis > local). (4) Definir TTL = fraicheur acceptable. (5) Monitorer hit rate > 80%.
