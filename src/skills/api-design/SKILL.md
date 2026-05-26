---
name: api-design
description: "API Design — l'API comme contrat, REST/GraphQL/gRPC, pagination cursor-based, idempotency, structured errors, rate limiting. À charger quand on crée ou modifie des endpoints."
---

# API Design

**Principe premier :** Une API est un contrat entre un client et un serveur qui évoluent à des rythmes différents. Le client peut être une app mobile qui se met à jour une fois par mois, le serveur peut être déployé 10× par jour. Le design d'API est l'art de faire évoluer le contrat sans le casser. Chaque champ que tu ajoutes est un engagement, chaque champ que tu changes est une rupture. La question n'est pas "est-ce que c'est RESTful ?" mais "est-ce que le client peut survivre à 6 mois de changements serveur sans mise à jour ?"

## Checklist
- [ ] L'API est versionnée — dans l'URL (/v1/) ou le header (Accept-Version)
- [ ] Pagination cursor-based — stable, index-friendly, pas de doublon entre pages
- [ ] Les erreurs sont structurées : `{error: {code, message, details}}` — pas de `200 OK {success: false}`
- [ ] Les mutations POST/PUT/DELETE supportent l'idempotency key
- [ ] Rate limiting en place avec headers standards : `Retry-After`, `X-RateLimit-*`
- [ ] Le schéma est documenté (OpenAPI/GraphQL schema/gRPC proto) et la doc est le contrat, pas une suggestion
- [ ] Pas de breaking change sans nouvelle version ou deprecation window explicite

## Anti-patterns
### Breaking change silencieux
**Ce qu'on voit :** `{price: 10}` devient `{price: {amount: 10, currency: "EUR"}}` sur la même version d'API. Les clients mobiles qui n'ont pas été mis à jour crashent.
**Pourquoi c'est dangereux :** le client n'a aucun moyen de savoir que le contrat a changé. Il parse ce qu'il reçoit, ça casse. Le pire : ça peut arriver à 20% des utilisateurs seulement (ceux qui n'ont pas la dernière version de l'app). Le bug est invisible côté serveur.
**Faire plutôt :** nouvelle version (/v2/) avec le nouveau format. L'ancienne version (/v1/) est maintenue pendant une deprecation window (6-12 mois) avec un header `Deprecation: true` et `Sunset: <date>`. Les clients ont le temps de migrer.

### `200 OK` avec erreur dedans
**Ce qu'on voit :** toutes les réponses sont HTTP 200. Le corps contient `{success: false, error: "quelque chose"}`. Même pour une erreur 500.
**Pourquoi c'est dangereux :** HTTP a un système de codes d'erreur pour une raison. Les CDN cachent les 200. Les load balancers comptent les 5xx. Les outils de monitoring alertent sur les taux d'erreur HTTP. En faisant tout en 200, tu rends ton API invisible à toute la chaîne d'infrastructure.
**Faire plutôt :** utiliser les codes HTTP comme prévu. 201 Created, 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 409 Conflict, 422 Unprocessable, 429 Too Many Requests, 500 Internal. Le code HTTP est un signal machine-readable.

### Offset pagination
**Ce qu'on voit :** `GET /orders?page=3&limit=50` → `LIMIT 50 OFFSET 100`. À la page 100, la DB scanne 5000 rows pour en retourner 50.
**Pourquoi c'est dangereux :** deux problèmes. Performance : OFFSET N oblige la DB à scanner N rows. Cohérence : si une row est insérée entre deux pages, toutes les rows suivantes sont décalées et l'utilisateur voit des doublons ou manque des entrées.
**Faire plutôt :** cursor-based : `GET /orders?cursor=xyz&limit=50` → `WHERE id > 'xyz' ORDER BY id LIMIT 50`. Index-friendly. Stable. Pas de doublon. Le cursor est opaque pour le client.

## Patterns
### Structured errors
**Quand :** toute API.
**Comment :** `{error: {code: "INSUFFICIENT_FUNDS", message: "Solde insuffisant", details: [{field: "amount", reason: "minimum 10 EUR"}]}}`. `code` : machine-readable (switch côté client). `message` : human-readable (debug). `details` : actionable (form validation).

### Idempotency key
**Quand :** toute mutation où le double-submit est dangereux (paiements, créations).
**Comment :** header `Idempotency-Key: <uuid>`. Le serveur stocke la clé + le résultat. Même clé = même réponse, l'opération n'est exécutée qu'une fois. Stripe utilise ce pattern pour 100% de leurs mutations.

### Rate limiting avec headers
**Quand :** tout endpoint public.
**Comment :** `429 Too Many Requests` + `Retry-After: 30` + `X-RateLimit-Limit: 100` + `X-RateLimit-Remaining: 0` + `X-RateLimit-Reset: 1716000000`. Le client sait exactement quand réessayer. Pas de backoff deviné.
