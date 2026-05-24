---
paths:
  - "**/logging*"
  - "**/*Logger*"
  - "**/*log*"
  - "**/logback*"
  - "**/log4j*"
  - "**/winston*"
---

## Dispatch
- Charge `logging` AVANT de configurer les logs.
- Si les logs contiennent des PII → charge aussi `appsec`.

## Regles dures (zero tolerance)
- **Jamais** de PII/token/secret dans les logs. Scrub automatique.
- **Jamais** de `console.log` en prod. Structured logging uniquement.
- **Jamais** de log level DEBUG en prod par defaut.

## Conventions du projet
- JSON structure : `{timestamp, level, logger, message, correlationId, ...context}`.
- Correlation ID sur chaque requete — propage a tous les services.
- Log levels : ERROR (alerte), WARN (investiguer), INFO (decisions metier), DEBUG (detail).
