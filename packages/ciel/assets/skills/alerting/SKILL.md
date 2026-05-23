---
name: alerting
description: "Alerting — alertes, PagerDuty/Opsgenie, escalation, on-call, runbooks, silence, fatigue d'alerte. A charger quand on configure les alertes."
triggers:
  path: "**/alert*,**/pagerduty*,**/opsgenie*,**/oncall*,**/runbook*"
---

# Alerting

## Checklist
- [ ] Chaque alerte a un runbook (quoi faire, qui contacter, lien dashboard)
- [ ] Les seuils d'alerte sont definis avec des valeurs mesurables PAS (ok → warning → critical)
- [ ] Les alertes sont classees par severite (P0 = site down, P1 = feature degradee, P2 = warning)
- [ ] L'escalation est automatique (si P0 non acquitte apres 5 min → manager → directeur)
- [ ] Les alertes de bruit sont silenciees (pas de fatigue, pas d'alerte ignoree)
- [ ] Le calendrier on-call est gere (rotation equitable, backup)
- [ ] Une post-mortem est faite pour chaque P0 (sans blame, avec actions)
- [ ] Les alertes sont testees (simulation, pas de "c'etait la premiere fois")

## Anti-patterns
### Trop d'alertes
**Ce qu'on voit :** 200 alertes par nuit. CPU > 50%, RAM > 60%, 1 erreur 4xx, etc.
**Pourquoi c'est dangereux :** l'on-call ignore toutes les alertes. La vraie urgence est noyee. L'alerte qui reveille a 3h du mat pour un warning est ignoree a 4h pour un vrai P0.
**Faire plutot :** alerter sur des symptomes, pas sur des causes. P0 = utilisateur impacte (error rate > 5%, P95 > 2s). P1 = risque imminent. Regle : si l'alerte ne necessite pas d'action immediate, ce n'est pas une alerte.

### Pas de runbook
**Ce qu'on voit :** l'alerte sonne a 3h du mat. L'on-call se reveille, cherche quoi faire, panique, appelle un collegue.
**Pourquoi c'est dangereux :** le temps de remediation est x10. L'erreur humaine est probable. L'on-call est stresse et fatigue.
**Faire plutot :** chaque alerte a un runbook. 1. Verifier le dashboard X. 2. Si Y → restart. 3. Si Z → escalader a equipe A. Le runbook est teste et mis a jour.

### Pas de post-mortem
**Ce qu'on voit :** incident resolu. L'equipe passe a la suite. Pas d'analyse post-incident.
**Pourquoi c'est dangereux :** la cause racine n'est pas traitee. Le meme incident se reproduit. L'equipe traite les symptomes pas la maladie.
**Faire plutot :** post-mortem pour tout P0. Sans blame. 5 Why. Actions correctives avec deadline. Suivi dans le backlog.

## Patterns
### Alert fatigue prevention
**Quand :** toute equipe avec on-call.
**Comment :** une alerte = un symptome utilisateur. Pas d'alerte sur des causes internes (CPU, RAM) sauf si critique. Taux de "false positive" < 10%. Revue mensuelle des alertes.

### Post-mortem without blame
**Quand :** apres chaque incident P0 ou P1.
**Comment :** chronologie des evenements. Cause racine. 5 Why. Actions correctives. Blame = poison. Le systeme a echoue, pas la personne.
