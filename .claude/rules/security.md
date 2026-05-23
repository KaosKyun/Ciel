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

## Dispatch
- Charge `appsec` AVANT d'ecrire du code d'auth ou de crypto.
- Si tu touches des tokens/sessions → charge aussi `crypto`.
- Si le fichier est dans `.github/workflows/` → charge aussi `devsecops` + `supply-chain`.

## Regles dures (zero tolerance)
- **Jamais** de secret, token, cle API, mot de passe dans le code. Env vars ou secret manager.
- **Jamais** de `import { random }` pour la crypto. Toujours `crypto.randomBytes` ou equivalent.
- **Jamais** de `bcrypt.compare` sans `await`. Un `== true` oublie = tous les comptes ouverts.

## Conventions du projet
- Hachage mots de passe : bcrypt ou argon2. Jamais MD5/SHA1.
- Chiffrement : AES-256-GCM ou ChaCha20-Poly1305. Jamais ECB.
- JWT : RS256 ou ES256. Pas de `secret: "mon-super-secret"`.
- Les cles tournent automatiquement (max 90 jours).
- Log scrubbing : jamais de PII/token/secret dans les logs.
