---
name: alerting
description: "Alerting — SLO-based alerting, alert fatigue prevention, on-call, post-mortems, runbooks. A charger quand on configure des alertes."
---

# Alerting

**Principe premier :** Une alerte qui ne declenche pas d'action n'est pas une alerte — c'est du bruit qui tue les vraies alertes. Chaque alerte doit etre : actionable (tu sais quoi faire), symptom-based (pas cause-based), et avoir un runbook. Si tu ne peux pas ecrire le runbook en < 5 etapes, ne cree pas l'alerte. Le but n'est pas d'etre notifie de tout — c'est d'etre notifie assez tot pour agir avant que les utilisateurs ne remarquent.

## Checklist
- [ ] Les alertes sont sur les symptomes (P95 > 1s, error rate > 1%), pas sur les causes (CPU > 70%)
- [ ] Chaque alerte a un runbook — pas "on verra quand ca sonnera"
- [ ] Les regles d'alerte et la config AlertManager sont dans le repo (alerting as code) — pas creees a la main
- [ ] SLA de reponse defini : critical (page, < 5 min), high (page jour, < 30 min), medium (ticket, < 4h)
- [ ] Alertes groupees et de-dupliquees — pas 50 pages pour la meme cause racine
- [ ] On-call rotation documentee avec escalation — personne n'est on-call seul sans backup
- [ ] Post-mortem blameless apres chaque incident majeur + 5 Whys jusqu'a la cause racine

## Anti-patterns
### Alerter sur tout
**Ce qu'on voit :** "CPU > 70%", "memoire > 60%", "disque > 70%" — 200 alertes configurees. 15 pages par nuit. L'equipe a mute le canal.
**Pourquoi c'est dangereux :** alert fatigue. Chaque fausse alerte entraine la suivante vers l'ignore. Quand la vraie alerte critique arrive, personne ne la voit. Le canal d'alerte est devenu un flux de bruit ignore.
**Faire plutot :** alerter sur les symptomes utilisateur. "P95 latency > 1s pendant 5 min" (l'utilisateur ressent la lenteur). "Error rate > 1% pendant 5 min" (l'utilisateur voit des erreurs). Le CPU est une cause possible parmi 10, pas un symptome.

### Alerte sans runbook
**Ce qu'on voit :** alerte "PaymentService is down". Pas de runbook. L'on-call Googlise "comment restart payment service" a 3h du matin.
**Pourquoi c'est dangereux :** MTTR explose. L'on-call stresse fait des erreurs. Le runbook est la difference entre "redemarrer en 2 minutes" et "aggraver l'incident en 30 minutes de debugging panique".
**Faire plutot :** runbook attache a chaque alerte. Etapes concretes. "1. Verifier les logs dans Loki avec {service=payment, level=error}. 2. Si OOM -> restart le pod. 3. Si DB timeout -> verifier les connexions pool. 4. Si rien -> escalader a l'equipe backend. 5. Post-mortem avec 5 Whys dans les 48h."

### Aucun post-mortem
**Ce qu'on voit :** incident resolu -> "ouf, on passe a autre chose". Pas d'analyse. Le meme incident se reproduit 3 mois plus tard.
**Pourquoi c'est dangereux :** sans post-mortem, l'organisation n'apprend pas. Les memes erreurs se repetent. Le but du post-mortem n'est pas de trouver un coupable — c'est d'identifier les failles du SYSTEME qui ont permis l'incident.
**Faire plutot :** post-mortem blameless dans les 48h. Format : timeline, impact, 5 Whys jusqu'a la cause racine, what went well, what went wrong, action items. Les action items ont des owners et des deadlines.

### Corriger le symptome, pas la cause racine
**Ce qu'on voit :** le disque est plein -> on supprime des logs. Le disque se remplit 3 jours plus tard. Meme incident, meme reponse. 5 iterations avant de se demander POURQUOI.
**Pourquoi c'est dangereux :** corriger le symptome sans trouver la cause racine garantit la recidive. Chaque recurrence erode la confiance. Le MTTR apparent est bas, le MTTR reel est infini (l'incident n'est jamais vraiment resolu).
**Faire plutot :** methode des 5 Whys. "Le disque est plein" -> Pourquoi ? "Les logs font 50 Go/jour" -> Pourquoi ? "Level DEBUG active en prod" -> Pourquoi ? "Le deploiement a ecrase la config" -> Pourquoi ? "La config n'est pas versionnee" -> Action racine : versionner la config + alerter si disque > 80%. Le bug est le niveau DEBUG. La cause racine est l'absence d'IaC pour la config. On corrige la cause, pas le symptome.

## Patterns
### AlertManager (routing + dedup + silence)
**Quand :** toute stack Prometheus en production.
**Comment :** Prometheus evalue les rules -> alertes -> AlertManager. AlertManager groupe les alertes (`group_by: [service, severity]`), deduplique (meme alerte = une notification), silencie la maintenance (`matchers: [env=staging]`). Routes par severite : critical -> PagerDuty/Opsgenie, warning -> Slack. Config dans `monitoring/alertmanager.yml`, versionne dans le repo.

### Alerting as Code (regles dans le repo)
**Quand :** toute equipe de plus d'une personne.
**Comment :** regles Prometheus (`monitoring/rules.yml`), config AlertManager (`monitoring/alertmanager.yml`), dashboards Grafana (`monitoring/dashboards/`) — tout dans le repo, versionne, deploye via CI/CD. Pas de regle creee a la main dans l'UI Grafana. Une PR pour chaque changement d'alerte — le seuil, le runbook_url, la severite sont revus comme du code.

### Runbook integre a l'alerte
**Quand :** chaque alerte creee.
**Comment :** `annotations: { runbook_url: "https://wiki.corp/runbooks/payment-latency" }`. Le runbook contient : (1) ce que signifie l'alerte, (2) comment verifier dans Grafana/Loki/Tempo, (3) actions de mitigation, (4) qui escalader, (5) comment faire un 5 Whys si la mitigation ne suffit pas.

### Post-mortem blameless + 5 Whys
**Quand :** tout incident qui a declenche une alerte on-call.
**Comment :** document blameless dans les 48h. Sections : timeline, impact, 5 Whys jusqu'a la cause racine systemique, what went well, what went wrong, action items avec owners et deadlines. L'objectif est d'ameliorer le SYSTEME — pas de trouver un responsable. Action items prioritaires sur le prochain sprint.
