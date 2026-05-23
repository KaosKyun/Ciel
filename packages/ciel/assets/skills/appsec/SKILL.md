---
name: appsec
description: "Application Security — OWASP Top 10, defense in depth, auth (OAuth2/OIDC), input validation, session security. À charger quand on sécurise une application."
---

# Application Security

**Principe premier :** La sécurité applicative n'est pas une feature — c'est une propriété émergente d'un système où chaque couche suppose que celle d'avant a échoué. Si ton input validation compte sur le WAF, et que ton WAF compte sur le framework, personne ne valide vraiment. La défense en profondeur n'est pas "plusieurs couches" — c'est "chaque couche traite l'input comme hostile, même si une autre couche est censée l'avoir déjà nettoyé". Assume breach à chaque étage.

## Checklist
- [ ] Toutes les entrées utilisateur sont validées à la frontière — type, longueur, charset, range
- [ ] Requêtes SQL/NoSQL paramétrées — jamais de concaténation (injection)
- [ ] Authentification via OAuth2/OIDC avec providers éprouvés — pas d'auth maison
- [ ] Sessions : HttpOnly, Secure, SameSite=Lax, rotation d'ID après login
- [ ] CSRF protégé sur toutes les mutations (SameSite + token si nécessaire)
- [ ] Rate limiting sur TOUS les endpoints sensibles (login, API, upload, reset password)
- [ ] Headers de sécurité : CSP, HSTS, X-Frame-Options, X-Content-Type-Options
- [ ] Mots de passe hashés avec argon2id (pas de SHA, pas de MD5)

## Anti-patterns
### Auth maison
**Ce qu'on voit :** `const token = jwt.sign({userId}, SECRET)` — JWT sans expiration, sans refresh, sans blacklist. Le token volé = accès permanent.
**Pourquoi c'est dangereux :** l'authentification est le problème de sécurité le plus résolu — et le plus mal implémenté. Un JWT mal configuré n'a pas de révocation possible. Si l'attaquant vole un token, il a un accès permanent. Construire son propre système d'auth est la cause #1 des failles critiques.
**Faire plutôt :** OAuth2/OIDC via un provider éprouvé (Auth0, Clerk, NextAuth, Keycloak). Access token courte durée (15 min), refresh token longue durée (7j) avec rotation. Blacklist côté serveur pour les tokens révoqués.

### Validation "plus tard"
**Ce qu'on voit :** les données arrivent dans le controller, passent dans le service, arrivent dans la DB sans validation. "Le frontend valide". "L'ORM échappe".
**Pourquoi c'est dangereux :** le frontend est sous le contrôle de l'attaquant. Un simple `curl` contourne toute validation frontend. L'ORM échappe le SQL mais ne valide pas le type, la longueur, le charset, le business logic. Sans validation à la frontière, la DB reçoit n'importe quoi.
**Faire plutôt :** validation à l'entrée de l'API (middleware/guard). Schéma (Zod, JSON Schema, Pydantic). Rejeter tout ce qui ne matche PAS le schéma — ne pas essayer de "corriger". Whitelist, pas blacklist.

### Rate limiting absent
**Ce qu'on voit :** `POST /login` sans rate limiting. Un attaquant brute-force 10 000 mots de passe par seconde.
**Pourquoi c'est dangereux :** le brute-force est l'attaque la plus simple et la plus efficace. Sans rate limiting, un mot de passe faible tombe en minutes. Le rate limiting n'est pas une feature — c'est la seule défense contre l'énumération.
**Faire plutôt :** rate limiting sur /login (5 tentatives/min/IP + compte), /api (100 req/s par clé), /reset-password (1 tentative/min/email). Retourner 429 avec `Retry-After`. Bloquer (pas juste ralentir) après N échecs.

## Patterns
### Defense in depth
**Quand :** toute application manipulant des données sensibles.
**Comment :** WAF → Input validation → Auth → Authorization → SQL paramétré → Output encoding → CSP → Encryption at rest. Chaque couche suppose que les précédentes ont failli. Exemple : même avec du SQL paramétré, valider le type de l'input avant. Même avec HTTPS, marquer les cookies Secure.

### Structured security review (OWASP Top 10)
**Quand :** à chaque release ou changement majeur.
**Comment :** passer en revue le Top 10 OWASP pour CHAQUE endpoint critique. Injection, Broken Auth, Sensitive Data Exposure, XXE, Broken Access Control, Security Misconfiguration, XSS, Insecure Deserialization, Vulnerable Components, Insufficient Logging. Pas un audit annuel — une habitude de release.
