---
name: data-engineering
description: "Data Engineering — ETL/ELT, pipelines (Spark/Airflow/dbt), data warehouses, streaming vs batch. A charger quand on construit des pipelines de donnees."
---

# Data Engineering

## Checklist
- [ ] Le pipeline est idempotent (re-run = meme resultat)
- [ ] Les donnees sont anonymisees avant d'entrer dans le warehouse (PII scrub)
- [ ] Le monitoring est en place (duree du job, rows traitees, erreurs)
- [ ] Les jobs sont parametres (date, batch size) — pas de valeurs hardcodees
- [ ] Les donnees sources ne sont jamais modifiees (read-only, le pipeline lit une copie ou un replica)
- [ ] Le schema est versionne (schema evolution = nouvelle colonne, pas modification)

## Anti-patterns
### Pipeline non-idempotent
**Ce qu'on voit :** `INSERT INTO warehouse.orders SELECT * FROM prod.orders WHERE created_at > last_run`. Si le job est relance, les rows de la fenetre precedente sont dupliquees.
**Pourquoi c'est dangereux :** doublons. Les rapports sont faux. Le CEO prend des decisions sur des chiffres en double.
**Faire plutot :** utiliser `MERGE` ou `INSERT ON CONFLICT` avec une cle de deduplication. Ou partitionner par date et overwrite la partition.

### PII dans le warehouse
**Ce qu'on voit :** copie brute de la table users (email, phone, adresse) dans le data warehouse sans anonymisation.
**Pourquoi c'est dangereux :** le data warehouse est accessible par les analystes. Violation RGPD. En cas de leak, fuite massive.
**Faire plutot :** hash/hash-salt pour les champs identifiants. Supprimer les champs non necessaires. Tokenization pour les besoins de jointure.

### Script cron sans monitoring
**Ce qu'on voit :** un script bash lance par cron. Pas d'alerte s'il echoue. Silence pendant 3 semaines.
**Pourquoi c'est dangereux :** le rapport est vide. Personne ne le sait. Decision business sur des donnees perimees.
**Faire plutot :** orchestrateur (Airflow, Prefect, Dagster). Chaque job a un SLA. Alerte si le job ne termine pas dans le delai.

## Patterns
### ELT (Extract, Load, Transform)
**Quand :** le volume est assez gros pour que la transformation soit couteuse.
**Comment :** extraire les donnees brutes → les charger dans le warehouse → transformer avec dbt ou SQL. La transformation est versionnee et testable.

### Partitionnement par date
**Quand :** les requetes filtrent toujours par date.
**Comment :** `PARTITION BY RANGE (created_at)`. Chaque partition = un jour. Les vieilles partitions peuvent etre compressees ou archivees.
