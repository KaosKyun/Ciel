---
name: api-design
description: "API Design — REST, GraphQL, gRPC, versioning, pagination, idempotency, structured errors, rate limiting, schema evolution. A charger des qu'on cree ou modifie des endpoints."
---

# API Design

## Checklist
- [ ] Le endpoint est versionne (/v1/ ou header `Accept-Version`)
- [ ] La pagination est cursor-based (pas offset)
- [ ] Les erreurs sont structurees : `{code, message, details}`
- [ ] Les mutations (POST/PUT/DELETE) supportent l'idempotency key
- [ ] Le rate limiting est defini et documente
- [ ] La reponse est documentee (OpenAPI / GraphQL schema / proto comment)
- [ ] Les noms de champs sont en snake_case (API publique) ou camelCase selon convention etablie
- [ ] Pas de breaking change sans nouvelle version

## Anti-patterns
### Breaking change silencieux
**Ce qu'on voit :** `{price: 10}` devient `{price: {amount: 10, currency: "EUR"}}` sans changer de version.
**Pourquoi c'est dangereux :** tous les clients cassent en production. Aucun avertissement.
**Faire plutot :** nouvelle version d'API (/v2/). L'ancienne version (/v1/) reste 6-12 mois avec deprecation notice.

### Offset pagination
**Ce qu'on voit :** `GET /orders?page=1&limit=50` → `LIMIT 50 OFFSET 0`.
**Pourquoi c'est dangereux :** a la page 100, la DB scanne 5000 rows pour en retourner 50. Et les rows inserees entre-temps decalent tout.
**Faire plutot :** cursor-based : `GET /orders?cursor=abc123&limit=50` → `WHERE id > 'abc123' ORDER BY id LIMIT 50`. Index-friendly et stable.

### Pas d'idempotency sur les paiements
**Ce qu'on voit :** `POST /charges` sans idempotency key. Le client timeout → retry → double charge.
**Pourquoi c'est dangereux :** l'utilisateur est debite 2×. Chargeback, confiance perdue.
**Faire plutot :** header `Idempotency-Key` obligatoire. Stripe-style : meme cle = meme reponse, l'operation n'est executee qu'une fois.

### `200 OK {error: "..."}` 
**Ce qu'on voit :** toutes les reponses sont HTTP 200. Le corps contient `{success: false, error: "..."}`.
**Pourquoi c'est dangereux :** les outils de monitoring, CDN, load balancer ne voient pas les erreurs. Le cache peut stocker des erreurs.
**Faire plutot :** utiliser les codes HTTP corrects. 201 Created, 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 409 Conflict, 422 Unprocessable, 429 Too Many Requests, 500 Internal.

## Patterns
### Cursor-based pagination
**Quand :** liste ordonnee avec potentiellement beaucoup de donnees.
**Comment :** `GET /orders?cursor=abc&limit=50` → `{items: [...], nextCursor: "def", hasMore: true}`. Stable, index-friendly.

### Structured errors
**Quand :** toute erreur API.
**Comment :** `{error: {code: "INSUFFICIENT_FUNDS", message: "Solde insuffisant", details: [{field: "amount", reason: "minimum 10 EUR"}]}}`. Machine-readable (`code`), human-readable (`message`), actionable (`details`).

### Rate limiting with headers
**Quand :** tout endpoint public.
**Comment :** `429 Too Many Requests` + `Retry-After: 30` + `X-RateLimit-Limit: 100` + `X-RateLimit-Remaining: 0` + `X-RateLimit-Reset: 1716000000`.
