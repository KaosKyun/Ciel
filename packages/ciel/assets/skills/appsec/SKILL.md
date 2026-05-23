---
name: appsec
description: "Application Security — OWASP Top 10, injection, XSS, CSRF, auth, session, input validation, rate limiting. A charger quand on securise une application."
---

# Application Security

## Checklist
- [ ] Toutes les entrees utilisateur sont validees et assainies (input validation)
- [ ] Les requetes SQL/NoSQL sont parametrees (pas de concatenation)
- [ ] L'authentification utilise des mecanismes eprouves (OAuth2, OpenID Connect, SAML)
- [ ] Les sessions sont protegees (HttpOnly, Secure, SameSite, rotation d'ID)
- [ ] CSRF protege sur toutes les mutations (token, SameSite=Strict, double submit)
- [ ] Rate limiting configure sur les endpoints critiques (login, API, upload)
- [ ] Les headers de securite sont presents (CSP, HSTS, X-Frame-Options, X-Content-Type-Options)
- [ ] Les mots de passe sont haches avec un algorithme lent (bcrypt, argon2)

## Anti-patterns
### Input jamais valide
**Ce qu'on voit :** `const query = "SELECT * FROM users WHERE id = " + req.params.id` — injection SQL directe.
**Pourquoi c'est dangereux :** un attaquant peut passer `1; DROP TABLE users` et detruire la base. L'injection est l'attaque #1 du Top 10 OWASP.
**Faire plutot :** requetes parametrees (`WHERE id = $1`), ORM, ou query builder. Jamais de concatenation. Valider le type (`parseInt`, `z.string()`).

### Auth maison
**Ce qu'on voit :** `const token = jwt.sign({userId: user.id}, process.env.SECRET)` — JWT custom sans refresh, sans blacklist.
**Pourquoi c'est dangereux :** le JWT ne peut pas etre revoque. Si vole, l'attaquant a un acces permanent. Pas de rotation, pas de detection.
**Faire plutot :** OAuth2 ou OpenID Connect avec des providers eprouves (Auth0, Clerk, NextAuth). Access token court (15 min) + refresh token long (7 jours). Blacklist cote serveur.

### Rate limiting absent
**Ce qu'on voit :** `POST /login` peut etre appele 10 000 fois par seconde sans limitation.
**Pourquoi c'est dangereux :** brute-force du mot de passe, DDoS sur l'API, epuisement des ressources. L'application tombe.
**Faire plutot :** rate limiting sur toutes les routes : 5 req/s pour login, 100 req/s pour API, 1 req/s pour upload. Retourner 429 Too Many Requests.

## Patterns
### OWASP Top 10
**Quand :** toute application web.
**Comment :** passer en revue le Top 10 OWASP a chaque release. Les plus critiques : injection, broken auth, XSS, insecure deserialization, SSRF. Automatiser avec un scanner.

### Defense in depth
**Quand :** toute application manipulant des donnees sensibles.
**Comment :** plusieurs couches : WAF (filtre les attaques connues) → Input validation → Auth → SQL parametre → CSP (empeche XSS) → Encryption au repos. Chaque couche protege si la precedente echoue.
