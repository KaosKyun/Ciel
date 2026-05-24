---
name: database-design
description: "Database Design — le schema comme contrat, normalisation, indexation, migrations sans downtime, UUID vs bigint. À charger quand on crée ou modifie un schéma de base de données."
---

# Database Design

**Principe premier :** Le schéma de base de données est le contrat le plus coûteux à modifier dans une application. Changer du code = redéployer (minutes). Changer un schéma avec 50M rows = migration potentiellement bloquante (heures ou jours). Le design de schéma est donc un exercice d'anticipation : tout ce qui est facile à changer plus tard peut être décidé plus tard ; tout ce qui est dur à changer doit être décidé maintenant. La normalisation n'est pas un dogme — c'est un défaut qui minimise la redondance. Dénormaliser doit être un choix explicite, pas un accident.

## Checklist
- [ ] Le schéma est en 3NF sauf raison explicite de dénormaliser (documentée)
- [ ] Chaque table a une primary key — UUID v7 si distribué, bigint si centralisé
- [ ] Les foreign keys sont définies ET indexées (intégrité + performance)
- [ ] Les colonnes sont NOT NULL par défaut — nullable est l'exception, justifiée
- [ ] Les migrations sont réversibles (up + down) et testées en rollback dans la CI
- [ ] Les migrations sur grosses tables (> 1M rows) utilisent une stratégie sans lock (expand/contract ou gh-ost)
- [ ] Pas de logique métier dans la DB — triggers et stored procedures = application

## Anti-patterns
### JSON pour tout
**Ce qu'on voit :** `data JSONB NOT NULL` — nom, email, adresse, commandes, tout dans une colonne JSON. "C'est flexible".
**Pourquoi c'est dangereux :** pas de typage, pas de contrainte, pas d'index utilisable. "Flexible" veut dire "le contrat n'existe pas". Impossible de faire un rapport sans parser toute la table. La DB devient un dump de documents sans structure.
**Faire plutôt :** colonnes typées pour tout champ connu et requêté. JSONB réservé aux données vraiment variables (metadata, preferences, config). La structure est le produit — ne pas y renoncer pour de la flexibilité.

### Migration = ALTER TABLE direct
**Ce qu'on voit :** `ALTER TABLE orders ADD COLUMN status VARCHAR NOT NULL DEFAULT 'pending'` lancé sur une table de 10M rows à 14h en production.
**Pourquoi c'est dangereux :** PostgreSQL locke la table entière pendant l'ALTER. Pour 10M rows, ça peut prendre 20 minutes. Tout le service est down — commandes, paiements, expéditions. La migration en une étape est la cause #1 des outages de DB.
**Faire plutôt :** expand/contract en 3 étapes : (1) ADD COLUMN sans NOT NULL (instantané), (2) remplir par batches de 1000 rows avec des pauses, (3) ajouter NOT NULL après que toutes les rows ont une valeur. Chaque étape est une migration séparée, déployable et rollbackable indépendamment.

### Index manquant sur FK
**Ce qu'on voit :** `order_items.order_id REFERENCES orders(id)` sans index sur `order_id`. Un DELETE sur orders déclenche un seq scan de order_items.
**Pourquoi c'est dangereux :** chaque DELETE/UPDATE cascadé parcourt toute la table enfant. Sur 10M de order_items, un DELETE d'une commande prend 30 secondes au lieu de 1ms. Deadlocks en cascade.
**Faire plutôt :** règle mécanique : toute foreign key a un index. C'est vérifiable automatiquement (pghero, linter SQL). Pas d'exception.

## Patterns
### Expand/Contract (migration sans downtime)
**Quand :** toute modification de schéma sur une table > 100K rows en production.
**Comment :** Phase expand : ajouter (colonnes, tables) sans rien supprimer — l'ancien code continue de fonctionner. Phase migrate : backfill par batches. Phase contract : supprimer l'ancien après validation que tout le nouveau code est déployé. Minimum 2 PRs séparées.

### UUID v7 pour PK distribuée
**Quand :** besoin d'IDs uniques sans séquence centrale, triables chronologiquement.
**Comment :** UUID v7 = timestamp (48 bits) + random (74 bits). Chronologiquement triable (contrairement à UUID v4), pas de fragmentation d'index B-tree. Généré côté application, pas de round-trip DB pour l'ID.

### Index partiel
**Quand :** une requête filtre sur une condition qui ne concerne qu'une petite fraction des rows.
**Comment :** `CREATE INDEX idx_active ON orders (created_at) WHERE status = 'active'`. L'index est plus petit, plus rapide à scanner, plus rapide à mettre à jour. Ne pas indexer ce qui n'est jamais cherché.
