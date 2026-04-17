---
name: faire-gatekeeper
description: Enforces FAIRE step gates during code implementation — alternatives gate (X over Y), idiomatic gate (framework bypass justification), quality gates (complexity/nesting/length), removal gate (who uses? what replaces? what degrades?), test-first gate (RED before GREEN), before-state capture (for bug fixes), and chunked validation. Invoked by the PreToolUse hook on Write/Edit operations.
allowed-tools: Read, Grep, Bash
---

# faire-gatekeeper — FAIRE gates enforcement

Step 8 of CRÉER. The gatekeeper that runs during coding, not before. Invoked by the `PreToolUse` hook on every Write/Edit.

For the full idiomatic bypass table and quality gate thresholds, see the orchestrator `skills/ciel/reference.md` Guards table.

---

## Gates

### 1. Alternatives gate
"I chose X over Y because [reason]." No Y named → back to `evaluer-sizer`.

### 2. Idiomatic gate — justify any framework bypass

- `window.*` / `document.*` in React → why not hook/ref/router?
- `for` + raw SQL → why not batch/ORM?
- `catch(e) { return null }` → why not Result/sealed class?
- `as X` without type guard → why not `is X`?
- Copying a block for the 3rd+ time → why not extract a helper?

Each bypass signal detected → justification required. "I don't know" → back to `research-web-sources`.

### 3. Quality gates
- Cyclomatic complexity < 15 per function
- Nesting depth < 4
- Function length < 50 lines

If any gate fails → refactor before committing (extract function, flatten conditionals, split logic).

### 4. Removal gate (before removing/reducing cache, feature, config, or dependency)

1. **Who uses it?** — grep all consumers
2. **What replaces it?** — identify the alternative layer (HTTP cache? TanStack Query? nothing?)
3. **What degrades?** — trace the UX path for offline, slow network, repeat visits

Any "I don't know" → investigate before acting. "It'll probably work" is NOT an answer.

### 5. Test gate (before implementation code — no exception)

- `□` Test written BEFORE implementation? (RED first)
- `□` Test verifies observable behavior, not just code execution?
- `□` Failure path tested (negative scenario) at same priority as happy path?

### 6. Before-state capture (bug fix only)

Capture broken behavior IMMEDIATELY, before writing any code:
- Log excerpt showing the error
- Curl output showing wrong response
- Screenshot showing wrong UI

Without this, `prouver-verifier` AVANT obligation cannot be satisfied.

### 7. Alignment checkpoint (3+ files)

When 3+ files have been touched: re-read QUOI. Did scope grow? Is the approach still best?

### 8. Volume gate

Creating 3+ PRs in the same session → PAUSE. Verify labels + `Closes #XXX` + staging evidence on each PR before opening the next.

### 9. Chunked validation

After each file: compile? types OK? 2 consecutive fails → STOP. Don't keep coding through compilation errors.

---

## Output format

Invoked via PreToolUse hook, injects into context:

```
## FAIRE CHECKPOINT

Gates applicable for <file.ext>:
- [✓/⚠/✗] Alternatives: <chose X over Y | missing>
- [✓/⚠/✗] Idiomatic: <bypass signal detected? justification?>
- [✓/⚠/✗] Quality: <complexity ok? nesting ok? length ok?>
- [✓/⚠/✗] Removal: <if removing: who/what/degrades clear?>
- [✓/⚠/✗] Test-first: <test written before? RED first?>
- [✓/⚠/✗] Before-state: <if bug fix: captured?>
- [✓/⚠/✗] Alignment: <scope still matches QUOI?>
- [✓/⚠/✗] Volume: <PR count this session?>
- [✓/⚠/✗] Chunked validation: <last compile ok?>

⚠ = review before continuing
✗ = blocking — address or explicitly accept risk
```

---

## Guardrails

- **Never block writes**: this skill injects context; the hook exit is always 0. Failed gates are warnings, not errors.
- **Hook-invoked**: typical invocation is automated via `PreToolUse` on Write/Edit. Manual invocation is also fine.
- **Per-file basis**: each Write/Edit gets its own gate check. Accumulated state (3+ files alignment) is tracked across invocations.
- **Quality gate thresholds**: match project linter config (ESLint, Detekt, etc.) if project defines stricter limits.

---

## When triggered

- `PreToolUse` hook on Write/Edit (automatic)
- Manual invocation when implementing a complex change
- Before any PR is opened (volume gate)
