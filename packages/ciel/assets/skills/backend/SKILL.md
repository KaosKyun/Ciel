---
name: backend
description: "Backend — middleware, auth guards, background jobs, graceful shutdown, error handling. A charger quand on cree ou modifie des services backend."
---

# Backend

## Checklist
- [ ] Chaque endpoint a un timeout explicite (pas d'attente infinie)
- [ ] Les erreurs sont structurees : `{code, message, details}`
- [ ] Graceful shutdown : SIGTERM → drain des requetes en cours → close DB → exit
- [ ] Health check : `GET /health` → `{status: "ok", db: "connected", uptime: 3600}`
- [ ] Connection pooling est configure (DB, Redis, HTTP clients)
- [ ] Les background jobs sont idempotents et monitorables
- [ ] Rate limiting est en place sur les endpoints publics
- [ ] Les inputs sont valides a la frontiere (jamais dans la logique metier)

## Anti-patterns
### Avaler les erreurs
**Ce qu'on voit :** `try { await db.query(...) } catch (e) { console.log(e) }` sans rethrow ni gestion.
**Pourquoi c'est dangereux :** l'erreur disparait. L'utilisateur voit "success" alors que rien n'a ete fait. La DB est inconsistante.
**Faire plutot :** soit gerer l'erreur explicitement (retry, fallback, rollback), soit la laisser remonter avec un error handler global.

### Pas de graceful shutdown
**Ce qu'on voit :** `process.on('SIGTERM', () => process.exit(0))` — les requetes en cours sont coupees.
**Pourquoi c'est dangereux :** perte de donnees. Le load balancer continue d'envoyer du trafic vers une instance qui ne repond plus.
**Faire plutot :** SIGTERM → arreter d'accepter les nouvelles requetes → attendre que les requetes en cours finissent (max 30s) → fermer les connexions → exit.

### Une seule DB connection
**Ce qu'on voit :** `const db = new Database(process.env.DATABASE_URL)` — une connexion pour toute l'app.
**Pourquoi c'est dangereux :** 100 requetes simultanees = 99 en attente. La connexion sature.
**Faire plutot :** connection pool avec min/max. Ex: `pg.Pool({min: 2, max: 20})`. Monitorer le pool (waiting, idle, active).

## Patterns
### Middleware chain
**Quand :** logique transversale (auth, logging, rate limiting, CORS).
**Comment :** chaque middleware fait une chose. Ordre : CORS → rate limit → auth → validation → handler → error handler.

### Idempotency
**Quand :** operations mutantes (POST/PUT/DELETE) qui ne doivent pas etre executees 2×.
**Comment :** client envoie `Idempotency-Key: <uuid>`. Serveur stocke cle + resultat. Si cle deja vue → retourner resultat stocke.

### Background job
**Quand :** operation lourde qui n'a pas besoin d'etre synchrone (email, export, resizing).
**Comment :** file d'attente (BullMQ, SQS). Job = {type, payload, maxRetries}. Worker = process job + ACK/NACK.
