---
name: stride-analyzer
description: How to threat model with STRIDE — 3-pass methodology: risk-rank by mechanical signals, STRIDE 6 categories (Spoofing/Tampering/Repudiation/Info Disclosure/DoS/Elevation) with grep evidence, and killer checklist. For auth, DB schema, payment, security changes.
allowed-tools: Read, Grep, Glob, Bash
---

# STRIDE Threat Modeling — Security Analysis Methodology

## What this covers

How to do a security threat model using STRIDE. STRIDE is the framework; grep is the evidence. No theater — every finding needs `file:line` proof.

## Core principle

**Anti-theater rule**: every checklist item needs evidence (file:line or grep output). "Checked ✓" with no evidence = not checked.

## Pass 1: Risk rank (mechanical signals)

Classify the change:

- **Critical** if ANY: `auth/`, `security/`, DB tables (users, sessions, tokens), `.executeQuery`, `.executeUpdate`, `userId`, `password`, `token`, `secret`
- **Important** if ANY: diff > 5 files, `validate`, `sanitize`, `rateLimit`, route handlers
- **Routine** otherwise

→ Critical = all 3 passes. Important = passes 2+3. Routine = pass 3 only.

## Pass 2: STRIDE 6 categories (Critical/Important)

For each category, answer with grep-backed evidence:

| Category | Question | Evidence type |
|----------|----------|--------------|
| **S**poofing | Can I impersonate someone? | Auth checks, token validation |
| **T**ampering | Can input be modified in transit? | Input validation, integrity checks |
| **R**epudiation | Can a user deny this action? | Audit logging, timestamps |
| **I**nfo Disclosure | What leaks? | Error messages, logs, responses |
| **D**oS | Can this be flooded/exhausted? | Rate limits, resource bounds |
| **E**levation | Can I access what I shouldn't? | Authorization checks, role validation |

Each answer: grep-backed or "N/A because X". **Mark N/A explicitly, never skip silently.**

**OPS lens** (overlayed on STRIDE): unclosed connections, memory leaks, locks, behavior at 100x volume.

## Pass 3: Killer checklist (all levels)

- Same field = same validation everywhere? (grep to verify)
- Same domain = same auth on ALL transports (REST + WS + SSE)?
- Identity fields resolved server-side, never client-supplied?
- SQL parameterized, never interpolated?
- PII touched = anonymization covered?

Each item: evidence (`file:line` or grep output) or N/A.

## Output format

```
## STRIDE ANALYSIS

### Risk rank: <Critical | Important | Routine>
Signals: <list>

### STRIDE (if Critical/Important)
- S (Spoofing): <N/A because X | RISQUE: ... — evidence: file:line>
- T (Tampering): <...>
- R (Repudiation): <...>
- I (Info Disclosure): <...>
- D (DoS): <...>
- E (Elevation): <...>

OPS: <connections | memory | locks | 100x volume>

### Killer checklist
- [✓/✗] Same validation everywhere — evidence: <grep output>
- [✓/✗] Auth parity across transports — evidence: <...>
- [✓/✗] Identity server-side — evidence: <...>
- [✓/✗] SQL parameterized — evidence: <...>
- [✓/✗] PII anonymization — evidence: <...>

### VERDICT
BLOCKING: <list or none>
IMPORTANT: <list or none>
```

## How to verify

- [ ] Pass 1 (Risk rank) completed with mechanical signals?
- [ ] Pass 2 (STRIDE 6 categories) — all categories have findings or explicit "N/A because X"?
- [ ] Pass 3 (Killer checklist) completed?
- [ ] VERDICT issued (PROCEED / BLOCK / INVESTIGATE)?
- [ ] Evidence format: `file:line` or grep output?

## Key rules

- **Don't skip categories silently**: every STRIDE category gets a finding or explicit "N/A because X"
- **Evidence format**: `path/to/file.ext:123` or `grep -n "pattern" src/` output
- **Rotate stale items**: if a checklist item catches nothing in 10+ audits, consider replacing it
