---
name: test-strategy-vitest-playwright
description: How to plan a test strategy — test pyramid (70/20/10), what to test at each level (unit/integration/E2E), what to mock vs hit real, property-based testing for boundaries, and keeping the suite fast. 2026 convention: browser-native runners, accessibility-tree assertions over screenshots.
allowed-tools: Read, Grep, Glob, Bash
---

# Test Strategy — Pyramid, Not Ice-Cream Cone

## What this covers

How to decide which tests go where, what to mock, and how to keep a test suite fast. The anti-pattern is 70% E2E Playwright, 5% unit — slow CI, flaky, expensive. The 2026 pyramid: most tests at the unit level, very few real-browser E2E.

## Core principle

**Most tests should be unit tests.** E2E is for critical user paths across 3+ components, not coverage inflation. If you're writing E2E because "it's hard to isolate", the code needs a refactor, not more tests.

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

## Unit testing (Vitest)

**When**: pure function, reducer, class method with deterministic input→output.

- Test ONE behavior per test (not "mega tests")
- No real filesystem, no real network, no real DB
- Run in < 50ms each
- Should fail if implementation logic breaks (not if formatting breaks)

```typescript
it('paginates offset correctly when page is 0', () => {
  expect(paginate({ page: 0, size: 10 }).offset).toBe(0);
});
```

## Integration testing (Vitest + MSW)

**When**: module touches an external system (HTTP API, DB, cache) but you want fast deterministic runs.

- MSW mocks the HTTP layer at the network level (not at the `fetch` level)
- Seed the test with a realistic fixture response
- DB: use `vitest-environment` + SQLite in-memory OR Testcontainers for the real engine
- Run in < 500ms each

**Anti-pattern**: mocking your own modules. If you mock your own user-service, you're just testing that you wrote mocks correctly.

## E2E testing (Playwright)

**When**: critical user path across ≥ 3 components (login → browse → checkout → confirm).

- **Accessibility-tree assertions** (`page.getByRole('button', { name: 'Submit' })`) — deterministic, doesn't break on CSS changes
- **Avoid screenshot assertions** for behavior — use for visual regression only, and only on static content
- Seed DB via a test setup script, NOT through the UI (too slow)
- One test = one user journey, not twelve

## Property-based testing (fast-check)

**When**: boundary conditions are the risk — off-by-one, null, empty, max int, unicode.

- State the PROPERTY ("sorting is idempotent: sort(sort(x)) === sort(x)")
- Let fast-check generate 100+ inputs
- Use `fc.pre()` to filter invalid inputs (not to avoid branches of logic)

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

## Key points

- Pyramid ratios are targets, not strict quotas — a pure-UI feature may skew E2E higher; a pure-algorithm feature may be 95% unit
- No E2E without unit first
- One test per behavior — tests named `it('does many things',...)` are code smell
- Avoid snapshot tests for dynamic output — they become "update snapshots" rituals that don't catch bugs
- Accessibility-tree > CSS selectors in Playwright — `getByRole` survives refactors
- Flaky test policy: first flake → debug. Second flake → quarantine (`test.skip` + ISSUE). Third flake → delete unless Critical

## Common anti-patterns

1. **Ice-cream cone**: 70% E2E, 5% unit — slow, flaky, expensive to maintain
2. **Coverage theater**: high coverage number but tests don't catch real bugs
3. **Mocking yourself**: mocking your own modules proves nothing except that mocks work
4. **Mega-tests**: one test covering 5 scenarios — split them
5. **Screenshot assertions for behavior**: brittle, break on font changes; use accessibility-tree assertions instead
6. **E2E as unit replacement**: E2E tests are 100x slower, use them only for integration across real browsers

## How to verify your test strategy is good

- **Runtime budget**: total suite < 3 min for pre-commit + CI
- **Mutation testing**: change production code → does a test fail?
- **New person test**: can someone understand the feature from tests alone?
- **Bug regression**: when a bug is found, add a test that would have caught it at the lowest level possible

## References

- defined.net/blog/modern-frontend-testing — Vitest + Storybook + Playwright stack
- playwright.dev/docs/best-practices — accessibility-tree assertions
- fast-check.dev — property-based testing in TS/JS
- hypothesis.works — property-based testing in Python (equivalent concepts)
