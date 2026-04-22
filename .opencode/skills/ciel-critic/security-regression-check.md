---
description: Attacker eyes on the diff — detect new inputs, removed auth, new external calls (Critical only)
---

# security-regression-check — Attacker eyes on the diff

Step 8b of CRÉER (Critical only). Runs after FAIRE, before RELIRE.

The hypothesis: "I fixed A without touching B" is NOT a check. Read the diff with attacker eyes — what did my fix add that wasn't there before?

---

## Process

### 1. Capture the diff

```bash
git diff --unified=3 HEAD
```

### 2. Grep for risk signals in the diff

| Signal | What to search | Why it matters |
|--------|---------------|----------------|
| New request param reads | `call.parameters[`, `request.body.`, `req.query.`, `req.params.` | New inputs = new validation surface |
| Removed auth blocks | lines starting with `-` containing `authenticate`, `requireAuth`, `verifyToken`, `checkPermission` | Removed auth = privilege escalation risk |
| New external calls | `+` lines with `fetch(`, `axios(`, `httpClient.`, `HttpClient.`, `WebClient.` | New outbound calls = SSRF / data exfil risk |
| New file reads/writes | `+` lines with `File(`, `fs.readFile`, `fs.writeFile`, `Path(` | New FS access = path traversal risk |
| New SQL | `+` lines with SQL keywords (SELECT, INSERT, UPDATE, DELETE) | New queries = new injection risk if concat |
| New eval/exec | `+` lines with `eval(`, `Function(`, `exec(`, `Runtime.exec` | Code injection risk |
| New trust boundaries | `+` lines with cookies set, tokens created, session writes | New trust = new spoofing surface |

### 3. Classify each finding

For each signal detected:

- **Critical finding** → must address in RELIRE before merge
- **Important finding** → document + address OR explicitly accept with rationale
- **Informational** → note for META-CRITIQUER

### 4. Output

Produce structured output for `relire-critic` to include in its checklist.

---

## Output format

```
## SECURITY REGRESSION CHECK

Diff scope: <N files, +X -Y lines>

### New inputs (from request)
- <file:line> — <new param> — <has validation? yes/no>

### Removed/modified auth
- <file:line> — <what was removed/changed>

### New external calls
- <file:line> — <target URL | dynamic URL risk>

### New file/FS access
- <file:line> — <path controlled by user input?>

### New SQL / eval
- <file:line> — <parameterized? safe?>

### New trust boundaries
- <file:line> — <cookie/token/session change>

### VERDICT
- Critical findings: <list or none>
- Important findings: <list or none>
- Informational: <list or none>

Any Critical → relire-critic must include as mandatory checklist item.
```

---

## Guardrails

- **Read `+` lines with attacker eyes, not author eyes**: the author's intent is irrelevant. What can an external actor do with this code path?
- **Diff scope matters**: 500-line diff → process in chunks. Hostile review of 500 lines at once → fatigue → misses.
- **Don't trust commit messages**: "just a refactor" still needs the check. Refactors routinely remove validation without the author noticing.
- **Cross-reference with stride-analyzer**: findings here update the STRIDE output. Not independent passes.

---

## When triggered

- Critical tasks, automatically after `faire-gatekeeper` and before `relire-critic`
- Before merging any PR in `auth/`, `security/`, DB migrations, payment flows
- On user request: "check if I introduced a regression"
