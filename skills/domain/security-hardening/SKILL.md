---
name: security-hardening
description: Expert knowledge on OWASP Top 10, authentication flows, session management, cryptography pitfalls, secrets hygiene, and STRIDE case library. Auto-activates on auth/, security/, Token, Password, Secret files. Invoked in parallel with researcher on Critical tasks involving credentials, identity, or data sensitivity.
allowed-tools: Read, Grep, WebFetch
paths: "**/auth/**,**/security/**,**/*{Token,Password,Secret,Credential,Session}*,**/crypto/**"
---

# security-hardening — Security expert knowledge

Applied in parallel with `researcher` when security-sensitive work detected. Contributes OWASP case library + auth-flow anti-patterns.

Complements (doesn't replace) `stride-analyzer` — STRIDE is the framework, this skill is the expert pattern library.

For OWASP Top 10 probes and auth flow cheatsheets, see `reference.md`.

---

## Inputs

```
TASK: [1-sentence description]
FILES_IN_SCOPE: [list of files involved]
SENSITIVITY: [credentials | session | PII | payment | general]
```

---

## Process

### 1. Map task to threat class

- Credentials? → password hashing, rotation, leak detection, brute-force
- Session? → revocation, hijacking, fixation, timeout
- Auth flow? → OAuth / OIDC / JWT — token lifecycle, refresh, revocation
- PII? → at-rest encryption, access logs, anonymization, retention
- Payment? → PCI DSS scope, tokenization, webhook verification

### 2. Apply OWASP Top 10 probes

Check against the current OWASP Top 10 (2021 + 2025 ASVS):
- A01: Broken Access Control
- A02: Cryptographic Failures
- A03: Injection
- A04: Insecure Design
- A05: Security Misconfiguration
- A06: Vulnerable Components
- A07: Identification & Authentication Failures
- A08: Software & Data Integrity Failures
- A09: Logging & Monitoring Failures
- A10: SSRF

### 3. Auth flow anti-patterns (specific probes)

- JWT `none` algorithm accepted
- Token stored in localStorage (XSS exposed)
- Refresh token never rotated
- Session fixation (accept any session ID)
- No rate limit on login / signup
- Password reset token reusable
- Timing attack on user existence check

### 4. Cryptography pitfalls

- MD5/SHA-1 for passwords (use bcrypt/argon2id)
- Static IV for AES
- ECB mode
- Own crypto implementation
- Secret in code / environment file committed
- Key derivation without salt

### 5. Secrets hygiene

- Grep for: API keys, tokens, passwords in commit history
- `.env` / `.env.local` in `.gitignore`
- Secrets manager (Vault, AWS Secrets, Doppler) vs env vars

---

## Output format

```
## SECURITY DOMAIN INSIGHTS

### Threat class
- <credentials | session | PII | payment | general>

### OWASP probes run
- A01 Access Control: <finding or N/A>
- A02 Cryptographic Failures: <...>
- ... (only relevant categories)

### Auth flow checks
- <check> — <status>

### Crypto checks
- <check> — <status>

### Secrets hygiene
- Repo scan: <clean | found: ...>
- Manager: <configured | using env vars>

### CROSS-REFERENCES
- Reinforces stride-analyzer findings: <list>
- Conflicts with researcher findings: <none | list>
```

---

## Guardrails

- **Never ship custom crypto** — use library primitives
- **Password hashing non-negotiable**: bcrypt / argon2id / scrypt. MD5/SHA for passwords is an incident.
- **Always rate-limit auth endpoints**: login, signup, password reset, 2FA verification
- **PII requires retention policy**: can't just store forever
- **Secrets in code = leak**: once committed, considered exposed; rotate immediately

---

## How to verify

- [ ] OWASP Top 10 probes run for relevant categories?
- [ ] Auth flow checks: JWT storage, token rotation, rate limiting?
- [ ] Crypto: bcrypt/argon2id for passwords, no MD5/SHA-1?
- [ ] Secrets: grep for API keys/tokens in code and history?
- [ ] `.env` in `.gitignore`?
- [ ] No custom crypto implementations?

## When triggered

- `explorer` agent parallel dispatch on Critical tasks touching auth/security
- Task mentions: login, logout, password, JWT, OAuth, session, encryption, 2FA
- `paths` glob on auth/, security/, Token/Password/Secret names
