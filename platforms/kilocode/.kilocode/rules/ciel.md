# Ciel — Rules (Kilo Code)

Principle: **"Understand before generating. Verify before claiming done."**

---

## Top 10 Guards

1. "I already know this" = red flag — research first before asserting
2. No citation = don't know it — verify via @ciel-researcher
3. DB columns: verify real schema before writing a query
4. Test URL host:port must match handler host:port
5. Pattern copied blindly → fitness check fails → adapt or reject
6. Self-critique in same context = same blind spots → dispatch @ciel-critic
7. No alternative considered → back to ÉVALUER step
8. Scope drift at 3+ files → re-read QUOI goal statement
9. Write test FIRST (RED) — test after is too late to catch design flaws
10. "No error in logs" ≠ proof — trigger the scenario, see a positive signal

---

## Prose hook equivalents (Kilo Code has no native hooks)

**On every code file write** (auth|security|Route|Service|Controller|Repository|Gateway|Middleware):
→ Pause. Dispatch `@ciel-critic MODE=RELIRE` before declaring done.
→ Do NOT mark the task complete without a critic verdict.

**When 3+ code files changed in a session:**
→ Dispatch `@ciel-critic MODE=RELIRE` — same-context critique = same blind spots.

**On session start:**
→ Read `ciel-overlay.md` (if present) for project-specific stack, versions, rules.
→ Read `AGENTS.md` for the full 10-step pipeline.

**Before using any external library or API:**
→ Dispatch `@ciel-researcher` to verify current docs — "I already know the API" is a red flag.

---

## Depth quick-reference

- **Trivial**: rename, typo, comment, 1-line fix → skip RECHERCHE + STRIDE
- **Standard**: hook, route, component, service → RECHERCHE + CODEBASE required
- **Critical**: auth, DB schema, security, payment → all 10 steps + STRIDE mandatory

Unsure → Standard. Touching user data or auth → Critical.
