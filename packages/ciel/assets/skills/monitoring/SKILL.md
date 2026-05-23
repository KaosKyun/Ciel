---
name: monitoring
description: "Monitoring — metriques, dashboards, alerting, RED, USE, SLI/SLO/SLA, observabilite. A charger quand on met en place du monitoring."
triggers:
  path: "**/prometheus*,**/grafana*,**/datadog*,**/newrelic*,**/sentry*,**/monitoring*"
---

# Monitoring

## Checklist
- [ ] Les metriques RED (Rate, Errors, Duration) sont exposees par chaque endpoint/service
- [ ] Les metriques USE (Utilization, Saturation, Errors) sont exposees par chaque ressource
- [ ] Un dashboard Grafana (ou equivalent) couvre les parcours critiques
- [ ] Les SLI (Service Level Indicators) sont definis et mesures
- [ ] Les SLO (Service Level Objectives) sont documentes et visibles
- [ ] Au moins 6 mois de retention pour les metriques (1 an pour les donnees critiques)
- [ ] Les dashboards sont documentes (quoi, pourquoi, comment lire)
- [ ] Les proxies metrics (charge, memoire, GC, pool de connexions) sont exposes

## Anti-patterns
### Dashboard sans contexte
**Ce qu'on voit :** un dashboard avec 50 graphiques, pas de titre, pas de description, pas de seuil.
**Pourquoi c'est dangereux :** personne ne comprend ce qui est surveille. Le dashboard est ignore. Les anomalies passent inapercues.
**Faire plutot :** un dashboard par service. Titre clair. Description de ce qui est attendu. Seuils visuels (vert/jaune/rouge). Instructions "si ce graphique est rouge, regarder X".

### Tout monitorer
**Ce qu'on voit :** 500 metriques par service, 20 dashboards, des alertes sur tout.
**Pourquoi c'est dangereux :** le bruit cache les signaux importants. Les vraies anomalies sont noyees dans la masse. Fatigue d'alerte.
**Faire plutot :** les metriques qui comptent : RED pour chaque endpoint, USE pour chaque ressource. Pas plus de 10 metriques critiques par service.

### Monitoring sans alerte
**Ce qu'on voit :** les metriques sont dans Grafana mais personne ne regarde. Les pannes sont detectees par les clients.
**Pourquoi c'est dangereux :** le monitoring sans alerte ne sert a rien. C'est de la data morte. L'equipe decouvre les incidents en meme temps que les utilisateurs.
**Faire plutot :** alertes sur les indicateurs critiques. P95 latency > 1s. Error rate > 1%. Disk > 80%. Pages (PagerDuty/Opsgenie) pour les alertes critiques.

## Patterns
### RED method
**Quand :** monitoring de services.
**Comment :** Rate (requetes/s), Errors (taux d'erreur), Duration (latence P50/P95/P99). Chaque endpoint expose ces 3 metriques. Dashboard dedie.

### USE method
**Quand :** monitoring de ressources (CPU, RAM, disque, reseau).
**Comment :** Utilization (% de temps occupe), Saturation (file d'attente), Errors (nombre d'erreurs). Pour chaque ressource, ces 3 metriques.
