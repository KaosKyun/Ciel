---
paths:
  - "**/*.sql"
  - "**/migrations/**"
  - "**/*repository*"
  - "**/*Repository*"
  - "**/*repositories*"
  - "**/*Repositories*"
  - "**/queries/**"
---

## Dispatch
- Charge `sql` AVANT d'ecrire ou d'optimiser une requete.
- Si la requete touche un gros volume → charge aussi `performance`.
- Si c'est une migration de schema → charge aussi `database-design`.

## Regles dures (zero tolerance)
- **Jamais** de concatenation de string dans une requete (injection SQL). Requetes parametrees uniquement.
- **Jamais** de `SELECT *` — liste les colonnes necessaires.
- **Jamais** de migration destructive (DROP/ALTER) en prod sans plan de rollback ni strategie expand/contract.
- **Toujours** un `EXPLAIN ANALYZE` dans la PR pour une requete non-triviale — pas apres la prod.

## Conventions du projet
- Transactions courtes : pas de logique applicative ni d'appel reseau dans une transaction ouverte.
- Index sur les colonnes de JOIN et de WHERE frequents ; un index n'existe que si le planificateur l'utilise.
- Pagination cursor-based (keyset), pas `OFFSET` sur les grosses tables.
- N+1 detecte par les tests, jamais decouvert en prod.
