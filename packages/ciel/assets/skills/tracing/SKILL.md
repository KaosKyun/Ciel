---
name: tracing
description: "Tracing — distributed tracing, spans, traces, OpenTelemetry, Jaeger, Zipkin, instrumentation. A charger quand on trace les requetes distribuees."
---

# Tracing

## Checklist
- [ ] OpenTelemetry est configure (couche d'observabilite standard)
- [ ] Chaque requete a un trace ID propage a travers tous les services
- [ ] Les spans critiques ont des attributs pertinents (DB query, HTTP method/URL, cache key)
- [ ] Les temps de chaque span sont mesures (duree reelle, pas de clock sync)
- [ ] Les erreurs sont capturees dans les spans (statut, message, stack trace)
- [ ] L'echantillonnage est configure (100% en staging, 1-10% en production)
- [ ] Les traces sont visibles dans un backend (Jaeger, Zipkin, Grafana Tempo, Datadog)

## Anti-patterns
### Pas de tracing
**Ce qu'on voit :** l'application n'a que des logs. Pour debug une requete lente, on regarde les timestamps dans les logs manuellement.
**Pourquoi c'est dangereux :** un appel qui traverse 5 services prend des heures a debugger. Impossible de savoir ou est le goulot. 5 logs, 5 timestamps, a aligner a la main.
**Faire plutot :** OpenTelemetry + Jaeger/Tempo. Une trace montre le temps dans chaque service. Le goulot est visible en un coup d'oeil.

### Sampling mal configure
**Ce qu'on voit :** 100% des requetes sont tracees en production. 50 000 req/s = 50 000 traces/s. Cout de stockage x10.
**Pourquoi c'est dangereux :** la facture d'observabilite explose. Le backend de traces sature. Les traces utiles sont noyees.
**Faire plutot :** head-based sampling : 100% en staging, 1-10% en production. Tail-based sampling pour les erreurs (toujours capturees). Ajuster selon le volume.

### Pas de baggage
**Ce qu'on voit :** chaque service doit parser le header de tracing et recreer le contexte manuellement.
**Pourquoi c'est dangereux :** l'instrumentation est fragile. Un oubli et la trace est cassee. Le contexte est perdu entre les services.
**Faire plutot :** OpenTelemetry Context Propagation automatique. Le SDK propage le contexte via les headers HTTP, les messages de queue, les appels gRPC.

## Patterns
### OpenTelemetry
**Quand :** toute application distribuee.
**Comment :** SDK OpenTelemetry instrumente automatiquement (HTTP, gRPC, DB, queue). Spans avec attributs. Export vers Jaeger, Tempo, ou Datadog. Standard ouvert.

### Trace-driven debugging
**Quand :** incident de performance ou d'erreur distribue.
**Comment :** la trace montre le chemin complet de la requete. Identifier le span le plus lent. Ajouter des attributs pour enrichir. Utiliser les traces pour les runbooks.
