---
paths:
  - "**/*dynamo*"
  - "**/*mongo*"
  - "**/*redis*"
  - "**/*.nosql.*"
---

## Dispatch
- Charge `nosql` AVANT de modeliser ou requeter une base NoSQL.
- Si Redis sert de cache → charge aussi `caching`.

## Regles dures (zero tolerance)
- **Jamais** Redis comme source de verite — persistence asynchrone non garantie. Redis = cache/sessions/queues ; la verite reste en DB durable.
- **Jamais** de partition key a faible cardinalite (`status`, `type`) — hot partition = throttling. Haute cardinalite, distribution uniforme (`user_id`, composite `tenant#id`).
- **Jamais** reproduire des JOINs (`$lookup` en cascade, `GetItem` sequentiels) — modeliser autour des access patterns, pre-joindre.

## Conventions du projet
- Le modele de donnees suit les access patterns, pas l'inverse. Une requete = un read.
- Chaque GSI / index secondaire est justifie (coute argent + latence).
- TTL pour les donnees temporaires — pas de cron de nettoyage manuel.
- Strategie de denormalisation documentee : quelle donnee est dupliquee, ou, pourquoi.
