---
paths:
  - "**/auth/**"
  - "**/security/**"
  - "**/*Token*"
  - "**/*Password*"
  - "**/*Secret*"
  - "**/*Session*"
  - "**/*Crypto*"
  - "**/*Credential*"
  - "**/encrypt*"
  - "**/cipher*"
---

## Security & Crypto

- Zero secret dans le code — variables d'environnement ou secret manager
- Requetes SQL/NoSQL parametrees — jamais de concatenation
- Mots de passe haches avec bcrypt/argon2 (pas MD5, pas SHA1)
- Chiffrement: AES-256-GCM ou ChaCha20-Poly1305 — pas d'AES-ECB
- TLS >= 1.2 partout, certificats auto-renouveles
- Input validation a la frontiere, OWASP Top 10 en tete
- Rate limiting sur login et endpoints sensibles
- Cles rotatees automatiquement (max 90 jours)
- Ne jamais logger tokens, secrets, ou mots de passe

Pour anti-patterns et patterns detailles, charger `appsec` ou `crypto`.
