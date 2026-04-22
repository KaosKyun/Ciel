---
description: Classifies a coding task as Trivial, Standard, or Critical based on mechanical signals.
---

# depth-classifier

Classifies a coding task as Trivial, Standard, or Critical based on mechanical signals.

## Inputs

```
PROMPT: [user's request — full text]
FILES_CHANGED: [list of files if known — optional]
```

## Classification rules

### Critical if ANY:
- **Keywords**: `auth`, `security`, `password`, `token`, `session`, `payment`, `credit.card`, `migration`, `schema`, `2fa`, `mfa`, `encryption`, `secret`, `credential`
- **File paths**: `auth/`, `security/`, `*Service.*`, `*Routes.*`, `*Controller.*`, `*Repository.*`, `*.migration.*`, `*.schema.*`
- **Operations**: DB table creation, auth flow changes, payment integration, crypto operations

### Trivial if ANY:
- **Keywords**: `rename`, `typo`, `copyright`, `comment`, `readme`, `1-line`, `one.line`, `fix.typo`, `spelling`, `docs`
- **Single file change**, <5 lines
- **No logic changes** (only text/comments)

### Standard otherwise:
- New feature, refactor, bug fix (non-security)
- 2-10 files changed
- Logic changes but not security-critical

## Output format

```
## DEPTH CLASSIFICATION

**Depth:** <Trivial | Standard | Critical>
**Reason:** <1 sentence — which signal triggered>
**Pipeline recommendation:**
- Trivial: inline, no dispatch
- Standard: @ciel-explorer if 3+ files, then @ciel-build, then @ciel-critic if 5+ files
- Critical: @ciel-researcher + @ciel-explorer (parallel), then @ciel-build, then @ciel-critic MODE=RELIRE (mandatory)
```

## When invoked

- First step of QUOI workflow (after quoi-framer)
- On every user prompt (via plugin `messages.transform`)
- When user explicitly asks: "what depth is this?"
