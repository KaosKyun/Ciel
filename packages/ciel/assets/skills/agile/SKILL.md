---
name: agile
description: "Agile — Scrum, Kanban, sprint, ceremonies, estimation, velocity, retro, continuous improvement. A charger quand on travaille en mode agile."
triggers:
  path: "**/sprint*,**/scrum*,**/kanban*,**/retro*,**/standup*,**/agile*"
---

# Agile

## Checklist
- [ ] Les ceremonies sont cadrees dans le temps (standup 15min, retro 1h, grooming 1h)
- [ ] Les tickets sont decoupables (INVEST : Independent, Negotiable, Valuable, Estimable, Small, Testable)
- [ ] La definition of Done est explicite et connue de tous
- [ ] La velocity est suivie sur plusieurs sprints (tendance, pas objectif)
- [ ] Les retros produisent des actions concretes (pas juste "c'etait bien/c'etait nul")
- [ ] Le backlog est priorise et affine regulierement (refinement hebdo)
- [ ] Les dependances sont identifiees et levees (bloquant levee ASAP)
- [ ] L'amelioration continue est la regle (pas de "on a toujours fait comme ca")

## Anti-patterns
### Ceremonies sans fin
**Ce qu'on voit :** standup de 45 minutes, retro de 3 heures, grooming de 2 heures. Les ceremonies mangent le temps de dev.
**Pourquoi c'est dangereux :** l'equipe n'a plus le temps de coder. La frustration monte. Les ceremonies sont percues comme une perte de temps.
**Faire plutot :** timeboxing strict. Standup : 15 min max (3 questions, pas de debug). Retro : 1h max. Refinement : 1h max. Timer. La parole est au facilitateur.

### Velocity comme objectif
**Ce qu'on voit :** "notre velocity est de 40 points, on doit l'augmenter a 50." Les points deviennent un KPI de performance.
**Pourquoi c'est dangereux :** les devs gonflent les estimations. La qualite baisse. Les points perdent leur sens. L'equipe triche.
**Faire plutot :** la velocity est une mesure, pas un objectif. Elle sert a planifier, pas a evaluer. Les points sont relatifs a l'equipe, pas comparables entre equipes.

### Retro sans action
**Ce qu'on voit :** chaque retro, on identifie les memes problemes. Rien ne change. Les actions ne sont jamais suivies.
**Pourquoi c'est dangereux :** l'equipe se sent ignoree. Les problemes persistent. La retro devient une perte de temps. L'amelioration continue s'arrete.
**Faire plutot :** chaque retro produit MAX 3 actions concretes. Action = "Qui fait quoi pour quand ?". La retro suivante commence par la verification des actions precedentes.

## Patterns
### Timeboxing
**Quand :** toute ceremonie agile.
**Comment :** chaque ceremonie a une duree maximale definie. Timer visible par tous. Le facilitateur coupe si le temps est depasse. Le reste est discute hors-ceremonie.

### Definition of Done solide
**Quand :** fin de chaque ticket/user story.
**Comment :** DoD = code review + tests passent + documentation + deploye en staging + PO valide. Explicite, ecrit, connu. Rien n'est "fini" tant que la DoD n'est pas remplie.
