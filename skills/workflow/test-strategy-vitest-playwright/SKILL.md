---
name: test-strategy-vitest-playwright
description: Designs the test strategy for a feature — which tests belong at which level (unit 70% / integration 20% / e2e 10%), which tooling fits (Vitest + MSW + Playwright + fast-check), what to mock vs what to hit real, and how to keep the suite fast. 2026 convention: browser-native runners, property-based for edge cases, accessibility-tree assertions over screenshots. Invoked during CRÉER step 4 (test planning) before code is written.
allowed-tools: Read, Grep, Glob, Bash
context: fork
agent: explorer
---

# test-strategy-vitest-playwright — Test pyramid, not ice-cream-cone

The anti-pattern is 70% E2E Playwright, 5% unit — slow CI, flaky, expensive. The 2026 pyramid: most tests at the unit level, very few real-browser E2E, property-based for boundary conditions.

---

## Inputs

```
FEATURE_DESCRIPTION: [what the feature does, user-level]
COMPONENTS_TOUCHED: [files / modules / routes]
EXISTING_TESTS: [coverage map of the affected area]
STACK: [TS/JS framework + test tooling currently used]
```

---

## The 2026 pyramid (target ratios)

```
        ┌───────────────┐
        │  E2E (10%)     │  Playwright — critical user paths only
        ├───────────────┤
        │  Integ (20%)   │  Vitest + MSW (no real network) OR test DB
        ├───────────────┤
        │                │
        │  Unit (70%)    │  Vitest — pure logic, reducers, utils
        │                │
        └───────────────┘
```

Property-based (`fast-check`) crosscuts all levels for boundary conditions.

---

## Decision rules per test type

### Unit test (Vitest)

**When**: pure function, reducer, class method with deterministic input→output.

**Rules**:
- Test ONE behavior per test (not "mega tests")
- No real filesystem, no real network, no real DB
- Run in < 50ms each
- Should fail if implementation logic breaks (not if formatting breaks)

**Example**:
```typescript
it('paginates offset correctly when page is 0', () => {
  expect(paginate({ page: 0, size: 10 }).offset).toBe(0);
});
```

### Integration test (Vitest + MSW)

**When**: module touches an external system (HTTP API, DB, cache) but you want fast deterministic runs.

**Rules**:
- MSW mocks the HTTP layer at the network level (not at the `fetch` level)
- Seed the test with a realistic fixture response
- DB: use `vitest-environment` + SQLite in-memory OR Testcontainers for the real engine
- Run in < 500ms each

**Anti-pattern**: mocking your own modules. If you mock your own user-service, you're just testing that you wrote mocks correctly.

### E2E test (Playwright)

**When**: critical user path across ≥ 3 components (login → browse → checkout → confirm).

**Rules**:
- **Accessibility-tree assertions** (`page.getByRole('button', { name: 'Submit' })`) — deterministic, doesn't break on CSS changes
- **Avoid screenshot assertions** for behavior — use for visual regression only, and only on static content
- Seed DB via a test setup script, NOT through the UI (too slow)
- One test = one user journey, not twelve

**Anti-pattern**: recreating every unit test via E2E. E2E = integration across real browsers, not coverage inflation.

### Property-based (fast-check)

**When**: boundary conditions are the risk — off-by-one, null, empty, max int, unicode.

**Rules**:
- State the PROPERTY ("sorting is idempotent: sort(sort(x)) === sort(x)")
- Let fast-check generate 100+ inputs
- Use `fc.pre()` to filter invalid inputs (not to avoid branches of logic)

---

## What to mock, what to hit real

| System | Mock? | Rationale |
|---|---|---|
| External HTTP APIs | Yes (MSW) | Flaky, slow, rate-limited |
| Internal microservices | Yes (MSW) for unit/integ; real for E2E | Keep blast radius small |
| Database | Real (in-memory or container) | Too many bugs hide in ORM/raw-SQL mismatch |
| Time (`Date.now`) | Yes (vi.useFakeTimers) | Non-determinism otherwise |
| Randomness | Yes (seeded PRNG) | Same reason |
| Filesystem | Real (temp dir) for integ; mock for unit | `memfs` is fine for pure tests |
| Auth tokens | Real signed test token | Mocked tokens hide signature-validation bugs |
| Third-party SDK | Mock at module boundary | Not at network level |

---

## Test plan output

```
## TEST STRATEGY

### Feature
<1 sentence>

### Coverage by level
- Unit (target 70%): paginate() logic, orderByField(), parseQuery() — Vitest
- Integration (target 20%): UserService.createUser() + MSW for /api/audit — Vitest
- E2E (target 10%): signup → verify email → first login — Playwright
- Property-based: sorting invariants, pagination offset boundaries — fast-check

### What's mocked
- External audit API (MSW at integration level)
- Time (vi.useFakeTimers for TTL tests)

### What's real
- SQLite in-memory DB for integration
- Signed JWT for auth tests

### Estimated runtime
- Unit suite: ~4s (80 tests)
- Integration: ~30s (20 tests)
- E2E: ~2min (4 tests)
- Total: <3min — suitable for pre-commit + CI

### Fixtures needed
- user.fixture.ts (5 users with different permissions)
- audit-response.fixture.ts (3 response shapes)
```

---

## Guardrails

- **Pyramid ratios are targets, not strict quotas** — a pure-UI feature may skew E2E higher; a pure-algorithm feature may be 95% unit.
- **No E2E without unit first** — if you're writing E2E because "it's hard to isolate", the code needs refactor, not more tests.
- **One test per behavior** — tests named `it('does many things', ...)` are code smell.
- **Avoid snapshot tests** for dynamic output — they become "update snapshots" rituals that don't catch bugs.
- **Accessibility-tree > CSS selectors** in Playwright — `getByRole` survives refactors, `[data-testid="btn-x"]` survives design refactors only by coincidence.
- **Flaky test policy**: first flake → debug. Second flake → quarantine (`test.skip` + ISSUE). Third flake → delete unless Critical.

---

## When triggered

- CRÉER step 4 (before writing code) for Standard/Critical tasks
- `@ciel-explorer` when a new feature starts
- Before adding a large test file to an existing suite (sanity-check ratios)
- User command: "how should I test this?"

---

## References

- defined.net/blog/modern-frontend-testing — Vitest + Storybook + Playwright stack
- playwright.dev/docs/best-practices — accessibility-tree assertions
- fast-check.dev — property-based testing in TS/JS
- hypothesis.works — property-based testing in Python (equivalent concepts)
