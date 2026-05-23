---
name: alerting
description: "Alerting — SLO-based alerting, alert fatigue prevention, on-call, post-mortems, runbooks. À charger quand on configure des alertes."
---

# Alerting

**Principe premier :** Une alerte qui ne déclenche pas d'action n'est pas une alerte — c'est du bruit qui tue les vraies alertes. Chaque alerte doit être : actionable (tu sais quoi faire), symptôme-based (pas cause-based), et avoir un runbook. Si tu ne peux pas écrire le runbook en < 5 étapes, ne crée pas l'alerte. Le but n'est pas d'être notifié de tout — c'est d'être notifié assez tôt pour agir avant que les utilisateurs ne remarquent.

## Checklist
- [ ] Les alertes sont sur les symptômes (P95 > 1s, error rate > 1%), pas sur les causes (CPU > 70%)
- [ ] Chaque alerte a un runbook — pas "on verra quand ça sonnera"
- [ ] SLA de réponse défini : critical (page, < 5 min), high (page jour, < 30 min), medium (ticket, < 4h)
- [ ] Alertes groupées et dé-dupliquées — pas 50 pages pour la même cause racine
- [ ] On-call rotation documentée avec escalation — personne n'est on-call seul sans backup
- [ ] Post-mortem blameless après chaque incident majeur

## Anti-patterns
### Alerter sur tout
**Ce qu'on voit :** "CPU > 70%", "mémoire > 60%", "disque > 70%" — 200 alertes configurées. 15 pages par nuit. L'équipe a muté le canal.
**Pourquoi c'est dangereux :** alert fatigue. Chaque fausse alerte entraîne la suivante vers l'ignore. Quand la vraie alerte critique arrive, personne ne la voit. Le canal d'alerte est devenu un flux de bruit ignoré.
**Faire plutôt :** alerter sur les symptômes utilisateur. "P95 latency > 1s pendant 5 min" (l'utilisateur ressent la lenteur). "Error rate > 1% pendant 5 min" (l'utilisateur voit des erreurs). Le CPU est une cause possible parmi 10, pas un symptôme.

### Alerte sans runbook
**Ce qu'on voit :** alerte "PaymentService is down". Pas de runbook. L'on-call Googlise "comment restart payment service" à 3h du matin.
**Pourquoi c'est dangereux :** MTTR explose. L'on-call stressé fait des erreurs. Le runbook est la différence entre "redémarrer en 2 minutes" et "aggraver l'incident en 30 minutes de debugging paniqué".
**Faire plutôt :** runbook attaché à chaque alerte. Étapes concrètes. "1. Vérifier les logs dans Loki avec {service=payment, level=error}. 2. Si OOM → restart le pod. 3. Si DB timeout → vérifier les connexions pool. 4. Si rien → escalader à l'équipe backend."

### Aucun post-mortem
**Ce qu'on voit :** incident résolu → "ouf, on passe à autre chose". Pas d'analyse. Le même incident se reproduit 3 mois plus tard.
**Pourquoi c'est dangereux :** sans post-mortem, l'organisation n'apprend pas. Les mêmes erreurs se répètent. Le but du post-mortem n'est pas de trouver un coupable — c'est d'identifier les failles du SYSTÈME qui ont permis l'incident.
**Faire plutôt :** post-mortem blameless dans les 48h. Format : timeline, impact, root cause, what went well, what went wrong, action items. Les action items ont des owners et des deadlines.
