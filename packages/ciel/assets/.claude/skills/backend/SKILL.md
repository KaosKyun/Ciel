---
name: backend
description: "Backend — graceful degradation, connection pooling, idempotency, error handling as contract, health checks. À charger quand on crée ou modifie des services backend."
---

# Backend

**Principe premier :** Le backend n'est pas "la partie qui parle à la base de données" — c'est un composant dans un système distribué qui doit survivre à la défaillance de tout ce qui l'entoure. La DB tombe, le réseau coupe, le client timeout. Un backend bien conçu ne crash pas — il dégrade, il retry, il informe. La métrique n'est pas "uptime" mais "MTTR" — chaque seconde entre la panne et la récupération est du temps utilisateur perdu.

## Checklist
- [ ] Chaque endpoint a un timeout explicite — pas de requête pendante infinie
- [ ] Graceful shutdown : SIGTERM → stop accepter → drainer les requêtes (max 30s) → close connexions → exit
- [ ] Health check exposé : liveness (suis-je vivant ?) ≠ readiness (puis-je servir ?)
- [ ] Connection pooling sur DB, Redis, et clients HTTP — pas de connexion unique
- [ ] Les erreurs sont structurées : `{code, message, details}` — jamais de stack trace en prod
- [ ] Rate limiting en place sur les endpoints publics — pas de "on verra plus tard"

## Anti-patterns
### Avaler les erreurs
**Ce qu'on voit :** `try { await db.query() } catch (e) { console.log(e) }`. Pas de rethrow, pas de fallback. L'erreur est loguée et oubliée.
**Pourquoi c'est dangereux :** l'appelant reçoit "success" mais rien n'a été fait. Le système continue dans un état incohérent. Les erreurs avalées sont impossibles à debugger — tu ne sais jamais quelles opérations ont réellement échoué.
**Faire plutôt :** soit gérer l'erreur (retry, fallback, compensation), soit la laisser remonter à un error handler global qui la transforme en réponse structurée. Ne jamais avaler silencieusement.

### Graceful shutdown = process.exit(0)
**Ce qu'on voit :** `process.on('SIGTERM', () => process.exit(0))` — les 50 requêtes en cours sont coupées net. Le load balancer envoie encore du trafic vers une instance zombie.
**Pourquoi c'est dangereux :** perte de données, transactions incomplètes, expérience utilisateur dégradée. Le load balancer détecte la panne 30 secondes plus tard — pendant ce temps, toutes les requêtes échouent.
**Faire plutôt :** SIGTERM → le load balancer retire l'instance (health check fail) → l'instance arrête d'accepter les nouvelles requêtes → attend la fin des requêtes en cours (timeout 30s max) → close les connexions DB/Redis → exit. Kubernetes donne 30s par défaut (terminationGracePeriodSeconds).

### Une connexion DB pour tout le monde
**Ce qu'on voit :** `const db = new Database(DATABASE_URL)` — un singleton connexion pour toute l'application. 100 requêtes simultanées = 99 en file d'attente.
**Pourquoi c'est dangereux :** la connexion unique est le bottleneck. Les requêtes s'empilent, la latence explose. Sous charge, l'app devient non-réactive. Une seule requête lente bloque tout le monde.
**Faire plutôt :** connection pool. min/max configurés selon la charge attendue (min: 2, max: 20). Monitorer les métriques du pool : waiting, idle, active. Si `waiting > 0` régulièrement, augmenter le max ou optimiser les requêtes.

## Patterns
### Middleware chain
**Quand :** logique transversale (auth, logging, rate limiting, CORS).
**Comment :** chaque middleware fait UNE chose. Ordre canonique : CORS → rate limit → auth → validation → handler → error handler. La requête traverse la chaîne dans l'ordre, l'erreur remonte dans l'ordre inverse.

### Idempotency token
**Quand :** opérations mutantes (paiement, création de ressource) où le double-submit est dangereux.
**Comment :** le client génère un `Idempotency-Key: uuid`. Le serveur stocke la clé + le résultat de l'opération dans une transaction. Si la clé est déjà vue → retourner le résultat stocké sans ré-exécuter.
