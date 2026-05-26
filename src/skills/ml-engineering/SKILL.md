---
name: ml-engineering
description: "ML Engineering — pipelines ML, feature stores, model serving, drift detection, MLOps, experiment tracking. A charger quand on met en production des modeles ML."
---

# ML Engineering

**Principe premier :** Le ML engineering n'est pas "entrainer un modele avec le meilleur score" — c'est mettre un modele en production et garantir qu'il reste performant dans le temps. La metrique qui compte n'est pas l'accuracy sur le dataset de test (qui est un instantane du passe) — c'est la performance en production sur les donnees de demain. Un modele est un programme qui se degrade passivement : le monde change, les distributions derivent, et un modele a 98% de precision aujourd'hui peut tomber a 72% dans 6 mois sans que personne ne le sache. La difference entre un notebook Jupyter et un systeme ML de production, c'est le monitoring, le versioning, et la capacite a re-entrainer.

## Checklist
- [ ] Les donnees sont versionnees (DVC, LakeFS, Delta Lake) — pas de `dataset_v3_final_FINAL.csv`
- [ ] Les experiences sont trackees (MLflow, W&B, ClearML) avec hyperparametres, code version, dataset version
- [ ] Le feature store est la source unique de verite pour les features — pas de features calculees differemment en train et en inference
- [ ] Le serving est monitorise : latence P95, taux d'erreur, distribution des predictions
- [ ] Le data drift ET le concept drift sont monitorises — alerter quand la distribution change
- [ ] Le pipeline d'entrainement est reproductible (DAG, conteneurise, versionne)
- [ ] Le rollback de modele est aussi simple que le rollback de code (model registry avec versioning)

## Anti-patterns
### Notebook → production
**Ce qu'on voit :** le data scientist donne son notebook "il marche sur mon laptop". L'ingenieur le copie-colle dans un endpoint. 2000 lignes de code non structure.
**Pourquoi c'est dangereux :** un notebook n'est pas un programme — c'est un journal d'exploration. Pas de gestion d'erreur, pas de typage, pas de tests, pas de reproductibilite (execution ordonnee non garantie). Les imports sont eparpilles, les variables persistent entre cellules, le code est impossible a maintenir.
**Faire plutot :** le notebook est un outil d'exploration. Le code de production est dans des modules Python standards, versionnes, testes. Le data scientist et le ML engineer travaillent ensemble sur la transition notebook → module. Le notebook documente l'intention, le module implemente la production.

### Features train/serve inconsistantes
**Ce qu'on voit :** les features sont calculees en Python (pandas) pour l'entrainement, et en Go/Java dans le serving. Implementation differente → comportement different → modele qui performe mal en production sans raison apparente.
**Pourquoi c'est dangereux :** c'est le bug le plus pernicieux en ML. Les metriques d'entrainement sont bonnes, les tests passent, mais le modele est mauvais en production. La cause est quasi impossible a debugger sans comparer les implementations feature par feature.
**Faire plutot :** feature store central. Les memes features, calculees par le meme code, servent l'entrainement ET l'inference. Si le calcul change, le feature store versionne. Zero implementation divergente.

### Drift = surprise
**Ce qu'on voit :** pas de monitoring du drift. Le modele se degrade lentement. 6 mois plus tard, un utilisateur remarque que les predictions sont mauvaises.
**Pourquoi c'est dangereux :** la degradation est silencieuse et graduelle. Le modele ne crash pas — il devient juste de plus en plus mauvais. Les decisions basees sur ces predictions deviennent de plus en plus mauvaises. Le MTTD (mean time to detect) est de 6 mois.
**Faire plutot :** monitoring continu de la distribution des features en production vs distribution d'entrainement (data drift). Monitoring des predictions (concept drift : relation feature → cible qui change). Alerter quand la divergence depasse un seuil. Re-entrainement automatise ou manuel selon la criticite.

## Patterns
### Model registry
**Quand :** plusieurs modeles en production ou re-entrainements frequents.
**Comment :** MLflow Model Registry, Seldon, ou Sagemaker Model Registry. Chaque modele a : version, metriques, dataset d'origine, artefact, statut (staging/production/archived). Promotion staging → production via CI/CD. Rollback = pointer vers la version precedente en un clic.

### Feature store
**Quand :** features reutilisees entre plusieurs modeles ou entre train/serving.
**Comment :** Feast, Tecton, ou solution interne. Les features sont definies une fois, calculees offline (batch) et servies online (low latency). Le feature store garantit la consistance entre train et serve. Chaque feature est versionnee et documentee.
