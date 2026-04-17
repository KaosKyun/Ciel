---
name: flux-narrator
description: Narrates end-to-end data flow for a coding task — trigger → handler → service → state → output — with BOUNDARIES, ASSUMPTIONS, and BREAK POINTS called out. Adds 4 mandatory test-specific items (test level, URL routing, mock lifecycle, timing) when the task involves writing tests. Invoke for Standard and Critical tasks before implementation.
allowed-tools: Read, Grep
context: fork
agent: Explore
---

# flux-narrator — Narrate data flow before coding

Step 7 of CRÉER. Can't narrate the flow → don't understand the system → read more code.

---

## Core narration

Format: `"When [trigger] → [handler fires] → [function calls] → [data flows] → [output]"`

Example:
```
When user clicks "Save" on ProfileForm →
  → ProfileForm.tsx:handleSubmit (component boundary)
  → useUpdateProfile hook fires (state boundary)
  → fetch('/api/users/:id/profile', {method: 'PATCH'}) (network boundary)
  → Ktor Route at routes/UserRoute.kt:PATCH /:id/profile
  → UserService.updateProfile (service layer)
  → UserRepository.save (DB layer)
  → return HTTP 200 with updated user
  → UI optimistically updates via React Query
  → Toast notification: "Profile saved"
```

## 3 cross-cutting dimensions

### BOUNDARIES
Where does control pass between layers? Each boundary is a place where contracts can break.

### ASSUMPTIONS
What must be true for this flow to work? E.g. "assumes user is authenticated", "assumes DB connection is not exhausted", "assumes the client sent the right Content-Type".

### BREAK POINTS
Where can the flow fail WITHOUT visible error? E.g. silent swallowed exceptions, network retries that mask failures, caching that hides stale data, fire-and-forget writes.

---

## Test-specific addendum (4 mandatory items when writing tests)

When the current task involves writing a test:

- **Test level**: unit (isolated logic) / integration (layer boundary) / E2E (user flow) — justify the choice
- **URL routing**: request `host:port` vs handler `host:port` — match or mismatch? (CI often differs from local — MSW mock at wrong host = test passes locally, fails in CI)
- **Mock lifecycle**: fires at module load? function call? render cycle? (Wrong lifecycle = stale or absent mock)
- **Timing**: expected delay in ms / CI runner capabilities (fake timers? jest/vitest default timeout?)

---

## Output format

```
## FLUX

When <trigger>
  → <layer 1: component/handler — file:function>
  → <layer 2: service/function — file:function>
  → <layer 3: DB/API/store>
  → <output: state change / HTTP response / side effect>

### Boundaries
- <list: where control crosses layers>

### Assumptions
- <list: what must be true>

### Break points (silent failures)
- <list: how the flow fails without visible error>

[If writing tests — 4 mandatory items:]

### Test-specific
- Test level: <unit | integration | E2E> — <justification>
- URL routing: request → <host:port>, handler → <host:port> — <MATCH ✓ | MISMATCH ⚠️>
- Mock lifecycle: fires at <module load | function call | render>
- Timing: expected <X ms>, CI runner: <capable | insufficient ⚠️>
```

---

## Guardrails

- **Narration granularity**: minimum 3 layers (trigger → middle → output). If you can only name 2 layers, you don't understand the flow.
- **Break points are NOT the same as assumptions**: an assumption is "must be true"; a break point is "how it fails silently even when all assumptions hold".
- **Test items are mandatory when writing tests**: skipping any one risks CI/local mismatch, mock lifecycle issues, or flaky tests.
- **Don't narrate from memory**: grep the actual call graph. Pattern-matching produces plausible but wrong narrations.

---

## When triggered

- Standard/Critical tasks, after CODEBASE step
- Before writing ANY test (always invoke with test-specific addendum)
- When debugging: "the flow is broken somewhere" → narrate to find the gap
- When user asks "walk me through how X works"
