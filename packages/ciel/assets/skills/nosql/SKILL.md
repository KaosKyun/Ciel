---
name: nosql
description: "NoSQL — MongoDB/DynamoDB/Redis, modeling around access patterns, single-table design, hot partition avoidance. À charger quand on choisit ou utilise du NoSQL."
---

# NoSQL

**Principe premier :** NoSQL n'est pas "SQL sans schéma" — c'est un trade-off fondamental : tu échanges la flexibilité des requêtes (tu ne peux pas tout JOINer) contre la scalabilité horizontale (tu peux sharder). Ce trade-off est le SEUL critère valide pour choisir NoSQL. Si tu n'as pas de problème de scale horizontal que SQL ne résout pas, NoSQL est un downgrade, pas une modernisation. Le modeling NoSQL se fait à l'envers du relationnel : tu pars des requêtes (qu'est-ce que je dois lire en une opération ?) et tu construis le modèle autour.

## Checklist
- [ ] Le choix NoSQL est justifié par le scale horizontal, pas par "c'est plus simple"
- [ ] Le modèle de données est conçu autour des access patterns (et pas l'inverse)
- [ ] La partition key a une haute cardinalité et une distribution uniforme
- [ ] Les index secondaires (GSI) sont justifiés — chaque GSI coûte de l'argent et de la latence
- [ ] La stratégie de dénormalisation est documentée : quelle donnée est dupliquée, où, pourquoi
- [ ] Les TTL sont configurés pour les données temporaires — pas de job de nettoyage manuel

## Anti-patterns
### Modélisation relationnelle dans NoSQL
**Ce qu'on voit :** 12 `$lookup` (MongoDB) pour reproduire un JOIN. 50 `GetItem` séquentiels (DynamoDB) parce que les données sont dans des items séparés.
**Pourquoi c'est dangereux :** NoSQL n'est pas optimisé pour les JOINs. Chaque `$lookup` est un scan coûteux. Chaque `GetItem` est une requête réseau. 50 requêtes séquentielles DynamoDB = 500ms de latence minimum contre 10ms pour un JOIN SQL. Tu paies le prix du NoSQL sans le bénéfice.
**Faire plutôt :** pre-joindre. Si les données sont lues ensemble, elles sont stockées ensemble (single document/item). Le modèle reflète les patterns d'accès — une requête = un read.

### Hot partition / hot key
**Ce qu'on voit :** partition key = `status` avec 90% des items à `status = "active"`. Ou pire, partition key = `tenant_id` et un tenant fait 80% du trafic.
**Pourquoi c'est dangereux :** en NoSQL, les partitions sont l'unité de scale. Une partition chaude = tout le trafic sur un seul shard = throttling (DynamoDB) ou performance dégradée (MongoDB). Le scale horizontal est neutralisé par une mauvaise clé.
**Faire plutôt :** partition key à haute cardinalité et distribution uniforme. `user_id`, `order_id`, pas de `status` ou `type`. Si un tenant est plus gros, sharder par `tenant_id#entity_id` (composite key).

### Redis comme source de vérité
**Ce qu'on voit :** toutes les données métier dans Redis. `FLUSHALL` ou reboot = toutes les données perdues. "Mais j'ai configuré la persistence" — qui n'a jamais été testée.
**Pourquoi c'est dangereux :** Redis est conçu comme un cache/queue/session store en mémoire. La persistence Redis (RDB/AOF) est asynchrone et non garantie. Même avec AOF everysec, tu peux perdre les 2 dernières secondes d'écritures.
**Faire plutôt :** PostgreSQL/MySQL/DynamoDB pour la source de vérité. Redis pour cache, sessions, rate limiting, queues temporaires. Si Redis est flush, l'app dégrade mais ne perd pas de données métier.

## Patterns
### Single-table design (DynamoDB)
**Quand :** plusieurs types d'entités avec des access patterns différents.
**Comment :** une table. PK = `TYPE#id`, SK = `RELATION#id`. Les GSI inversent PK/SK pour les autres patterns. Un user et ses orders sont dans la même table, lus en une query. Pas de JOIN.

### TTL index
**Quand :** données temporaires (sessions, cache, logs éphémères).
**Comment :** champ `expires_at` en epoch seconds + TTL index. La DB supprime automatiquement. Pas de cron job. Pas de nettoyage manuel. Gratuit (DynamoDB) ou quasi-gratuit.
