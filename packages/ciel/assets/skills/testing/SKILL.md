---
name: testing
description: "Testing — RED-GREEN-REFACTOR, test pyramid, testing behavior not implementation, FIRST principles, flaky test quarantine. À charger quand on écrit ou planifie des tests."
---

# Testing

**Principe premier :** Les tests ne sont pas là pour prouver que le code marche — ils sont là pour te permettre de changer le code sans peur. Un test qui ne survit pas à un refactoring n'est pas un test, c'est un otage. Le but ultime n'est pas 100% de couverture — c'est la confiance : si les tests passent, je peux déployer. Si tu ne peux pas déployer après un test vert, les tests ont échoué, pas le code.

## Checklist
- [ ] RED (test échoue) → GREEN (passe) → REFACTOR — dans cet ordre, toujours
- [ ] Les tests testent le comportement observable, pas l'implémentation interne
- [ ] Test pyramid : 70% unitaires, 20% intégration, 10% E2E — pas de pyramide inversée
- [ ] Chaque test est isolé — pas d'ordre d'exécution, pas de state partagé, pas de dépendance
- [ ] Les tests sont FIRST : Fast, Isolated, Repeatable, Self-validating, Timely
- [ ] Flaky test detection : > 2% de flaky → quarantaine automatique → fix ou delete dans le sprint

## Anti-patterns
### Tester l'implémentation
**Ce qu'on voit :** test qui mock `repository.findById()` et vérifie qu'il est appelé avec les bons arguments. Le test sait QUELLES méthodes le code appelle, pas ce que le code produit.
**Pourquoi c'est dangereux :** le test est couplé à l'implémentation. Tu refactores en inline le `findById()` → le test casse alors que le comportement est identique. Ces tests ne donnent PAS la confiance pour refactorer — ils empêchent le refactoring.
**Faire plutôt :** tester le comportement observable. Input → output. "Given un utilisateur avec id 123, when GET /users/123, then retourne {name, email}". Peu importe si le handler appelle un service ou un repository.

### Mock absolument tout
**Ce qu'on voit :** DB mockée, Redis mocké, filesystem mocké, horloge mockée. Le test unitaire passe, le test d'intégration n'existe pas. Premier déploiement → explosion.
**Pourquoi c'est dangereux :** les mocks mentent. Un mock Redis ne vérifie pas le format de la clé. Un mock DB ne vérifie pas la contrainte UNIQUE. Le test passe mais le code est cassé en condition réelle. C'est la fausse confiance — pire que pas de confiance.
**Faire plutôt :** mocker les frontières lentes/non-déterministes (appels HTTP externes, emails). Tester avec une vraie DB en intégration (testcontainers, pg_tmp). La DB est le composant le plus important à tester réellement.

### Test flaky toléré
**Ce qu'on voit :** "ce test faille parfois, relance le job". Le pipeline passe au 3ème rerun. Le flaky rate est de 5% mais personne ne le mesure.
**Pourquoi c'est dangereux :** chaque test flaky érode la confiance dans le pipeline. Quand le rouge ne veut plus dire "bug", les vrais bugs passent. L'équipe développe un réflexe "rerun" au lieu de "investigate". C'est la mort lente de la CI.
**Faire plutôt :** quarantaine automatique. Flaky > 2% → test déplacé dans une suite séparée. Le pipeline principal reste strict (vert = ok, rouge = bug). La quarantaine est prioritaire — chaque test est fixé, réécrit, ou supprimé.

## Patterns
### Test pyramid
**Quand :** toute suite de tests.
**Comment :** base large de tests unitaires (rapides, isolés, nombreux). Milieu de tests d'intégration (DB réelle, API réelle). Sommet étroit de tests E2E (parcours critiques). Si la pyramide s'inverse (beaucoup d'E2E, peu d'unitaires), le feedback est lent et le debugging est coûteux.

### FIRST principles
**Quand :** écrire chaque test.
**Comment :** Fast (< 5ms unitaire, < 100ms intégration), Isolated (pas d'ordre), Repeatable (même résultat à chaque run), Self-validating (assertion, pas de log à vérifier manuellement), Timely (écrit AVANT le code — RED first).
