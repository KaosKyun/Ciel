---
name: code-review
description: "Code Review — PR/merge request, checklist, feedback, revue de securite, revue de performance. A charger quand on fait ou recoit une revue de code."
---

# Code Review

## Checklist
- [ ] Le code fait ce qui est demande (pas de fonctionnalite cachee ou manquante)
- [ ] Les tests existent, passent, et couvrent les cas limites (RED → GREEN)
- [ ] La securite est verifiee : injection, auth, donnees sensibles, rate limiting
- [ ] Pas de TODO, FIXME, XXX, ou commentaire de code mort
- [ ] Les noms sont explicites (pas de `x`, `data`, `tmp`, `result`)
- [ ] La PR est petite (< 400 lignes ou justifiee)
- [ ] Les erreurs sont gerees (pas de try/catch vide, pas de throw generique)

## Anti-patterns
### Review trop tardive
**Ce qu'on voit :** la PR fait 2000 lignes, 15 fichiers, 3 fonctionnalites differentes.
**Pourquoi c'est dangereux :** impossible de review correctement. Les bugs passent inapercus. La review prend 2 heures et fatigue tout le monde.
**Faire plutot :** PR < 400 lignes. Une fonctionnalite par PR. Review rapide (< 30 min) ou WIP/ Draft PR pour les gros changements.

### Feedback agressif
**Ce qu'on voit :** "c'est nul", "refais tout", "qui a ecrit ca ?". Ton condescendant.
**Pourquoi c'est dangereux :** l'auteur se ferme, la qualite baisse, la confiance est brisee. L'equipe evite les PR.
**Faire plutot :** feedback sur le code, pas sur la personne. "Cette approche a tel risque" plutot que "t'es nul". Suggestions, pas ordres.

### Review sans contexte
**Ce qu'on voit :** le reviewer critique sans comprendre le contexte metier, les contraintes, ou le pourquoi.
**Pourquoi c'est dangereux :** le reviewer demande des changements qui n'ont pas de sens dans le contexte. Frustration, rework inutile.
**Faire plutot :** lire la description de la PR, le ticket, ou demander le contexte avant de commenter. Comprendre avant de critiquer.

## Patterns
### PR template
**Quand :** toute PR/merge request.
**Comment :** template avec sections : contexte, changements, test plan, points d'attention. L'auteur remplit le template, le reviewer a tout le contexte.

### The Boy Scout Rule
**Quand :** en reviewant du code existant.
**Comment :** laisser le code plus propre qu'on l'a trouve. Si on touche a un fichier, on ameliore un truc : renommer une variable, extraire une fonction, ajouter un test manquant.
