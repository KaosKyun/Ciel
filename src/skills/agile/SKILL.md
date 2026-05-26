---
name: agile
description: "Agile — Scrum, Kanban, Shape Up, sprints, estimation, retros, amelioration continue. A charger quand on travaille en mode agile."
---

# Agile

**Principe premier :** L'agilite n'est pas un framework (Scrum n'est pas l'agilite) — c'est un principe : livrer de la valeur en petits increments, inspecter le resultat, et adapter le plan. Le manifeste agile a 4 valeurs, et la premiere est "les individus et leurs interactions plus que les processus et les outils". Si ton processus agile est plus important que les personnes qui l'utilisent, tu as echoue l'agilite. Le but du process n'est pas d'etre suivi — c'est de rendre l'equipe plus efficace. Un processus qui ralentit l'equipe n'est pas agile, meme s'il suit Scrum a la lettre. Le meilleur indicateur d'agilite : combien de temps entre "j'ai une idee" et "c'est en production" ?

## Checklist
- [ ] Les ceremonies sont cadrees : standup 15min, retro 1h, planning 1-2h — si plus long, le processus est casse
- [ ] Les tickets sont INVEST : Independent, Negotiable, Valuable, Estimable, Small, Testable
- [ ] Le WIP est limite (Kanban/Scrum avec capacite explicite) — pas plus de travail en cours que de capacite
- [ ] Les retros produisent des actions concretes (pas "on communiquera mieux") — max 2-3 actions par retro
- [ ] La velocite est utilisee pour le planning, pas pour le jugement de performance
- [ ] Le backlog est priorise par valeur business, pas par "c'est facile" ou "c'est urgent depuis 6 mois"
- [ ] Le cycle time (temps ticket ouvert → ferme) est mesure et s'ameliore — c'est le vrai KPI agile

## Anti-patterns
### Agile = Scrum = standups + sprints
**Ce qu'on voit :** l'equipe fait des standups, des sprints de 2 semaines, et un retro. "On est agile." Les stories sont estimees en story points. Les sprints sont bookes a 110%. Rien n'est livre en production a la fin du sprint.
**Pourquoi c'est dangereux :** c'est du theatre agile. Les ceremonies sont suivies mais l'objectif (livrer de la valeur rapidement) est manque. Le processus devient le produit. L'equipe est frustree ("l'agile c'est des reunions qui servent a rien") sans comprendre que le probleme n'est pas l'agilite, c'est l'imitation vide de l'agilite.
**Faire plutot :** se demander POURQUOI on fait chaque ceremonie. Si le standup est un compte-rendu au manager, c'est foutu — le standup est pour que l'equipe se synchronise. Si la retro ne produit jamais d'actions, l'arreter. Moins de processus, plus de livraison. Commencer par Kanban (pas de sprint, flux continu) et ajouter des ceremonies seulement si le besoin emerge.

### Story points = mesure de performance
**Ce qu'on voit :** "tu as fait 8 points ce sprint, l'objectif est 13." Les story points deviennent un KPI individuel.
**Pourquoi c'est dangereux :** les story points mesurent la complexite relative, pas la productivite. Les utiliser comme KPI = l'equipe gonfle les estimations. 1 point devient 3. La velocite augmente mais rien n'est livre plus vite. Culture de la peur et du gaming du systeme.
**Faire plutot :** les story points servent UNIQUEMENT a la planification de sprint (combien de travail l'equipe peut absorber). La vraie metrique est le cycle time (combien de temps pour livrer) et le throughput (combien de tickets livres par semaine). Ces metriques ne sont pas gameables.

### Retro = rituel vide
**Ce qu'on voit :** "Qu'est-ce qui s'est bien passe ? Qu'est-ce qui s'est mal passe ?" Memes reponses depuis 6 mois : "la communication" et "les specs pas claires". Zero action concrete.
**Pourquoi c'est dangereux :** une retro sans action est un signal que l'equipe est apprise a l'impuissance. Les problemes sont identifies mais jamais resolus. La retro devient une soupape ou on se plaint sans consequence — c'est pire que pas de retro car ca cree du cynisme.
**Faire plutot :** chaque retro produit 1-2 actions concretes, assignees, avec deadline. La retro suivante commence par "est-ce que les actions de la derniere retro sont faites ?" Si non, pourquoi ? Si une action n'est jamais faite, le probleme n'est pas l'equipe — c'est que le systeme empeche l'amelioration.

## Patterns
### Kanban pour commencer
**Quand :** equipe qui decouvre l'agilite ou qui a ete brulee par Scrum.
**Comment :** visualiser le flux (colonnes To Do / In Progress / Done), limiter le WIP (max 2 taches par personne en In Progress), mesurer le cycle time. Pas de sprint, pas d'estimation obligatoire, pas de ceremonies forcees. Ajouter un standup uniquement si la synchro est necessaire. Iterer sur le processus a partir de la.

### Cycle time comme North Star
**Quand :** mesurer l'amelioration continue.
**Comment :** cycle time = temps entre "le ticket est pret a developper" et "en production". Mesurer le P50 et P85 (pas la moyenne — les outliers faussent). Objectif : reduire le cycle time sans sacrifier la qualite. Un cycle time qui diminue = l'equipe s'ameliore VRAIMENT.
