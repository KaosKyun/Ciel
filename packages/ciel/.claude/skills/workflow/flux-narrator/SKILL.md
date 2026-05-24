---
name: flux-narrator
description: How to trace data flow through a system — trigger → handler → service → state → output, with boundaries, assumptions, and break points called out. Essential before implementation or test writing.
allowed-tools: Read, Grep
---

# Data Flow Tracing — Narrate Before You Code

## What this covers

How to trace and narrate data flow through a system. If you can't narrate the flow, you don't understand the system — read more code before implementing.

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
What must be true for this flow to work? E.g. "assumes user is authenticated", "assumes DB connection is not exhausted".

### BREAK POINTS
Where can the flow fail WITHOUT visible error? E.g. silent swallowed exceptions, network retries that mask failures, caching that hides stale data.

**Break points ≠ assumptions**: an assumption is "must be true"; a break point is "how it fails silently even when all assumptions hold".

## Test-specific items (when writing tests)

When the task involves writing tests, also determine:

- **Test level**: unit / integration / E2E — justify the choice
- **URL routing**: request `host:port` vs handler `host:port` — match or mismatch? (CI often differs from local)
- **Mock lifecycle**: fires at module load? function call? render cycle?
- **Timing**: expected delay in ms / CI runner capabilities (fake timers? timeout?)

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

[If writing tests:]
### Test-specific
- Test level: <unit | integration | E2E> — <justification>
- URL routing: MATCH ✓ | MISMATCH ⚠️
- Mock lifecycle: <module load | function call | render>
- Timing: <X ms>, CI: <capable | insufficient ⚠️>
```

## How to verify

- [ ] ≥ 3 layers in the flow (trigger → middle → output)?
- [ ] BOUNDARIES identified?
- [ ] ASSUMPTIONS listed (what must be true)?
- [ ] BREAK POINTS identified (silent failures)?
- [ ] Narration based on grep (not memory)?

## Key rules

- **Minimum 3 layers**: trigger → middle → output. Only 2 = don't understand the flow.
- **Don't narrate from memory**: grep the actual call graph. Pattern-matching produces plausible but wrong narrations.
- **Test items mandatory when writing tests**: skipping any one risks CI/local mismatch or flaky tests.
