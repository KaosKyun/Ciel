---
name: database-design
description: "Database Design — modelisation, normalisation, indexation, migrations sans downtime. A charger des qu'on cree ou modifie un schema de base de donnees."
triggers:
  path: "**/*.sql,**/migrations/**,**/prisma/**"
---

# Database Design

## Checklist
- [ ] Le schema est en 3NF (3eme forme normale) sauf raison explicite de denormaliser
- [ ] Chaque table a une primary key (UUID ou bigint, pas de string)
- [ ] Les colonnes filtrees dans WHERE/JOIN ont un index
- [ ] Les foreign keys sont definies (integrite referentielle)
- [ ] Les migrations sont reversibles (up + down)
- [ ] Les migrations sont sans downtime (pas de lock longue duree sur grosse table)
- [ ] Les colonnes nullable sont justifiees (NOT NULL par defaut)
- [ ] Pas de logique metier dans la DB (triggers, stored procedures → application)

## Anti-patterns
### JSON pour tout
**Ce qu'on voit :** `data JSONB NOT NULL` — toute la donnee metier dans une colonne JSON.
**Pourquoi c'est dangereux :** pas de typage, pas d'index, pas de contrainte. "Flexible" devient "inconnu". Impossible de faire un rapport.
**Faire plutot :** colonnes typees pour les champs connus. JSONB uniquement pour les donnees vraiment variables (metadata, preferences, config).

### Migration bloquante
**Ce qu'on voit :** `ALTER TABLE orders ADD COLUMN status VARCHAR NOT NULL DEFAULT 'pending'` sur 10M rows.
**Pourquoi c'est dangereux :** la table est lockee pendant des minutes ou des heures. Tout le service est down.
**Faire plutot :** (1) ADD COLUMN sans NOT NULL, (2) remplir par batches, (3) ajouter NOT NULL. Ou utiliser des outils comme `gh-ost` / `pt-online-schema-change`.

### Pas d'index sur les foreign keys
**Ce qu'on voit :** `order_items.order_id` reference `orders.id` mais n'a pas d'index.
**Pourquoi c'est dangereux :** chaque DELETE sur orders fait un full scan de order_items. Deadlocks en cascade.
**Faire plutot :** index sur chaque foreign key. Regle : si une colonne est dans un ON DELETE/UPDATE, elle doit avoir un index.

## Patterns
### Migration en 3 etapes
**Quand :** modification de schema sur une table > 1M rows.
**Comment :** (1) ajouter sans contrainte (2) remplir les donnees par lots (3) ajouter la contrainte. Chaque etape est une migration separee, reversible independamment.

### Index partiel
**Quand :** une requete filtre sur une condition specifique ET une petite fraction des rows.
**Comment :** `CREATE INDEX idx_active_orders ON orders (created_at) WHERE status = 'active'`. Plus petit, plus rapide.

### UUID v7 pour primary key
**Quand :** besoin d'IDs uniques sanssequence centrale ET triables chronologiquement.
**Comment :** UUID v7 (timestamp-ordered). Evite le index fragmentation de UUID v4 tout en gardant la decentralisation.
