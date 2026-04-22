---
description: Security threat model using STRIDE — 3 passes (RISK-RANK, STRIDE 6 cats, KILLER CHECKLIST)
---

# stride-analyzer — Security threat model

Step 4 of CRÉER (Critical only). The security auditor. STRIDE is the framework; grep is the evidence.

---

## 3-pass process

### PASSE 1 — RISK-RANK (mechanical signals)

Classify the change:

- **Critical** if ANY: `auth/`, `security/`, DB tables (users, sessions, tokens), `.executeQuery`, `.executeUpdate`, `userId`, `password`, `token`, `secret`
- **Important** if ANY: diff > 5 files, `validate`, `sanitize`, `rateLimit`, route handlers
- **Routine** otherwise

→ Critical = all 3 passes. Important = passes 2+3. Routine = pass 3 only.

### PASSE 2 — STRIDE 6 categories (Critical/Important)

For each category, answer with evidence:

- **S**poofing — can I impersonate someone?
- **T**ampering — can input be modified in transit?
- **R**epudiation — can a user deny this action?
- **I**nfo Disclosure — what leaks (errors, logs, responses)?
- **D**oS — can this be flooded/exhausted?
- **E**levation — can I access what I shouldn't?

Each answer: `grep`-backed or "N/A because X". **Mark N/A explicitly, never skip silently.**

**OPS lens** (overlayed on STRIDE): unclosed connections, memory leaks, locks, behavior at 100x volume.

**Multi-PR rule**: delegate the 2nd pass to a subagent (same reviewer = same blind spots).

### PASSE 3 — KILLER CHECKLIST (all levels)

- `□` Same field = same validation everywhere? (grep to verify)
- `□` Same domain = same auth on ALL transports (REST + WS + SSE)?
- `□` Identity fields resolved server-side, never client-supplied?
- `□` SQL parameterized, never interpolated?
- `□` PII touched = anonymization covered?

Each item: evidence (file:line or grep output) or N/A. "Checked" without evidence = not checked.

---

## Output format

```
## STRIDE ANALYSIS

### PASSE 1 — Risk rank: <Critical | Important | Routine>
Signals: <list>

### PASSE 2 — STRIDE (if Critical/Important)
- S (Spoofing): <N/A because X | RISQUE: ... — evidence: file:line>
- T (Tampering): <...>
- R (Repudiation): <...>
- I (Info Disclosure): <...>
- D (DoS): <...>
- E (Elevation): <...>

OPS: <connections | memory | locks | 100x volume — any finding?>

### PASSE 3 — Killer checklist
- [✓/✗] Same validation everywhere — evidence: <grep output | file:line>
- [✓/✗] Auth parity across transports — evidence: <...>
- [✓/✗] Identity server-side — evidence: <...>
- [✓/✗] SQL parameterized — evidence: <...>
- [✓/✗] PII anonymization — evidence: <...>

### VERDICT
BLOCKING: <list or none>
IMPORTANT: <list or none>
```

---

## Guardrails

- **Anti-theater rule**: every checklist item needs evidence (file:line or grep output). "Checked ✓" with no evidence = not checked.
- **Don't skip categories silently**: every STRIDE category gets either a finding or an explicit "N/A because X" with justification
- **Evidence format**: `path/to/file.ext:123` or `grep -n "pattern" src/` output. Screenshots are evidence for UI. Curl output is evidence for APIs.
- **Rotate stale items**: if a killer checklist item catches nothing in 10+ audits, log to `learnings-capture` for replacement consideration.

---

## When triggered

- Critical tasks, after `avec-quoi-versioner` and before FAIRE
- Before merging any PR that touches auth/security/DB-schema
- On user explicit request: "run STRIDE on this change"
