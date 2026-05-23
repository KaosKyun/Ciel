---
name: tech-leadership
description: "Tech Leadership — architecture decision, mentoring, code review, technical debt, roadmap, estimation, spike. A charger quand on fait du leadership technique."
---

# Tech Leadership

## Checklist
- [ ] Les decisions techniques sont documentees (ADR) avec contexte et alternatives
- [ ] La dette technique est suivie et budgetee (20% du sprint)
- [ ] Les estimations incluent les incertitudes (pessimiste, realiste, optimiste)
- [ ] Les spikes techniques sont planifies pour les zones de risque
- [ ] Le mentoring est structure (pair programming, code review, feedback regulier)
- [ ] La roadmap technique est alignee avec la roadmap produit
- [ ] Les decisions sont communiquees avec le "why" — pas juste le "what"
- [ ] L'autonomie de l'equipe est priorisee (vous etes un multiplicateur, pas un decideur)

## Anti-patterns
### Architecture par consensus
**Ce qu'on voit :** "on vote pour choisir entre Kafka et RabbitMQ". La decision est prise par le nombre de voix, pas par l'expertise.
**Pourquoi c'est dangereux :** le vote favorise le connu, pas le meilleur pour le contexte. La decision est rarement optimale. Personne n'est responsable.
**Faire plutot :** le tech lead ecoute, synthetise, et DECIDE. Les inputs de tous sont consideres mais la responsabilite est portee par une personne. ADR documente le pourquoi.

### Micro-management technique
**Ce qu'on voit :** le tech lead review chaque ligne de code, chaque PR, chaque decision. Rien ne passe sans approbation.
**Pourquoi c'est dangereux :** l'equipe ne grandit pas. Le tech lead est le goulot. Les decisions prennent 3x plus de temps. L'equipe devient dependante.
**Faire plutot :** deleguer, faire confiance, accepter que les juniors fassent des erreurs. Le tech lead est un filet de securite, pas un gardien.

### Decision sans ADR
**Ce qu'on voit :** "on a decide d'utiliser Prisma lors d'une reunion il y a 6 mois." Personne ne se souvient du pourquoi.
**Pourquoi c'est dangereux :** 6 mois plus tard, l'equipe se demande "pourquoi Prisma ?" et "est-ce que c'etait la bonne decision ?" Le contexte est perdu.
**Faire plutot :** ADR (Architecture Decision Record) pour toute decision significative. Contexte, options considerees, decision, consequences. Lisible et maintenable.

## Patterns
### ADR (Architecture Decision Record)
**Quand :** toute decision architecturale significative.
**Comment :** 1 fichier par decision. Format : Title, Context, Decision, Consequences, Alternatives. Dans `docs/adrs/`. Visible par toute l'equipe.

### Delegation progressive
**Quand :** developpeur junior ou middle qui monte en competence.
**Comment :** commencer par des petites decisions guidees → PR review → autonomie complete. Le tech lead recule progressivement. L'erreur est permise (et apprise).
