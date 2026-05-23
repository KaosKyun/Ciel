---
name: ml-engineering
description: "ML Engineering — pipelines ML, feature stores, model serving, drift, MLOps, experiment tracking, evaluation. A charger quand on met en production des modeles ML."
---

# ML Engineering

## Checklist
- [ ] Les donnees sont versionnees (DVC, LakeFS) — pas de "dataset_v3_final.csv"
- [ ] Les experiences sont trackees (MLflow, Weights & Biases) avec hyperparametres
- [ ] Les pipelines sont reproductibles (meme code + meme donnees = meme modele)
- [ ] Le feature store est utilise (pas de logique de feature dupliquee dans chaque modele)
- [ ] Le model serving a un endpoint avec monitoring (latence, throughput, erreurs)
- [ ] La detection de drift est en place (data drift, model drift, concept drift)
- [ ] Les modeles sont versionnes avec promotion (staging → production → canary)
- [ ] Un fallback est defini si le modele est degrade (regle metier, modele plus simple)

## Anti-patterns
### Modele en boite noire
**Ce qu'on voit :** le modele est entraine sur un laptop, copie en production via SCP. Personne ne sait avec quelles donnees ni quels parametres.
**Pourquoi c'est dangereux :** impossible de reproduire le modele. Impossible de debugger une regression. Si le modele est perdu, tout est perdu.
**Faire plutot :** pipeline ML entierement automatise : data ingestion → feature engineering → training → evaluation → deployment. Versionne (DVC). Tracke (MLflow). Reproductible.

### Drigt ignore
**Ce qu'on voit :** le modele est en production depuis 8 mois. Les performances se degradent mais personne ne le mesure.
**Pourquoi c'est dangereux :** le modele prend des decisions de moins en moins bonnes silencieusement. Les utilisateurs sont impactes sans alerte.
**Faire plutot :** monitoring du data drift (distribution des features), du prediction drift (distribution des predictions), et du concept drift (performance vs ground truth). Alerte si seuil depasse. Retraining automatique ou alerte.

### Pas de feature store
**Ce qu'on voit :** chaque equipe reimplemente les memes features (TF-IDF, encodings, embeddings) dans chaque modele.
**Pourquoi c'est dangereux :** les features divergent entre modeles. Les corrections ne sont pas partagees. Le temps de developpement est multiplie.
**Faire plutot :** feature store centralise (Feast, Tecton). Les features sont definies une fois, reutilisables en training et en serving. Point d'acces unique.

## Patterns
### ML Pipeline
**Quand :** tout projet ML en production.
**Comment :** data ingestion → validation → feature engineering → training → evaluation → deployment → monitoring. Orchestre par Kubeflow, Airflow, ou Vertex AI. Chaque etape est reproductible.

### Canary deployment pour modeles
**Quand :** modele en production avec trafic reel.
**Comment :** deployer le nouveau modele a 5% du trafic. Comparer les metriques (AUC, precision) entre old et new. Si new est meilleur → passer a 50% → 100%. Rollback si regression.
