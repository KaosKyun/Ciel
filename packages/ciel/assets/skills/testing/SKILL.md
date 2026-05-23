---
name: testing
description: "Testing — tests unitaires, integration, E2E, snapshot, mutation, TDD, couverture. A charger quand on ecrit ou planifie des tests."
triggers:
  path: "**/*.test.*,**/*.spec.*,**/__tests__/**,**/vitest*,**/jest.config*,**/pytest*"
---

# Testing

## Checklist
- [ ] Le test echoue d'abord (RED) avant de coder la solution (GREEN)
- [ ] Les tests unitaires couvrent les cas limites (edge cases, erreurs, valeurs nulles)
- [ ] Les tests d'integration verifient les vrais appels DB/API (pas de mocks systeme)
- [ ] Les tests E2E couvrent les parcours critiques (login, paiement, inscription)
- [ ] Les tests sont isoles : pas de state partage, pas d'ordre d'execution假设
- [ ] La couverture est mesuree (minimum 80% lignes, 100% sur les cas critiques)
- [ ] Les tests sont rapides (< 1s par test unitaire, < 10s pour toute la suite)

## Anti-patterns
### Tester l'implementation pas le comportement
**Ce qu'on voit :** le test verifie des methodes privees, des etats internes, ou l'ordre d'appel.
**Pourquoi c'est dangereux :** le refactoring casse les tests meme si le comportement est correct. Tests fragiles, maintenance couteuse.
**Faire plutot :** tester le comportement observable. Entree → sortie. Ce que l'utilisateur ou le systeme voit, pas comment c'est implemente.

### Mock systematique
**Ce qu'on voit :** tout est mocke — DB, API, filesystem, horloge. Le test ne teste rien de reel.
**Pourquoi c'est dangereux :** les mocks mentent. Le test passe, la production casse. Le faux positif cree une fausse confiance.
**Faire plutot :** mocker les frontieres systeme (IO, reseau). Tester avec de vraies DB en integration. Mock API uniquement en unitaire.

### Test qui depend d'un autre
**Ce qu'on voit :** le test B a besoin que le test A ait deja tourne pour avoir des donnees.
**Pourquoi c'est dangereux :** l'ordre d'execution devient un contrat implicite. Un test seul echoue. CI flaky.
**Faire plutot :** chaque test cree ses propres donnees (setup/teardown). Ordre aleatoire = les tests passent toujours.

## Patterns
### Test pyramid
**Quand :** toute suite de tests.
**Comment :** 70% tests unitaires (rapides, isoles), 20% tests integration (API/DB reelles), 10% tests E2E (parcours critiques). Base large et stable, sommet etroit et lent.

### FIRST principle
**Quand :** ecrire un test.
**Comment :** Fast (rapide), Isolated (isole), Repeatable (reproductible), Self-validating (auto-valide), Timely (ecrit au bon moment — avant le code).
