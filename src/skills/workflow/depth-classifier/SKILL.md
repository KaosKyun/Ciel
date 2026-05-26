---
name: depth-classifier
description: Classifies a coding task as Trivial, Standard, or Critical based on mechanical signals (auth paths, security code, DB tables, diff size, route handlers). Use at the start of every Ciel workflow to determine which downstream skills to invoke. Returns a one-word depth + rationale + pipeline recommendation.
allowed-tools: Read, Grep, Glob
---

# depth-classifier — Classify task depth

Gatekeeper skill at the entry of every Ciel workflow. Wrong classification = wrong depth = either waste (over-processing trivial) or risk (under-processing critical).

---

## Inputs

- **task**: the task description in natural language (from `/ciel <task>` or user message)
- **project-root** (optional): absolute path, defaults to CWD
- **overlay** (optional): `ciel-overlay.md` content if available

---

## Classification signals

### Critical if ANY match:

- Path patterns: `auth/`, `security/`, `Token`, `Password`, `Secret`, `Session`, `Crypto`
- DB table names: `users`, `sessions`, `tokens`, `accounts`, `credentials`, `2fa`, `api_keys`
- Code patterns: `.executeQuery`, `.executeUpdate`, raw SQL, `userId` (server-provided vs client-provided), `role`, `permission`
- Task keywords: "authentication", "authorization", "payment", "migration (DB schema)", "JWT", "OAuth", "encryption", "2FA", "session"
- Scope: touches user data, money, audit trails

### Standard if ANY match (and not Critical):

- Path patterns: `routes/`, `controllers/`, `services/`, `components/`, `hooks/`
- **CI/CD & pipeline files**: `.github/workflows/*.yml`, `.gitlab-ci.yml`, `.circleci/`, `Dockerfile`, `docker-compose*.yml`, `Jenkinsfile`, `.buildkite/`, `.drone.yml`
- **PR-review signals**:
  - Prompt contains a PR number (`#\d+`, `PR \d+`, `pull request \d+`) OR phrases "open PR", "review PR", "fix PR", "merge PR"
  - Planned tool calls include `gh pr list`, `gh pr view`, `gh pr checks`, `gh pr review`, `gh pr merge` (any variant: `--auto`, `--squash`, `--merge`, `--rebase`)
  - Planned edits touch any CI/CD pipeline file (see row above)
- Diff scope (estimated): > 1 file OR > 50 lines change
- Code patterns: `validate`, `sanitize`, `rateLimit`, route handlers, state management
- Task keywords: "add endpoint", "new component", "refactor", "extract helper", "feature", "integration"

**Floor rule**: if ANY PR-review signal OR any CI/CD-file signal is present, depth is **at minimum Standard** — Trivial is disqualified even if the diff is small. PR review plus CI fix is never "just a one-line change".

### Trivial otherwise:

- Rename, typo, 1-line fix, copyright update, README edit
- Single-file localized change ≤ 10 lines
- No business logic change

### Default rule

If unsure → **Standard**. If touching user data or auth → **Critical**.

---

## Pipeline recommendations

Return pipeline for each depth:

### Trivial
`quoi-framer` → `pattern-fitness-check` → `faire-gatekeeper` → `relire-critic` (inline) → push → `meta-critiquer`

### Standard
`quoi-framer` → `avec-quoi-versioner` → [researcher agent + explorer agent IN PARALLEL] → `evaluer-sizer` → `faire-gatekeeper` → `critic` agent MODE=RELIRE → `prouver-verifier` → `meta-critiquer`

### Critical
All of Standard + `stride-analyzer` (after `avec-quoi-versioner`) + `security-regression-check` (between FAIRE and RELIRE) + critic agent MANDATORY

---

## Output format

```
## DEPTH CLASSIFICATION

Depth: **Trivial | Standard | Critical**

Signals detected:
- [signal 1 with source — e.g. "path matches /auth/"]
- [signal 2]

Rationale: [1-2 sentences]

Pipeline:
1. <skill>
2. <skill>
...

Agents required:
- [researcher: yes/no]
- [explorer: yes/no]
- [critic: yes/no]
```

---

## Guardrails

- **Asymmetric bias**: when borderline between Trivial/Standard → Standard wins. When borderline between Standard/Critical → Critical wins. Missing a Critical is worse than over-processing a Standard.
- **Auth/security override**: any mention of auth, credentials, tokens, or user identity → Critical regardless of diff size
- **Single-line fix can still be Critical**: e.g. a 1-char fix in an auth check is Critical
- **Don't infer from filename alone**: `UserService.kt` could be Trivial if the change is a rename. Look at the actual code change being proposed.

---

## How to verify

- [ ] Classification signals checked (Critical, Standard, Trivial)?
- [ ] Pipeline recommendation provided?
- [ ] Default rule applied (Unsure → Standard)?
- [ ] Auth/security files → Critical?

## When triggered

- Automatically at start of `/ciel <task>` via the `ciel` orchestrator
- By `UserPromptSubmit` hook (light classification hint injected into context)
- Explicitly when depth is ambiguous after initial assessment
