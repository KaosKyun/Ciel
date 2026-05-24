---
name: data-engineering
description: "Data Engineering — pipelines ETL/ELT, Spark/Airflow/dbt, data warehouses, streaming vs batch, qualite des donnees. A charger quand on construit des pipelines de donnees."
---

# Data Engineering

**Principe premier :** Le data engineering n'est pas "deplacer des donnees de A a B" — c'est garantir que les bonnes donnees arrivent au bon moment avec la bonne qualite. La donnee est un passif jusqu'a ce qu'elle soit utilisable — un pipeline qui livre des donnees corrompues ou tardives est pire que pas de pipeline du tout (les decisions sont prises sur des donnees fausses). Le vrai defi n'est pas le volume (tout le monde peut scaler) — c'est la qualite, la fraicheur, et la gouvernance. Un pipeline doit etre idempotent (re-run = meme resultat), observable (chaque etape logue ce qu'elle a fait), et testable (tu peux verifier la sortie sans la comparer a elle-meme).

## Checklist
- [ ] Le pipeline est idempotent : re-run = meme resultat, pas de doublons, pas d'effet cumulatif
- [ ] Les donnees sont validees a l'ingestion (schema, types, contraintes) — pas de "on verifiera plus tard"
- [ ] Le lineage est documente (d'ou viennent ces donnees ? quelles transformations ?) — pas de mystere
- [ ] Les PII sont anonymisees/scrubbees avant d'entrer dans le warehouse (pas dans les requetes)
- [ ] Les incremental loads utilisent des watermarks fiables (pas `MAX(updated_at)` sur une table sans index)
- [ ] Le monitoring couvre : fraicheur (age des donnees), volume (trop/pas assez), qualite (% de nulls)
- [ ] Les backfills sont testees et reversibles — un backfill qui casse la production est un incident

## Anti-patterns
### Pipeline fragile aux changements de schema
**Ce qu'on voit :** le pipeline fait `SELECT *` et insere dans une table cible. La source ajoute une colonne → le pipeline casse. La source supprime une colonne → le pipeline casse.
**Pourquoi c'est dangereux :** les schemas evoluent, c'est normal. Un pipeline qui casse a chaque changement de schema est un pipeline qui passe plus de temps en panne qu'en production. Chaque panne = donnees manquantes = decisions sur des donnees incompletes.
**Faire plutot :** definir un contrat de schema (schema registry, Avro, Protobuf). Evolution compatible : ajouter des colonnes optionnelles, jamais supprimer sans migration. Le pipeline lit les colonnes explicitement, pas `SELECT *`. Tests d'evolution de schema dans la CI.

### "On nettoiera les donnees plus tard"
**Ce qu'on voit :** ingestion brute de tout. "On fera la qualite dans le data warehouse." 6 mois plus tard : 500 To de donnees, 40% de valeurs nulles, colonnes inutilisables.
**Pourquoi c'est dangereux :** la qualite des donnees se degrade avec le temps — chaque transformation ajoute une couche d'interpretation. Plus tu attends pour nettoyer, plus c'est dur et cher. Le data warehouse devient un data swamp.
**Faire plutot :** validation a l'ingestion (schema, types, contraintes metier). Rejeter les donnees invalides dans une dead letter queue, pas dans le warehouse. Les donnees propres sont plus petites, plus rapides, plus utiles.

### Pipeline = boite noire
**Ce qu'on voit :** le pipeline tourne dans Airflow/Dagster. Pas de logs structures. "Le DAG a echoue" — aucun diagnostic possible sans regarder le code.
**Pourquoi c'est dangereux :** sans observabilite, chaque echec est une enquete policiere. Les pipelines sont des programmes distribues — ils echouent pour 50 raisons differentes. Sans logs structures (combien de rows traitees, combien de temps par etape, quelles valeurs aberrantes), le MTTR est de l'ordre de l'heure.
**Faire plutot :** chaque etape logue : nombre de records traites, duree, nombre d'erreurs/valides, watermark utilise. Dashboards de sante par pipeline. Alertes sur deviation (moins de donnees que d'habitude = probleme upstream).

## Patterns
### Medaillon architecture (Bronze/Silver/Gold)
**Quand :** data lake ou data warehouse avec plusieurs consommateurs.
**Comment :** Bronze = donnees brutes (ingestion, append-only, schema preserve). Silver = donnees nettoyees, deduplicatees, jointes. Gold = donnees metier agreggees, pretes pour la consommation. Chaque couche a un proprietaire et un SLA de fraicheur.

### Watermark incremental
**Quand :** pipeline qui traite des donnees par lots incrementaux.
**Comment :** utiliser une colonne de watermark monotone (`updated_at`, `event_time`, `sequence_id`). Stocker le watermark precedent. Charger `WHERE updated_at > last_watermark`. Gerer les late arrivals avec une fenetre de tolerance (ex: recharger les 2 dernieres heures en plus du delta).
