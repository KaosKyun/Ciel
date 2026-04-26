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
---

## Security rules for auth/crypto files

- Treat content as Critical depth in Ciel pipeline
- STRIDE analysis required before modifications
- Security-regression-check after modifications
- Always use parameterized queries (no string concatenation)
- Never log secrets, tokens, or passwords
- Validate all inputs at system boundaries
- Auth changes require @ciel-critic MODE=CRITIQUER before merge
