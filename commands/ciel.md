# /ciel — Ciel Deep-Reasoning Workflow

*Named after the Primordial Sage from Tensura — reasoning at infinite speed before action.*

Usage: `/ciel <task description>`

---

You are now running the Ciel workflow. Follow these steps in order.

## Step 1 — Load context

Check if `ciel-overlay.md` exists at project root or `.claude/`. If found → load it. It contains the project's stack, exact versions, CI setup, and rules that override Ciel defaults.

## Step 2 — Classify depth

State explicitly: **"This is [Trivial/Standard/Critical] because [reason]."**

| Trivial | Standard | Critical |
|---------|----------|---------|
| rename, typo, 1-line | hook, route, component | auth, DB schema, security |
| No agents | researcher + explorer + critic | All 3 mandatory |

If unsure → Standard. If touching user data or auth → Critical.

## Step 3 — QUOI

- What you're building (1 sentence)
- Optimizing for: `perf` | `maintainability` | `security` | `simplicity`
- **NOT-X**: at least 1 constraint the solution must NOT do
- What counts as "done"

## Step 4 — AVEC QUOI

Read actual versions from package.json / build files. Do not use memory. State assumptions.

## Step 5 — Dispatch agents IN PARALLEL (Standard/Critical)

Dispatch **researcher** and **explorer** simultaneously before writing any code:

**researcher:**
```
TASK: [task description]
TECHNOLOGIES: [stack + exact versions from overlay or package files]
QUESTION: [what you need to understand to implement safely]
OVERLAY: [ciel-overlay.md content]
```

**explorer:**
```
TASK: [task description]
FIND: [patterns/functions to locate]
TRACE: [user action that triggers this code path]
PROJECT_ROOT: [absolute project path]
```

Wait for BOTH reports before proceeding to FAIRE.

## Step 6 — SÉCURITÉ (Critical only)

RISK-RANK → STRIDE (6 categories) → KILLER CHECKLIST. Show evidence per item.

## Step 7 — ÉVALUER + FLUX

From agent reports:
- State alternative considered and rejected
- Narrate full data flow
- For tests: URL routing + mock lifecycle + timing

## Step 8 — FAIRE

For each file:
- Alternatives gate: "I chose X over Y because [reason]"
- Idiomatic gate: justify any framework bypass
- Chunked validation: compile check after each file
- Alignment checkpoint at 3+ files

## Step 9 — Dispatch critic (Standard/Critical)

After FAIRE, dispatch a **`general-purpose` Agent** using `agents/critic.md` as its prompt (not `superpowers:code-reviewer` or any other named agent — load `agents/critic.md` to preserve Ciel's critique format):
```
MODE: RELIRE
CHANGED_FILES: [all modified files]
QUOI_GOAL: [original objective]
IMPLEMENTATION: [what was done — 3-5 sentences]
```

- BLOCKING → fix before PROUVER
- IMPORTANT → apply if low-risk, defer with issue ref otherwise

## Step 10 — PROUVER

Write 3 constraints BEFORE checking staging (Critical):
1. Functional: `"POST /api/X returns 201 with body.data.id"`
2. Behavioral: `"Log contains '[MESSAGE]' after triggering"`
3. Negative: `"Old error '[ERROR]' no longer appears"`

Push → staging deploy → trigger scenario → capture concrete evidence → post evidence → create PR.

Code diff ≠ proof. Staging evidence is mandatory.
