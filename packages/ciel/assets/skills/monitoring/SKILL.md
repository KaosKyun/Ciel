---
name: monitoring
description: "Monitoring — RED/USE metrics, SLI/SLO/SLA comme contrats, dashboards comme outils de debugging, alerting fatigue. À charger quand on met en place du monitoring."
---

# Monitoring

**Principe premier :** Le monitoring n'est pas "avoir des dashboards" — c'est pouvoir répondre à deux questions en < 30 secondes : "est-ce que le système fonctionne ?" et "si non, qu'est-ce qui a changé ?". Si tes dashboards ne répondent pas à ça, ils sont du bruit visuel. La métrique fondamentale n'est pas le nombre de graphiques — c'est le Mean Time To Detect (MTTD). Combien de temps entre le début de l'incident et la première alerte ? Si la réponse est "quand un client ouvre un ticket", ton monitoring a échoué.

## Checklist
- [ ] RED metrics par service : Rate, Errors, Duration (P50/P95/P99) — couvre l'expérience utilisateur
- [ ] USE metrics par ressource : Utilization, Saturation, Errors — couvre l'infrastructure
- [ ] SLI définis (ce qu'on mesure), SLO documentés (l'objectif), SLA communiqués (la promesse)
- [ ] Dashboards avec seuils visuels (vert/jaune/rouge) — pas juste des lignes sur un graphique
- [ ] Alertes sur les signaux critiques uniquement — pas d'alerte sur "CPU > 70% pendant 30s à 3h du matin"
- [ ] Runbook associé à chaque alerte — "si cette alerte sonne, voici quoi faire"

## Anti-patterns
### Dashboard = décoration
**Ce qu'on voit :** un écran mural avec 50 graphiques, pas de titre, pas d'échelle, pas de seuil. Personne ne le regarde. Les incidents sont découverts par les utilisateurs.
**Pourquoi c'est dangereux :** un dashboard sans contexte n'est pas un outil — c'est du bruit. Les anomalies sont noyées dans la masse de données non interprétables. Le MTTD est infini.
**Faire plutôt :** un dashboard par service. Titre explicite. Description : "Ce dashboard montre la santé du service X. Si ce graphique est rouge, regarder Y." Seuils visuels. Maximum 10 métriques par dashboard. Le dashboard doit permettre de répondre "est-ce que c'est normal ?" en un coup d'œil.

### Alerte sur tout
**Ce qu'on voit :** 200 alertes configurées. "CPU > 50%", "mémoire > 60%", "disque > 70%". 15 alertes par nuit. L'équipe a muté le canal. Les vraies urgences sont ignorées.
**Pourquoi c'est dangereux :** l'alert fatigue est réelle. Chaque fausse alerte entraîne la suivante vers l'ignorance. Quand une vraie alerte critique arrive, personne ne la voit parce que tout le monde a appris que "les alertes = du bruit".
**Faire plutôt :** alerter sur les SYMPTÔMES, pas sur les causes potentielles. "P95 latency > 1s pendant 5 min" (symptôme utilisateur), pas "CPU > 70%" (cause possible). Chaque alerte doit être actionable — si tu ne peux pas écrire le runbook en 3 étapes, ne crée pas l'alerte.

### Monitoring = dashboards Grafana
**Ce qu'on voit :** tout est dans Grafana. Pas de logs structurés, pas de tracing, pas d'alerting. "On regardera le dashboard si quelqu'un se plaint."
**Pourquoi c'est dangereux :** le monitoring sans observabilité, c'est regarder le tableau de bord de ta voiture. Tu vois que la vitesse est à 0, mais tu ne sais pas POURQUOI. Les dashboards montrent les symptômes, les logs et traces montrent les causes. L'un sans l'autre = tu sais que c'est cassé, pas pourquoi.
**Faire plutôt :** monitoring (métriques + dashboards + alertes) + logging (logs structurés JSON + correlation ID) + tracing (OpenTelemetry, traces distribuées). Les trois piliers de l'observabilité.

## Patterns
### RED method (services)
**Quand :** monitoring de tout service (API, worker, etc.).
**Comment :** Rate (requêtes/s), Errors (taux d'erreur), Duration (P50/P95/P99). 3 métriques par endpoint. Couvre l'expérience utilisateur. Si le Rate chute, si les Errors montent, si la Duration explose — alerter.

### USE method (ressources)
**Quand :** monitoring de toute ressource (CPU, RAM, disque, réseau, DB pool).
**Comment :** Utilization (% utilisé), Saturation (file d'attente), Errors (compteur d'erreurs). 3 métriques par ressource. Couvre la santé de l'infrastructure. Si Utilization > 80%, si Saturation > 0, si Errors > 0 — investiguer.

### SLO-based alerting
**Quand :** définir les alertes sans tomber dans l'alert fatigue.
**Comment :** définir un SLO (ex: "99.9% des requêtes < 500ms sur 30 jours"). L'alerte se déclenche quand le error budget est consommé trop vite (ex: 5% du budget mensuel en 1h), pas sur chaque dépassement ponctuel.
