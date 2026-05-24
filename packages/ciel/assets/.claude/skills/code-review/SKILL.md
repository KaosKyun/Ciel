---
name: code-review
description: "Code Review — PR hygiene, review checklist, constructive feedback, security review, Boy Scout Rule. À charger quand on fait ou reçoit une revue de code."
---

# Code Review

**Principe premier :** La code review n'est pas un gate de qualité — c'est un outil de partage de connaissance. Le but #1 n'est pas de trouver des bugs (les tests et la CI font ça), c'est de s'assurer que le code est compréhensible par quelqu'un qui ne l'a pas écrit. Un bug trouvé en review est un échec des tests. Une incompréhension en review est un échec du code. La métrique n'est pas "nombre de commentaires" mais "est-ce que je pourrais maintenir ce code sans parler à l'auteur ?"

## Checklist
- [ ] La PR fait < 400 lignes — sinon, découper
- [ ] Les tests existent, passent, et couvrent les cas limites
- [ ] La description explique le POURQUOI, pas le QUOI (le diff montre le quoi)
- [ ] Les noms sont explicites — pas de `x`, `data`, `tmp`, `result`, `handle()`
- [ ] Pas de code mort, pas de TODO sans ticket, pas de commentaire qui ment
- [ ] La sécurité est vérifiée : injection, auth, PII exposé

## Anti-patterns
### PR de 2000 lignes
**Ce qu'on voit :** une PR avec 15 fichiers, 3 fonctionnalités, et une description "Refactoring + nouvelle feature + fix bug".
**Pourquoi c'est dangereux :** impossible à review correctement. Le cerveau humain ne peut pas traiter 2000 lignes de diff. Les bugs passent. La review dure 2h et personne ne la fait sérieusement. Les grosses PRs sont le symptôme d'un découpage du travail mal fait.
**Faire plutôt :** PR < 400 lignes. Une fonctionnalité, un fix, un refactoring par PR. Petits merges fréquents. Si le changement est gros → feature flag + PRs incrémentales.

### Feedback sur la personne
**Ce qu'on voit :** "c'est nul", "refais tout", "pourquoi t'as fait comme ça ?" — ton condescendant.
**Pourquoi c'est dangereux :** ça ne tue pas que l'humeur — ça tue les futures PRs. L'auteur évite de soumettre, ou soumet en cachette. La qualité baisse par peur du feedback. Le coût est à long terme.
**Faire plutôt :** "Cette approche a le risque X" (pas "tu as mal fait"). Suggestion, pas ordre : "Est-ce qu'on pourrait... ?". Le feedback cible le code, jamais la personne.

### LGTM reflex
**Ce qu'on voit :** "LGTM" sur une PR de 500 lignes, 2 minutes après l'ouverture.
**Pourquoi c'est dangereux :** c'est un non-review. Le reviewer n'a pas lu le code. L'auteur n'apprend rien. Les bugs passent. Pire : ça donne une fausse confiance ("c'est reviewé").
**Faire plutôt :** si tu n'as pas le temps, ne review pas. Si tu review, passe au moins 15 min et trouve au moins UNE chose (positive ou à améliorer). Une review qui ne produit aucun commentaire n'est pas une review.

## Patterns
### PR template
**Quand :** toute PR.
**Comment :** template concis : contexte, changements, captures/évidence, points d'attention pour le reviewer. L'auteur remplit. Le reviewer a tout le contexte. 2 minutes de remplissage = 15 minutes gagnées en review.

### Boy Scout Rule
**Quand :** tout fichier touché.
**Comment :** laisser le code plus propre qu'on ne l'a trouvé. Renommer une variable confuse. Extraire une fonction de 30 lignes. Ajouter un test manquant. Pas de refactoring massif — juste le petit coup de balai.
