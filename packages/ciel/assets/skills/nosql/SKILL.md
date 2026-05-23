---
name: nosql
description: "NoSQL — MongoDB/DynamoDB/Redis, document vs KV vs graph vs time-series, single-table design. A charger quand on choisit ou utilise du NoSQL."
triggers:
  path: "**/dynamo*,**/mongo*,**/redis*"
---

# NoSQL

## Checklist
- [ ] Le choix NoSQL est justifie par le pattern d'acces, pas par "c'est plus simple"
- [ ] Le modele de donnees est concu autour des requetes (et pas l'inverse)
- [ ] Les cles de partition/sharding evitent les hot partitions
- [ ] Les index secondaires sont limites (cout $ et perf)
- [ ] La strategie de denormalisation est documentee (quelle donnee est dupliquee, ou, pourquoi)
- [ ] Les TTL sont configures pour les donnees temporaires (sessions, cache)

## Anti-patterns
### Modelisation relationnelle dans NoSQL
**Ce qu'on voit :** 12 `$lookup` (MongoDB) pour reproduire un JOIN. 50 `getItem` sequentiels (DynamoDB).
**Pourquoi c'est dangereux :** les performances sont pires qu'une DB relationnelle. Le cout est 50× plus eleve (DynamoDB facture par requete).
**Faire plutot :** denormaliser. Si les donnees sont lues ensemble, elles sont stockees ensemble. Le modele reflete les patterns d'acces.

### Hot partition
**Ce qu'on voit :** partition key = `status` avec 90% des items `status = "active"`.
**Pourquoi c'est dangereux :** une seule partition recoit 90% du trafic. Throttling. Les autres partitions sont vides.
**Faire plutot :** partition key a haute cardinalite (user_id, order_id). Sharding uniforme.

### Redis comme DB principale
**Ce qu'on voit :** toutes les donnees dans Redis. Pas de persistance configuree.
**Pourquoi c'est dangereux :** reboot = toutes les donnees perdues. Redis est un cache, pas une source de verite.
**Faire plutot :** Redis pour cache, sessions, rate limiting, queues. PostgreSQL/MySQL pour la source de verite.

## Patterns
### Single-table design (DynamoDB)
**Quand :** plusieurs types d'entites avec des patterns d'acces differents.
**Comment :** une seule table. PK = entity_type#id, SK = relation_type#id. Les index secondaires (GSI) inversent PK/SK pour d'autres patterns d'acces.

### TTL index
**Quand :** donnees temporaires (sessions, logs, cache).
**Comment :** champ `expires_at` en epoch seconds + TTL index. La DB supprime automatiquement. Pas de job de nettoyage.

### Embedded documents (MongoDB)
**Quand :** donnees toujours lues ensemble et rarement modifiees independamment.
**Comment :** `{order: {items: [{product, qty}], shipping: {address, method}}}`. Un seul read pour toute la commande. Pas de JOIN.
