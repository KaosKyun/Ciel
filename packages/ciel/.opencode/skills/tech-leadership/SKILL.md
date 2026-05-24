---
name: tech-leadership
description: "Tech Leadership — ADR, RFC, architecture reviews, dette technique, mentoring, estimation, roadmap technique. A charger quand on fait du leadership technique."
---

# Tech Leadership

**Principe premier :** Le leadership technique n'est pas "le dev le plus senior decide" — c'est creer un environnement ou les bonnes decisions emergent de l'equipe. Le tech lead n'est pas un architecte omniscient qui dicte les solutions — c'est un jardinier qui cree les conditions pour que les bonnes pratiques poussent. Les deux livrables principaux sont les ADR (Architecture Decision Records) qui capturent le contexte et le pourquoi des decisions, et la strategie de dette technique (toute equipe a de la dette — la question est de savoir laquelle et a quel prix). Le technicien resout les problemes ; le tech lead rend l'equipe capable de resoudre les problemes sans lui.

## Checklist
- [ ] Les decisions techniques sont documentees en ADR (contexte, alternatives considerees, decision, consequences)
- [ ] La dette technique est suivie, budgetee (ex: 20% du sprint), et communiquee aux stakeholders
- [ ] Les RFC sont le processus standard pour les changements majeurs (> 2 semaines d'effort)
- [ ] L'estimation est basee sur l'historique (cycle time, throughput) — pas sur des jours/homme devines
- [ ] Les revues d'architecture sont regulieres (mensuelles) avec des criteres objectifs
- [ ] Le mentoring est structure : chaque dev junior a un plan de progression avec objectifs mesurables
- [ ] La roadmap technique est alignee avec la roadmap produit — pas deux planifications paralleles

## Anti-patterns
### Tech lead = seul decideur
**Ce qu'on voit :** le tech lead prend toutes les decisions seul. "Je connais le systeme, faites ce que je dis." L'equipe execute sans comprendre.
**Pourquoi c'est dangereux :** goulot d'etranglement decisionnel. L'equipe devient passive — "je fais ce que le lead dit". Le lead devient le bus factor = 1. Quand il part, la connaissance part avec lui. Les decisions ne sont pas contraintes parce que personne ne les conteste.
**Faire plutot :** decisions via RFC. L'auteur propose, l'equipe review, le lead approuve ou demande des changements. Le lead est un editeur, pas un auteur. Les decisions sont documentees (ADR) pour que le contexte survive au lead.

### Dette technique = tabou
**Ce qu'on voit :** l'equipe sait qu'il y a de la dette. Personne n'en parle aux stakeholders. Un jour, tout explose et le sprint "refactoring urgent" dure 3 mois.
**Pourquoi c'est dangereux :** la dette technique non communiquee est une bombe a retardement. Les stakeholders ne comprennent pas pourquoi "une feature simple prend 3 semaines". La confiance s'erode. L'equipe est en mode pompier permanent.
**Faire plutot :** la dette technique est un choix economique, pas une honte. La quantifier ("ce module coute 2x plus cher a modifier que la moyenne"). La presenter aux stakeholders comme un risque avec un cout. Budgeter 20% du sprint pour la reduction de dette. Montrer le ROI : "apres ce refactoring, les features sur ce module seront 2x plus rapides".

### Estimation = souhait
**Ce qu'on voit :** "c'est 3 jours" — base sur rien. Les estimations sont systematiquement x2-x3. Les deadlines sont basees sur les estimations et deviennent des engagements.
**Pourquoi c'est dangereux :** l'estimation n'est pas un engagement, mais les stakeholders l'entendent comme tel. Le cycle se repete : estimation optimiste → sous-performance percue → pression → estimation encore plus optimiste pour compenser → burn-out.
**Faire plutot :** estimer en probabilites : "50% de chances en 3 jours, 90% en 7 jours." Utiliser l'historique (cycle time reel, pas estime). Separer estimation (combien de temps) et engagement (quand c'est livre). L'engagement vient apres l'exploration, pas avant.

## Patterns
### ADR (Architecture Decision Record)
**Quand :** toute decision architecturale non triviale.
**Comment :** format standard : Titre, Contexte (pourquoi maintenant), Decision (ce qu'on a decide), Alternatives considerees, Consequences (positives et negatives). Fichier `docs/adrs/NNNN-title.md`. Les ADR documentent le POURQUOI, pas juste le QUOI. Un nouveau membre peut lire les ADR et comprendre l'histoire de l'architecture.

### RFC (Request for Comments)
**Quand :** changement qui affecte > 1 equipe ou > 2 semaines d'effort.
**Comment :** document de 2-4 pages. Sections : Motivation, Design propose, Alternatives, Impact (migration, cout, risques). Review period : 3-5 jours. L'auteur n'est pas le decideur — l'equipe (ou les equipes) commentent, le lead tranche. La decision est capturee en ADR.

### Probabilistic estimation
**Quand :** estimation d'une tache de > 1 jour.
**Comment :** "J'ai 50% de confiance que ca prendra X jours, 90% que ca prendra Y jours." Le ratio Y/X mesure l'incertitude. Si Y > 3X → l'incertitude est trop grande, faire un spike pour reduire. L'estimation est basee sur des taches similaires passees (historique), pas sur l'intuition.
