---
paths:
  - "**/monitoring*"
  - "**/grafana*"
  - "**/prometheus*"
  - "**/alert*"
  - "**/logging*"
---

## Monitoring & Observability

- RED metrics par endpoint: Rate, Errors, Duration (P50/P95/P99)
- USE metrics par ressource: Utilization, Saturation, Errors
- Logs structures JSON avec correlation ID
- Pas de log de PII (emails, tokens, secrets) — scrubbing obligatoire
- Alertes sur les signaux critiques (pas sur tout) — P95 > 1s, Errors > 1%, Disk > 80%
- Dashboard documente: quoi, pourquoi, seuils visuels (vert/jaune/rouge)
- Distributed tracing sur les requetes multi-services
- SLO/SLI definis et visibles
- Runbook pour chaque alerte (quoi faire)

Pour anti-patterns et patterns detailles, charger `monitoring`, `logging`, `tracing` ou `alerting`.
