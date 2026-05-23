---
name: logging
description: "Logging — logs structures, niveaux de log, centralisation, retention, correlation ID, detection d'anomalies. A charger quand on configure les logs."
triggers:
  path: "**/log*,**/winston*,**/pino*,**/bunyan*,**/log4j*,**/fluentd*,**/loki*"
---

# Logging

## Checklist
- [ ] Les logs sont structures (JSON) — pas de `console.log("texte")` libre
- [ ] Un correlation ID (trace ID) traverse tous les services pour chaque requete
- [ ] Les niveaux de log sont utilises correctement (ERROR, WARN, INFO, DEBUG)
- [ ] Les erreurs contiennent le stack trace et le contexte (payload, params, userId)
- [ ] Les donnees sensibles ne sont jamais logguees (password, token, carte bancaire)
- [ ] Les logs sont centralises (Loki, ELK, Datadog, CloudWatch) — pas de `tail -f`
- [ ] La retention est definie et appliquee (hot 7j, warm 30j, cold 1 an)
- [ ] Pas de log dans les boucles critiques (perforation, volume, cout)

## Anti-patterns
### Log texte
**Ce qu'on voit :** `console.log("User logged in: " + userId + " at " + Date.now())`.
**Pourquoi c'est dangereux :** impossible de parser automatiquement. Pas de champ structure. Recherche et filtrage impossibles sans regex fragiles.
**Faire plutot :** `logger.info({ event: "user_login", userId, timestamp }, "User logged in")` — logs structures JSON. Parsables, filtrables, indexables.

### Pas de correlation ID
**Ce qu'on voit :** chaque service loggue avec son propre identifiant. Impossible de suivre une requete a travers 3 services.
**Pourquoi c'est dangereux :** debug d'un incident = ouvrir 3 terminaux, chercher manuellement des timestamps qui coincident. Impossible en microservices.
**Faire plutot :** correlation ID genere a l'entree (API Gateway ou ingress). Transmis dans chaque appel (header HTTP, message queue). Loggue dans chaque service.

### Logs sensibles
**Ce qu'on voit :** `logger.error("Payment failed", { cardNumber, cvv, userId })`.
**Pourquoi c'est dangereux :** PCI-DSS viole. Les donnees bancaires sont stockees dans les logs. En cas de fuite des logs, les cartes sont compromisees.
**Faire plutot :** `logger.error("Payment failed", { paymentId, errorCode, userId })`. Jamais de donnees sensibles (password, token, carte, secret). Masquage automatique si necessaire.

## Patterns
### Logs structures (JSON)
**Quand :** toute application.
**Comment :** chaque log est un objet JSON avec timestamp, level, message, service, correlationId, et les donnees contextuelles. Parse, filtre, et indexe par Loki/ELK. Requetable.

### Log centralise
**Quand :** application distribuee (microservices, K8s).
**Comment :** tous les logs convergent vers un endpoint central (Loki, ELK, Datadog, CloudWatch). Un seul endroit pour chercher. Requetes cross-service possibles.
