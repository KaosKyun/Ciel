---
paths:
  - "**/*.sql"
  - "**/migrations/**"
  - "**/schema/**"
  - "**/*repository*"
  - "**/*Repository*"
  - "**/*repositories*"
  - "**/*Repositories*"
  - "**/*Database*"
---

## Dispatch
- Charge `database-design` AVANT d'ecrire du SQL ou de modifier un schema.
- Si la migration touche une table > 1M rows → charge aussi `resilience`.

## Regles dures (zero tolerance)
- **Jamais** de `ALTER TABLE` direct sur une grosse table en une etape. Expand/Contract : add column → backfill → add constraint.
- **Jamais** de FK sans index. Verifiable automatiquement.
- **Jamais** de logique metier dans la DB (triggers, stored procedures).

## Conventions du projet
- UUID v7 si distribue, bigint si centralise.
- Migrations reversibles (up + down) testees en rollback dans la CI.
- Colonnes NOT NULL par defaut — nullable est l'exception, justifiee.
