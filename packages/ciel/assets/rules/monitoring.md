---
paths:
  - "**/metrics*"
  - "**/*Metrics*"
  - "**/health*"
  - "**/*Health*"
  - "**/dashboards/**"
  - "**/alerts*"
  - "**/prometheus*"
  - "**/grafana*"
---

## Dispatch
- Charge `monitoring` AVANT de configurer des metriques ou alertes.
- Si les alertes sont pour la securite → charge aussi `appsec`.

## Regles dures (zero tolerance)
- **Jamais** d'alerte sans runbook. Chaque alerte a un lien vers la procedure.
- **Jamais** de metrique sans cardinalite bornee. Pas de user ID comme label.
- **Jamais** de `alert: always` sans fenetre de silence.

## Conventions du projet
- RED metrics pour les services : Rate, Errors, Duration.
- USE metrics pour l'infra : Utilization, Saturation, Errors.
- Dashboards : 4 golden signals (latency, traffic, errors, saturation).
