# security-hardening — Reference

## OWASP Top 10 2021 (relevant to 2025) — probes

### A01 — Broken Access Control

Probes:
- Is there an authorization check before every sensitive action?
- Horizontal priv escalation: can user A access user B's resources by ID manipulation?
- Vertical priv escalation: can regular user perform admin-only actions?
- CORS misconfig: `Access-Control-Allow-Origin: *` + `Allow-Credentials: true` → exfil
- Directory traversal: `../` / absolute paths in file access endpoints
- Force browsing: hidden pages accessible without auth

### A02 — Cryptographic Failures

Probes:
- Passwords hashed with bcrypt/argon2id/scrypt (NOT MD5/SHA-1/SHA-256 alone)
- Sensitive data encrypted at rest (DB, backups, logs)
- TLS 1.2+ only (1.0/1.1 disabled)
- Weak ciphers disabled
- Random values from CSPRNG (crypto/rand in Go, `SecureRandom` in Java, `crypto.randomUUID()` in Node)
- No hardcoded keys/IVs

### A03 — Injection

Probes:
- Parameterized queries (prepared statements) — grep for string concat in SQL
- Template engines with auto-escape — grep for `raw` / `safe` escape hatches
- LDAP, OS command, XPath injection — grep for user input in these contexts
- NoSQL injection — MongoDB `$where`, JS-in-query

### A04 — Insecure Design

Probes:
- Threat model exists?
- Trust boundaries documented?
- Rate limiting on abusable endpoints?

### A05 — Security Misconfiguration

Probes:
- Default accounts removed
- Error pages don't leak stack traces
- Security headers present: CSP, HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy
- Unused features disabled (debug endpoints, admin panels on public URLs)

### A06 — Vulnerable Components

Probes:
- `npm audit` / `pip-audit` / `bundle audit` / `cargo audit` run recently?
- CVEs in dependencies with known exploits?
- Dependencies pinned to specific versions (not `*` or `latest`)?

### A07 — Identification & Authentication Failures

Probes:
- Password policy: min length 12, no upper bound
- Common password dictionary check (haveibeenpwned integration)
- MFA available for sensitive accounts
- Credential stuffing protection (rate limit + captcha + anomaly detection)
- Session timeout reasonable (15min-8h depending on sensitivity)

### A08 — Software & Data Integrity Failures

Probes:
- CI/CD pipeline integrity (signed commits, protected branches)
- Deserialization of untrusted data (Java ObjectInputStream, Python pickle, PHP unserialize)
- Auto-update verifies signatures
- SBOM generated and reviewed

### A09 — Logging & Monitoring Failures

Probes:
- Logging in place for: logins (success + failure), authorization failures, admin actions, high-value transactions
- Log format structured (JSON), not line-based
- PII not logged (passwords, tokens, full credit card)
- Logs shipped to remote immutable store

### A10 — SSRF

Probes:
- Outbound URL fetch accepts user input?
- URL validation: scheme whitelist (https only?), IP allowlist/blocklist
- Block cloud metadata endpoints (169.254.169.254, localhost)
- DNS rebinding protection

## JWT — auth flow anti-patterns

- `alg: none` accepted → signature bypass
- Weak HS256 secret (guessable) → forge tokens
- No `exp` claim → tokens live forever
- No `iss`/`aud` validation → tokens from other services accepted
- Stored in localStorage → accessible by XSS
- Refresh token stored in localStorage → same risk
- Refresh token never rotated → long-lived compromise

Recommended:
- RS256 (asymmetric) with key in HSM/KMS
- Short access token (15 min)
- Refresh token rotation (new on every use)
- Refresh in HttpOnly, Secure, SameSite cookie
- Revocation list or short-lived tokens only

## OAuth / OIDC flows

| Flow | Use case |
|------|----------|
| Authorization Code + PKCE | Web apps, mobile, SPAs (with PKCE) |
| Client Credentials | Service-to-service, no user |
| Device Code | TVs, CLIs, no-keyboard devices |
| Resource Owner Password | **Avoid** — requires passing password to client |
| Implicit | **Deprecated** — use Auth Code + PKCE |

PKCE (S256): mandatory for public clients.

State parameter: always include, validate on callback (CSRF).

## Session management

- Session ID: 128+ bits of entropy, CSPRNG
- Session ID regenerated on login (prevents fixation)
- Logout invalidates server-side session (don't rely on client deletion)
- Concurrent session limit per user
- Inactive timeout (15min for sensitive, 8h for normal)
- Absolute timeout (24h max even with activity)

Cookie flags: `HttpOnly`, `Secure`, `SameSite=Lax` (or Strict for very sensitive)

## Password policy

Current best practice (NIST SP 800-63B):
- Min 8 chars, but recommend 12+
- NO max (or at least 64+)
- Allow all printable chars including spaces
- NO forced complexity (upper/lower/digit/symbol)
- NO periodic forced rotation (only on compromise)
- Check against compromised password list (HIBP API)

## Cryptography — pick one

| Need | Pick |
|------|------|
| Password hashing | argon2id > bcrypt > scrypt |
| Symmetric encryption | AES-256-GCM |
| Asymmetric encryption | RSA-OAEP-256 or ECIES |
| Signatures | Ed25519 (fast) or ECDSA P-256 |
| KDF | Argon2id, PBKDF2-SHA256 with 600k+ iters |
| MAC | HMAC-SHA256 |
| Random | Platform CSPRNG (NOT `Math.random`) |

Never: MD5 (anywhere), SHA-1, ECB mode, DES, RC4, custom.

## Secrets

- Rotated on leak (assume leak when in doubt)
- Per-environment (dev secret ≠ prod secret)
- In memory only (or on-demand from secret manager)
- NOT in code, NOT in env files committed to git, NOT in client-side bundles

Tools: Vault, AWS Secrets Manager, GCP Secret Manager, Doppler, 1Password Secret References.

Detection: gitleaks, trufflehog on git history. Run in CI.

## PII / GDPR considerations

- Minimum data collection (YAGNI applies)
- Retention policy documented and enforced (auto-delete after N days)
- Right to deletion implemented
- Data portability (export in structured format)
- Anonymization for logs / analytics (hash emails, truncate IPs)
