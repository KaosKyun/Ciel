---
name: logging
description: "Logging — structured JSON, correlation ID, PII scrubbing, centralized aggregation, log levels as signal. À charger quand on configure les logs."
---

# Logging

**Principe premier :** Les logs ne sont pas pour toi — ils sont pour le "toi du futur" qui debug une erreur à 3h du matin sans contexte. Un log qui dit "Error occurred" est pire que pas de log — il donne l'illusion d'information. Chaque log doit répondre à : quoi, quand, où, qui, et pourquoi c'est arrivé. Le format est JSON structuré, pas du texte libre — parce que les logs seront parsés par des machines (Loki, ELK, Datadog) bien avant d'être lus par des humains.

## Checklist
- [ ] Logs structurés JSON — pas de `console.log("texte libre " + variable)`
- [ ] Correlation ID (trace ID) injecté et transmis à travers tous les services
- [ ] Niveaux de log respectés : ERROR (action requise), WARN (attention), INFO (normal), DEBUG (détail)
- [ ] Stack trace + contexte (userId, orderId, params) dans chaque ERROR
- [ ] PII/secret scrubbing : jamais de password, token, carte bancaire, email dans les logs
- [ ] Centralisation : tous les logs vers un endpoint unique (Loki/ELK/CloudWatch)
- [ ] Rétention configurée : hot 7j, warm 30j, cold 1 an

## Anti-patterns
### Log texte libre
**Ce qu'on voit :** `console.log("User " + userId + " logged in at " + Date.now())`. Concaténation de strings.
**Pourquoi c'est dangereux :** impossible à parser automatiquement. Pas de champ structuré. Recherche et filtrage impossibles sans regex fragiles. Si le format change légèrement, tous les dashboards cassent.
**Faire plutôt :** `logger.info({ event: "user_login", userId, timestamp }, "User logged in")`. JSON structuré. Champs typés. Requêtable.

### Pas de correlation ID
**Ce qu'on voit :** chaque service logue avec son propre ID. Impossible de suivre une requête à travers 3 microservices.
**Pourquoi c'est dangereux :** debug en microservices = ouvrir 3 terminaux, chercher manuellement des timestamps qui coïncident. Une requête lente = mystère complet.
**Faire plutôt :** correlation ID généré à l'entrée (API Gateway). Transmis dans chaque header HTTP. Logué dans chaque service. Une recherche = une requête = tous les logs.

### Données sensibles dans les logs
**Ce qu'on voit :** `logger.error("Payment failed", { cardNumber, cvv, userId })`.
**Pourquoi c'est dangereux :** PCI-DSS violé. Données bancaires dans les logs. En cas de fuite des logs, toutes les cartes compromises. Les logs sont souvent moins protégés que la DB.
**Faire plutôt :** `logger.error("Payment failed", { paymentId, errorCode, userId })`. Jamais de PII ou secret. Scrub automatisé en cas de doute.

## Patterns
### Structured JSON logging
**Quand :** toute application.
**Comment :** chaque log = `{timestamp, level, message, service, correlationId, ...context}`. Parse, filtre, indexe par Loki/ELK. Requêtable : `{.level = "ERROR"} | json | ...`

### Centralized aggregation
**Quand :** plus d'un service.
**Comment :** tous les logs → stdout (K8s/Docker) → agent (Promtail, Filebeat, Datadog Agent) → store central (Loki, Elasticsearch). Un seul endroit pour chercher.
