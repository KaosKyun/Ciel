---
name: sql
description: "SQL — EXPLAIN ANALYZE comme discipline, CTE & window functions, requêtes N+1, transactions courtes, connection pooling. À charger quand on écrit ou optimise des requêtes SQL."
---

# SQL

**Principe premier :** Le SQL n'est pas un langage de requête — c'est un langage déclaratif qui décrit CE QUE tu veux, pas COMMENT l'obtenir. Le planificateur de la DB décide du comment. Ton job n'est pas d'écrire "la bonne requête" — c'est d'écrire une requête que le planificateur peut optimiser. La discipline fondamentale est donc : toujours vérifier ce que le planificateur a fait (EXPLAIN ANALYZE). Sans ça, tu codes à l'aveugle. Un index n'existe que si le planificateur l'utilise.

## Checklist
- [ ] EXPLAIN ANALYZE dans la PR pour toute requête non-triviale — pas après la mise en prod
- [ ] Pas de `SELECT *` sauf si tu as VRAIMENT besoin de toutes les colonnes
- [ ] Les JOINs sont vérifiés : chaque condition de JOIN a un index des deux côtés
- [ ] Pas de N+1 — les données liées sont fetchées en une requête (JOIN, IN, ou LATERAL)
- [ ] Les transactions sont aussi courtes que possible — tout le calcul est fait avant le BEGIN
- [ ] Connection pooling : PgBouncer (transaction mode) ou équivalent entre l'app et PostgreSQL

## Anti-patterns
### N+1 queries
**Ce qu'on voit :** `for (const user of users) { orders = await db.query('SELECT * FROM orders WHERE user_id = $1', [user.id]) }`. 100 users = 101 requêtes.
**Pourquoi c'est dangereux :** le N+1 est le tueur silencieux de performance. Chaque requête a une latence réseau (0.5ms en local, 5ms en cloud). 1000 users = 5 secondes juste en overhead réseau. Et le pire : la DB pourrait répondre en 50ms avec un JOIN.
**Faire plutôt :** `SELECT * FROM orders WHERE user_id = ANY($1)` avec un tableau d'IDs. Ou JOIN. Toujours regarder les boucles qui contiennent des requêtes DB — c'est le pattern N+1.

### EXPLAIN jamais fait
**Ce qu'on voit :** la requête est lente en production. On ajoute un index "au pif" sur une colonne qui semblait importante. La requête est toujours lente — l'index n'est pas utilisé.
**Pourquoi c'est dangereux :** sans EXPLAIN ANALYZE, tu ne sais pas ce que la DB fait vraiment. Seq Scan ? Index Scan ? Nested Loop ? Hash Join ? Chaque choix du planificateur a un impact 100-1000× sur la performance. Deviner l'index est du gaspillage.
**Faire plutôt :** `EXPLAIN (ANALYZE, BUFFERS) SELECT ...` → regarder le plan. Seq Scan sur grosse table → index. Nested Loop sur 100K×100K → Hash Join. L'index se met là où le plan montre un goulot, pas là où "ça semble logique".

### Transaction longue
**Ce qu'on voit :** `BEGIN; calculApplicatif(); query1(); appelAPIExterne(); query2(); COMMIT;` L'appel API prend 2 secondes.
**Pourquoi c'est dangereux :** la transaction garde des locks (RowExclusive, ShareLock) pendant toute sa durée. Toutes les modifications concurrentes sur les mêmes rows sont bloquées. 2 secondes de blocage → file d'attente → timeout → erreurs en cascade.
**Faire plutôt :** tout le calcul, les appels API, la validation métier sont faits AVANT le BEGIN. La transaction ne contient QUE les requêtes DB. Durée < 100ms. Si un appel externe est nécessaire au milieu → reconsidérer le design.

## Patterns
### CTE (Common Table Expression)
**Quand :** requête complexe avec des étapes intermédiaires.
**Comment :** `WITH active_users AS (SELECT id FROM users WHERE last_login > now() - interval '30 days'), user_orders AS (SELECT ...) SELECT ... FROM active_users JOIN user_orders ...`. Le CTE nomme chaque étape — bien plus lisible qu'une soupe de sous-requêtes. `MATERIALIZED` ou non selon que le CTE est réutilisé.

### Window functions
**Quand :** classement, cumuls, ou comparaison entre rows sans perdre la granularité.
**Comment :** `ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at)` pour le premier/dernier par groupe. `LAG(price) OVER (PARTITION BY product ORDER BY date)` pour la variation. Pas de self-JOIN coûteux.

### Connection pooling
**Quand :** toute application en production avec PostgreSQL.
**Comment :** PgBouncer en transaction mode. L'app se connecte à PgBouncer (local), PgBouncer multiplexe sur PostgreSQL (peu de connexions). 1000 clients → 20 connexions DB. Évite le fork() par connexion de PostgreSQL.
