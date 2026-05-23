---
name: deployment-strategies
description: "Deployment Strategies — blue-green, canary, rolling, feature flags, rollback. A charger quand on planifie un deploiement."
---

# Deployment Strategies

## Checklist
- [ ] La strategie de deploiement est choisie selon le risque et le contexte (pas toujours la meme)
- [ ] Le rollback est planifie (pas improvise en stress)
- [ ] Les health checks sont passes avant de basculer le trafic
- [ ] Le deploiement est automatise (pas de `git pull && npm run build && pm2 restart`)
- [ ] La nouvelle version est testee avant d'etre exposee aux utilisateurs (smoke tests, canary)
- [ ] Les feature flags permettent de desactiver une fonctionnalite sans redeployer
- [ ] L'observabilite est en place pendant le deploiement (dashboards, alertes)

## Anti-patterns
### Deploiement manuel
**Ce qu'on voit :** `git pull && npm run build && pm2 restart` sur le serveur.
**Pourquoi c'est dangereux :** pas de rollback, pas de health check, pas de trace. Si le build plante, le serveur est dans un etat indefini.
**Faire plutot :** deploiement automatise via CI/CD. Un click ou un merge declenche le pipeline. Si le health check echoue, rollback automatique.

### Pas de rollback
**Ce qu'on voit :** la nouvelle version est cassee. Personne ne sait comment revenir en arriere.
**Pourquoi c'est dangereux :** chaque minute de downtime coute de l'argent et de la confiance. Le fix prend 30 minutes en stress.
**Faire plutot :** rollback en un click. Si CI/CD : `git revert HEAD && git push`. Si blue-green : basculer le trafic vers l'ancien groupe. Toujours garder l'ancienne version prete.

### Deploiement le vendredi a 17h
**Ce qu'on voit :** deploiement de fin de semaine. Bug decouvert le samedi.
**Pourquoi c'est dangereux :** equipe indisponible. Incident non gere. 3 jours de mauvaise experience utilisateur.
**Faire plutot :** deploiement en debut de semaine (mardi, mercredi matin). Equipe disponible pour les hotfixes. Rollback possible dans l'apres-midi.

## Patterns
### Blue-Green
**Quand :** zero downtime requis. Rollback immediat.
**Comment :** 2 environnements identiques (blue, green). Le live est sur blue. On deploie sur green. On teste green. On bascule le trafic sur green. Si probleme, on rebascule sur blue.

### Canary
**Quand :** deploiement a risque (breaking change, nouveau systeme).
**Comment :** 5% du trafic -> nouvelle version pendant 10 min. Si pas d'erreur -> 30% -> 50% -> 100%. Si erreur -> 0% (rollback automatique).

### Feature flags
**Quand :** fonctionnalite pas encore prete, ou qui doit pouvoir etre desactivee sans deploiement.
**Comment :** `if (featureFlags.isEnabled("new-checkout")) { ... } else { ... }`. Pas de deploiement necessaire pour activer/desactiver. Les flags sont geres dans un service dedie.
