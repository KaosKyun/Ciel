---
name: commit-writer
description: Writes commit messages in conventional commit format (feat/fix/chore/docs/refactor/test/perf) with imperative mood, issue references, and warnings on secret files. Invoked before git commit. Short, structured, mechanical — for reviewer clarity and changelog automation.
allowed-tools: Bash, Read
---

# commit-writer — Conventional commit messages

Small utility to ensure commits are: structured, informative, issue-referencing, and free of secrets.

---

## Inputs

Reads from current git state:
- `git status --porcelain` — staged files
- `git diff --staged` — diff content
- Optional: recent commit history for style matching

---

## Process

### 1. Scan staged files

Flag if any of:
- `.env*` (not `.env.example`)
- `credentials.*`, `secrets.*`, `*-keys.*`
- Files > 10 MB (binary?)
- `id_rsa`, `id_ed25519`, other SSH keys

Warn loudly. Do NOT commit secrets.

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

- Imperative mood: "add" not "added"
- ≤ 72 chars
- No trailing period
- Lowercase after type

### 5. Write body (optional)

If non-trivial:
- What changed (1-2 sentences)
- Why (the rationale)
- Any side effects / migration notes

### 6. Add issue reference

If branch name matches pattern `<user>/issue-<N>-description` or an open issue is linked, add at the bottom:
```
Closes #<N>
```

---

## Output format

Print the proposed commit message block, ready to be used with `git commit -m "..."` or via heredoc.

```
<type>(<scope>): <subject ≤72 chars>

<body: what + why>

Closes #<N>
```

---

## Guardrails

- **Warn on secrets**: if `.env`, keys, or credentials are staged → block and ask user to unstage
- **No emojis unless user requests** (default: no emojis in commit messages)
- **No co-author / generated-by lines unless user requests** (to keep history clean)
- **Issue ref required on feature/fix**: if no issue detected, prompt user
- **Preserve project style**: if recent commits use a different format (e.g. `[FEAT]` prefix), match it

---

## When triggered

- Before `git commit`
- User says "write a commit message for these changes"
- In `/ciel` workflow at end of FAIRE before pushing
