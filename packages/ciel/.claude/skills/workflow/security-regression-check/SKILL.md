---
name: security-regression-check
description: How to check for security regressions in a diff — greps for new inputs, removed auth blocks, new external calls, new file access, new SQL/eval, and new trust boundaries. Attacker-eye review of what changed, not what was intended.
allowed-tools: Read, Grep, Bash
---

# Security Regression Check — Attacker Eyes on the Diff

## What this covers

How to check if a code change introduced security regressions. The hypothesis: "I fixed A without touching B" is NOT a check. Read the diff with attacker eyes — what did my fix add that wasn't there before?

## Core principle

**Read `+` lines with attacker eyes, not author eyes.** The author's intent is irrelevant. What can an external actor do with this code path?

## Process

### 1. Capture the diff

```bash
git diff --unified=3 HEAD
```

### 2. Grep for risk signals

| Signal | What to search | Why it matters |
|--------|---------------|----------------|
| New request param reads | `call.parameters[`, `request.body.`, `req.query.`, `req.params.` | New inputs = new validation surface |
| Removed auth blocks | `-` lines with `authenticate`, `requireAuth`, `verifyToken`, `checkPermission` | Removed auth = privilege escalation |
| New external calls | `+` lines with `fetch(`, `axios(`, `httpClient.` | New outbound = SSRF / data exfil risk |
| New file reads/writes | `+` lines with `File(`, `fs.readFile`, `fs.writeFile`, `Path(` | New FS access = path traversal risk |
| New SQL | `+` lines with SELECT, INSERT, UPDATE, DELETE | New queries = injection risk if concat |
| New eval/exec | `+` lines with `eval(`, `Function(`, `exec(` | Code injection risk |
| New trust boundaries | `+` lines with cookies, tokens, sessions | New trust = new spoofing surface |

### 3. Classify each finding

- **Critical** — must address before merge
- **Important** — document + address OR accept with rationale
- **Informational** — note for reflection

## Output format

```
## SECURITY REGRESSION CHECK

Diff scope: <N files, +X -Y lines>

### New inputs (from request)
- <file:line> — <new param> — <has validation?>

### Removed/modified auth
- <file:line> — <what changed>

### New external calls
- <file:line> — <target | dynamic URL risk>

### New file/FS access
- <file:line> — <path controlled by user?>

### New SQL / eval
- <file:line> — <parameterized? safe?>

### New trust boundaries
- <file:line> — <cookie/token/session change>

### VERDICT
- Critical: <list or none>
- Important: <list or none>
- Informational: <list or none>
```

## How to verify

- [ ] Diff captured and reviewed?
- [ ] Risk signals grepped (new inputs, removed auth, external calls, file access, SQL/eval, trust boundaries)?
- [ ] Each finding classified (SAFE / RISK / BLOCK)?
- [ ] VERDICT issued (CLEAN / FINDINGS)?
- [ ] Attacker perspective applied?

## Key rules

- **Diff scope matters**: 500-line diff → process in chunks. Fatigue causes misses.
- **Don't trust commit messages**: "just a refactor" still needs the check. Refactors routinely remove validation.
- **"No error" ≠ safe**: absence of error messages doesn't mean the change is secure.
