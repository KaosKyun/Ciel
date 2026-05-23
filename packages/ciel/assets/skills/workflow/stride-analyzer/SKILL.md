---
name: stride-analyzer
description: "Threat modeling STRIDE 3 passes — Risk rank (mécanique), STRIDE 6 catégories (grep-backed), Killer checklist (validation/auth/SQL/PII). Anti-theater : chaque item a une preuve file:line. Usage interne par ciel-critic et critiquer-auditor."
internal: true
---

# STRIDE Analyzer — Threat Modeling

**Principe premier :** La sécurité n'est pas une checklist qu'on coche — c'est une analyse systématique de ce qu'un attaquant peut faire. Chaque finding a une preuve (file:line ou grep output). "Checked ✓" sans preuve = pas checked. Le but n'est pas de documenter qu'on a vérifié, c'est de trouver ce qu'on a raté.

## Checklist
- [ ] Pass 1 : Risk rank classifié (Critical/Important/Routine) avec signaux mécaniques
- [ ] Pass 2 : STRIDE 6 catégories — chaque catégorie a un finding ou "N/A because X"
- [ ] Pass 3 : Killer checklist 5 items complétés avec preuves
- [ ] Verdict BLOCKING/IMPORTANT émis

## Pass 1 — Risk rank (signaux mécaniques)

- **Critical** si : `auth/`, `security/`, tables DB (users, sessions, tokens), `.executeQuery`, `.executeUpdate`, `userId`, `password`, `token`, `secret`
- **Important** si : diff > 5 fichiers, `validate`, `sanitize`, `rateLimit`, route handlers
- **Routine** sinon

→ Critical = 3 passes. Important = passes 2+3. Routine = pass 3 seulement.

## Pass 2 — STRIDE 6 catégories (Critical/Important)

| Catégorie | Question | Evidence type |
|-----------|----------|--------------|
| **S**poofing | Can I impersonate someone? | Auth checks, token validation |
| **T**ampering | Can input be modified in transit? | Input validation, integrity checks |
| **R**epudiation | Can a user deny this action? | Audit logging, timestamps |
| **I**nfo Disclosure | What leaks? | Error messages, logs, responses |
| **D**oS | Can this be flooded/exhausted? | Rate limits, resource bounds |
| **E**levation | Can I access what I shouldn't? | Authorization checks, role validation |

Chaque réponse : grep-backed ou "N/A because X". **Jamais skip silencieux.**
**OPS lens** (superposé sur STRIDE) : connexions non fermées, memory leaks, locks, 100x volume.

## Pass 3 — Killer checklist (tous niveaux)

- Même champ = même validation partout ? (grep pour vérifier)
- Même domaine = même auth sur TOUS les transports (REST + WS + SSE) ?
- Champs d'identité résolus serveur-side, jamais fournis par le client ?
- SQL paramétré, jamais interpolé ?
- PII touchée = anonymization couverte ?

Chaque item : preuve (file:line ou grep) ou N/A.

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
