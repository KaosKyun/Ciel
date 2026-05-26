---
name: tracing
description: "Tracing — OpenTelemetry, distributed traces, spans, sampling, context propagation. À charger quand on met en place du tracing distribué."
---

# Tracing

**Principe premier :** Le tracing n'est pas "du monitoring avec plus de détails" — c'est le seul outil qui te permet de voir une requête traverser 5 services et identifier lequel a pris 90% du temps. Sans tracing, chaque service est une boîte noire. Avec tracing, tu as un diagramme de séquence généré automatiquement. OpenTelemetry est le standard — ne pas utiliser de solution propriétaire.

## Checklist
- [ ] OpenTelemetry SDK configuré dans chaque service — pas de vendor lock-in
- [ ] Chaque requête entrante génère un span racine avec trace ID unique
- [ ] Les appels sortants (HTTP, DB, Redis, queue) créent des spans enfants
- [ ] Le contexte de trace est propagé automatiquement (W3C Trace Context headers)
- [ ] Sampling configuré : 100% en dev/staging, sampling adaptatif en prod
- [ ] Les spans contiennent les attributs clés : service, endpoint, userId, status code

## Anti-patterns
### Tracing = logs améliorés
**Ce qu'on voit :** des spans manuelles `span.setAttribute("message", "processing order")` — comme des logs déguisés.
**Pourquoi c'est dangereux :** le tracing n'est pas du logging. Son pouvoir vient de l'automatisme : les spans sont créées automatiquement par l'instrumentation, pas manuellement par le dev. Des spans manuelles = du bruit.
**Faire plutôt :** laisser l'auto-instrumentation créer les spans (HTTP, DB, gRPC). Ajouter manuellement UNIQUEMENT les spans qui représentent des étapes métier importantes (OrderProcessing, PaymentValidation).

### Pas de sampling
**Ce qu'on voit :** 100% des traces en production. 10 millions de spans/heure. Coût du stockage x10.
**Pourquoi c'est dangereux :** coût et volume. La plupart des traces normales n'apportent rien. Seules les traces lentes et les traces avec erreurs sont utiles en prod.
**Faire plutôt :** sampling adaptatif : 100% des traces avec erreur ou > P95. 10% des traces normales. Assez pour voir les patterns, pas assez pour exploser le budget.

## Patterns
### OpenTelemetry auto-instrumentation
**Quand :** tout service en production.
**Comment :** importer le SDK OTel. Auto-instrumentation pour HTTP, DB, gRPC, queues. Zéro code pour les spans de base. Export vers Jaeger/Tempo/Honeycomb. Standard ouvert — change de backend sans changer le code.

### Span attributes
**Quand :** chaque span.
**Comment :** `service.name`, `http.method`, `http.status_code`, `db.system`, `user.id` (pas de PII). Assez pour filtrer et grouper, pas assez pour identifier une personne.
