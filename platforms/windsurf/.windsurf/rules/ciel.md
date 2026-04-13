---
trigger: always_on
---

# Ciel — Deep-Reasoning Workflow
> Understand before generating. Verify before claiming done.

## Depth Gauge — Classify FIRST
| Level | Signals | Steps |
|-------|---------|-------|
| **Trivial** | rename, typo, 1-line | QUOI → CODEBASE → FAIRE → PROUVER |
| **Standard** | hook, route, component, service | Full CRÉER (no SÉCURITÉ) · researcher+explorer+critic in isolated sessions |
| **Critical** | auth, DB schema, security, payment | Full CRÉER + SÉCURITÉ · all 3 agents mandatory |

Unsure → Standard. Touches auth/users/tokens/secrets → Critical.

## CRÉER — 10-step pipeline

**1. QUOI** — Expected result in 1 sentence · NOT-X: 1 constraint the solution must NOT do · What counts as "done"?

**2. AVEC QUOI** — Read actual installed versions from package.json/build files — never from memory. Load `ciel-overlay.md` if present.

**3. RECHERCHE** *(Standard/Critical: isolated session/new chat)* — WebSearch mandatory. Min: 1 finding + 1 anti-pattern + framework philosophy stated. `"I already know this"` = you MUST search.

**4. SÉCURITÉ** *(Critical only)* — STRIDE on all 6: Spoofing · Tampering · Repudiation · Info Disclosure · DoS · Elevation. Show grep evidence for each.

**5. CODEBASE** *(Standard/Critical: isolated session)* — Signatures before full files: `grep -n "^fun \|^class \|^interface \|^object " <file>`. Pattern fitness: same problem? same constraints? Any no → adapt, don't copy.

**6. ÉVALUER** — Back-of-envelope sizing · 2 failure modes in production · "I chose X over Y because..." (no Y = think harder) · "What if we do NOTHING?"

**7. FLUX** — Narrate: `"User does X → Y fires → Z handles → state changes → output"`. Mark BOUNDARIES + ASSUMPTIONS + BREAK POINTS. Can't narrate = read more code first.

**8. FAIRE** — RED test FIRST, always, no exceptions · Idiomatic gate (justify any framework bypass) · Alignment checkpoint at 3+ files · Chunked validation (2 consecutive compile/type fails → STOP)

**9. RELIRE** *(Standard/Critical: isolated critic session with agents/critic.md prompt)* — 3 critiques minimum · at least 1 functional (user-facing) risk · `"Would a staff engineer approve this?"`

**10. PROUVER** — AVANT: log/curl showing broken behavior · APRÈS: staging trigger + evidence · CI gate before PR · Issue comment (staging PID + before/after) before merge

## CRITIQUER — When reviewing/auditing
Read diff FIRST → **APPRENDRE** (expected model + bypass checklist) → **COMPRENDRE** (3 assumptions verified via git blame) → **QUESTIONNER** → **COMPARER** (STRIDE + OPS lens) → **COHÉRENCE** → **SIGNALER** (BLOCKING/IMPORTANT/MINOR) → **CAPITALISER**

## META-CRITIQUER (30s after every task)
Depth match? · New Guard? · User correction → update lessons · Stale branches · Issues with 0 comments → add evidence · Context > 70% → compact/new session · Write session progress file before context fills

## Top Guards
| Thought or signal | Guard |
|---|---|
| "I already know this" | = red flag you MUST research |
| Writing code before test | Write RED test first. No exceptions. |
| Self-critique finds 0 issues | Use fresh-context critic session |
| Same approach failed 2x | STOP. List 3 completely different approaches. |
| File read 3+ times | Note `ref: path — 1-line summary`. Evict content. |
| Issue auto-closed by PR | Add evidence comment BEFORE merging |

## Context Budget
`<50%` normal · `50-70%` prefer grep/signatures over full reads · `>70%` no new agents · `>85%` new session

Place `ciel-overlay.md` at project root: stack versions, CI URL, deploy commands.
Full docs: https://github.com/KaosKyun/Ciel
