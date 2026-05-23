---
paths:
  - "**/*.sql"
  - "**/migrations/**"
  - "**/migration/**"
  - "**/*Schema*"
  - "**/*Model*"
---

## Database Design & SQL

- Chaque table a une primary key (UUID v7 ou bigint, pas de string)
- Colonnes filtrees dans WHERE/JOIN = index obligatoire
- Foreign keys definies avec index sur chaque FK
- Migrations reversibles (up + down) et sans downtime
- Pas de JSON pour tout — colonnes typees, JSONB pour metadata uniquement
- NOT NULL par defaut, nullable justifie
- Pas de logique metier dans la DB (triggers, stored procedures)
- Utiliser EXPLAIN ANALYZE avant de deployer une requete
- Connection pooling configure (min/max)

Pour anti-patterns et patterns detailles, charger `database-design` ou `sql`.
