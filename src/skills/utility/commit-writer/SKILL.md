---
name: commit-writer
description: Writes commit messages in conventional commit format (feat/fix/chore/docs/refactor/test/perf) with imperative mood, issue references, and warnings on secret files. Invoked before git commit. Short, structured, mechanical — for reviewer clarity and changelog automation.
allowed-tools: Bash, Read
---

# commit-writer — Conventional commit messages

## What this covers
Ensures every commit is structured, informative, traceable to an issue, and free of secrets. The commit message is the first thing a reviewer reads — make it count.

## Core principle
**The commit message explains WHY, not WHAT.** The diff shows what changed. The message explains why it changed. "Fix null pointer in auth" is better than "Update auth.ts".

## Methodology

Reads from current git state:
- `git status --porcelain` — staged files
- `git diff --staged` — diff content
- Optional: recent commit history for style matching

### 1. Scan staged files — secrets gate

Flag if any of:
- `.env*` (not `.env.example`)
- `credentials.*`, `secrets.*`, `*-keys.*`
- Files > 10 MB (binary?)
- `id_rsa`, `id_ed25519`, other SSH keys

**Block immediately.** Do NOT commit secrets.

### 2. Classify change type

From diff content:
- New feature (new endpoint / component / capability) → `feat`
- Bug fix → `fix`
- Build config / CI / dependencies → `chore` or `build`
- Docs only → `docs`
- Refactor (no behavior change) → `refactor`
- Test only → `test`
- Performance → `perf`
- Breaking change → add `!` suffix: `feat!:` or include `BREAKING CHANGE:` in body

### 3. Identify scope (optional)

From top-level folder(s) changed: `feat(auth):`, `fix(users):`, `refactor(db):`.

### 4. Write subject line

- Imperative mood: "add" not "added", "fix" not "fixed"
- ≤ 72 chars (hard limit — git log truncates beyond this)
- No trailing period
- Lowercase after type prefix

### 5. Write body (optional)

If non-trivial:
- What changed (1-2 sentences)
- Why (the rationale — the most important part)
- Any side effects / migration notes

### 6. Add issue reference

If branch name matches pattern `<type>/<N>-<slug>` or an open issue is linked, add at the bottom:
```
Closes #<N>
```

## Output format

```
<type>(<scope>): <subject ≤72 chars>

<body: what + why>

Closes #<N>
```

## Common patterns

### Good commits (before → after)

```
# Feature — clear scope, imperative, issue linked
feat(auth): add OAuth2 PKCE flow for mobile clients

Mobile apps can't safely store client secrets. PKCE eliminates
the need by using a code verifier/challenge pair.

Closes #342

# Bug fix — explains the root cause, not just the symptom
fix(db): prevent N+1 query in user dashboard endpoint

The /dashboard endpoint was loading each user's posts in a
separate query. Eager-load posts via JOIN to reduce 101 queries
to 1.

Closes #567

# Chore — explains WHY the dependency was updated
chore(deps): bump @auth/core from 3.1 to 4.0

v4.0 fixes CVE-2026-1234 (session fixation). Breaking change:
useSession() now returns null instead of throwing on expired
tokens. Updated 3 call sites.
```

### Bad commits

```
# BAD — no type prefix, no scope, no issue
update auth stuff

# BAD — describes WHAT not WHY
fix(users): change line 42 in users.ts

# BAD — too vague, could be anything
fix: bugs

# BAD — past tense, trailing period, > 72 chars
Fixed the authentication module to properly handle the case where users have expired tokens and the refresh flow fails silently.
```

## Anti-patterns

- **"Update X"** — update is not a type. Use `fix`, `feat`, `refactor`, or `chore`.
- **Past tense** — "added", "fixed", "changed" — use imperative: "add", "fix", "change".
- **No issue reference on feat/fix** — every feature and bug fix should trace to an issue. If no issue exists, prompt user to create one first.
- **Secrets in diff** — never commit `.env`, API keys, credentials. Block and warn.
- **Squashing unrelated changes** — one logical change per commit. If you fixed a bug AND added a feature, make two commits.
- **Bodyless non-trivial commits** — if the diff touches > 3 files or > 50 lines, write a body explaining why.

## How to verify

- [ ] Subject line ≤ 72 chars? (`echo "$SUBJECT" | wc -c` ≤ 73)
- [ ] Starts with valid type prefix? (`feat|fix|chore|docs|refactor|test|perf|build|ci`)
- [ ] Imperative mood? (not "added", "fixed", "changed")
- [ ] No trailing period?
- [ ] `feat`/`fix` commits have issue reference (`Closes #N` or `Refs #N`)?
- [ ] No secrets in staged files? (check `.env`, `credentials.*`, `*-keys.*`)
- [ ] Style matches recent commits? (`git log --oneline -5` for reference)

## When triggered

- Before `git commit`
- User says "write a commit message for these changes"
- In `/ciel` workflow at end of FAIRE before pushing

## References

- Conventional Commits v1.0.0 — conventionalcommits.org
- Angular commit convention (widely adopted baseline) — github.com/angular/angular/blob/main/CONTRIBUTING.md
- Ciel pipeline: FAIRE → commit-writer → push
