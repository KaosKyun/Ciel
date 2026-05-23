---
name: sql
description: "SQL — CTE, window functions, EXPLAIN ANALYZE, locking, connection pooling. A charger des qu'on ecrit ou optimise des requetes SQL."
---

# SQL

## Checklist
- [ ] Chaque requete non-triviale a un EXPLAIN ANALYZE dans la PR
- [ ] Pas de `SELECT *` — lister les colonnes explicitement
- [ ] Les JOINs utilisent des index (verifier avec EXPLAIN)
- [ ] Les sous-requetes sont remplacees par des CTE ou JOINs quand possible
- [ ] Pas de N+1 — les donnees liees sont fetchees en une requete (JOIN ou IN)
- [ ] Les transactions sont aussi courtes que possible
- [ ] Le connection pooling est configure (PgBouncer, pg-pool)

## Anti-patterns
### N+1 queries
**Ce qu'on voit :** `for (const user of users) { const orders = await db.query('SELECT * FROM orders WHERE user_id = $1', [user.id]) }`.
**Pourquoi c'est dangereux :** 100 users = 101 requetes au lieu de 1. 100× plus lent.
**Faire plutot :** `SELECT * FROM orders WHERE user_id IN (SELECT id FROM users WHERE ...)` ou JOIN.

### Pas de EXPLAIN
**Ce qu'on voit :** la requete est lente, personne ne sait pourquoi. On ajoute un index au hasard.
**Pourquoi c'est dangereux :** l'index choisi n'est pas utilise. La requete reste lente. L'espace disque est gaspille.
**Faire plutot :** `EXPLAIN ANALYZE SELECT ...` → regarder le plan : seq scan ? nested loop ? hash join ? Indexer la ou le plan montre un bottleneck.

### Transaction ouverte longue
**Ce qu'on voit :** `BEGIN; ... (calcul en JS pendant 2 secondes) ... COMMIT;`.
**Pourquoi c'est dangereux :** la transaction garde des locks. Toutes les autres transactions attendent. Deadlock potentiel.
**Faire plutot :** tout le calcul est fait avant le BEGIN. La transaction ne contient que les requetes DB. Durée < 100ms.

## Patterns
### CTE (Common Table Expression)
**Quand :** requete complexe avec des etapes intermediaires.
**Comment :** `WITH active_users AS (SELECT ...), user_orders AS (SELECT ...) SELECT ... FROM active_users JOIN user_orders ...`. Plus lisible que les sous-requetes imbriquees.

### Window functions
**Quand :** classement, cumuls, comparaison entre rows sans GROUP BY.
**Comment :** `ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at)` pour le premier/dernier par groupe. `LAG(price) OVER (...)` pour comparer avec la row precedente.

### Connection pooling
**Quand :** toute app en production avec PostgreSQL.
**Comment :** PgBouncer en transaction mode entre l'app et PostgreSQL. L'app ouvre des connexions au pooler, le pooler multiplexe sur PostgreSQL. 1000 clients app → 20 connexions DB.
