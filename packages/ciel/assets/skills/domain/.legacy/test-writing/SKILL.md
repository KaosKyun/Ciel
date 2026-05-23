---
name: test-writing
description: How to write effective tests — methodology for unit, integration, and E2E tests. Covers test structure, assertion patterns, mocking strategy, coverage targets, and common anti-patterns. Auto-activates on test files (*.test.*, *.spec.*, *_test.*, test_*.*).
allowed-tools: Read, Grep, Glob
---

# Test Writing — Methodology Guide

## What this covers

How to write tests that catch real bugs, are maintainable, and give confidence for refactoring. NOT a rigid workflow — a reference for test design decisions.

## Core principles

1. **Test behavior, not implementation** — test what the code does, not how it does it
2. **Arrange-Act-Assert** — every test has 3 clear sections
3. **One assertion concept per test** — test one thing, name it clearly
4. **Tests are documentation** — a new reader should understand the feature from tests alone
5. **Fast feedback** — unit tests < 100ms, integration < 5s, E2E < 30s

## Test pyramid

```
        /  E2E  \        ← few, slow, high confidence
       / integration \   ← moderate, test boundaries
      /    unit tests    \  ← many, fast, cheap
```

Ratio guideline: 70% unit / 20% integration / 10% E2E. Adjust based on project needs.

## Unit testing methodology

### What to test

- **Pure functions**: input → output contracts, edge cases, boundary values
- **Business logic**: state transitions, calculations, validation rules
- **Error handling**: invalid input, missing data, boundary violations
- **Transformations**: data mapping, serialization, parsing

### What NOT to test

- Framework code (React render, Express routing, ORM queries)
- Third-party libraries (trust their tests)
- Trivial getters/setters (no logic = no test value)
- Implementation details (private methods, internal state, call order)

### Assertion patterns

```typescript
// Good: test behavior
expect(calculateTotal(items, tax)).toBe(110)
expect(validateEmail("bad")).toEqual({ valid: false, reason: "missing @" })

// Bad: test implementation
expect(calculateTotal).toHaveBeenCalledTimes(1)
expect(internalCache.size).toBe(1)
```

### Naming convention

```
<unit> <behavior> <condition>
"calculateTotal applies tax rate when items are taxable"
"validateEmail rejects addresses without @"
```

### Mocking strategy

- **Mock at boundaries**: external APIs, databases, file system, time, random
- **Don't mock what you own** (unless it's a boundary like a repository interface)
- **Prefer fakes over mocks**: in-memory database > mock database
- **Spy, don't stub**: when you need to verify interaction, spy first
- **Reset mocks between tests**: avoid state leakage

## Integration testing methodology

### What to test

- **API endpoints**: request → response contract, status codes, headers
- **Database operations**: query correctness, migrations, transactions, constraints
- **Service boundaries**: module A calls module B correctly, error propagation
- **Configuration**: env vars, feature flags, secrets resolution
- **Middleware/chains**: request processing pipeline

### Test data strategy

- **Factory functions**: `createUser({ name: "test" })` with sensible defaults
- **Isolation**: each test creates its own data, doesn't depend on other tests
- **Cleanup**: transaction rollback (preferred) or explicit delete in teardown
- **Builders**: `UserBuilder().withEmail("x@y.com).withRole("admin").build()`

### Database testing

- Use a real database (not mocks) for integration tests
- Wrap each test in a transaction, roll back after
- Use migrations to set up schema, not raw SQL
- Test constraints: unique, foreign key, not-null

## E2E testing methodology

### What to test

- **Critical user journeys**: login → purchase → confirmation
- **Cross-system integration**: frontend → API → database → external service
- **Error recovery**: network failure, timeout, invalid state
- **Authentication flows**: login, logout, token refresh, session expiry

### What NOT to E2E test

- Every UI state (use component tests)
- Edge cases already covered by unit/integration tests
- Visual regression (use snapshot/screenshot tools separately)
- Performance (use dedicated profiling tools)

### E2E best practices

- **Page Object Model**: encapsulate page interactions in reusable objects
- **Wait for elements**: don't use fixed sleeps, wait for conditions
- **Test IDs**: use `data-testid` attributes, not CSS selectors
- **Independent tests**: each test can run in isolation
- **Retry flaky assertions**: network-dependent checks may need retries

## Coverage targets

- **Statements**: 80%+ for business logic, 60%+ overall
- **Branches**: focus on error paths and edge cases
- **Functions**: 100% for public API, less for internal helpers
- **Don't chase 100%** — diminishing returns past 80-85%
- **Quality over quantity**: 50 meaningful tests > 200 trivial ones

## Common anti-patterns

1. **Testing the test**: assertions on test setup, not behavior
2. **Mega-tests**: one test covering 5 scenarios — split them
3. **Brittle tests**: break on every refactor — test behavior, not structure
4. **Slow tests**: mocking everything vs using fakes
5. **Flaky tests**: time-dependent, order-dependent, network-dependent
6. **Coverage theater**: high coverage number but tests don't catch real bugs
7. **God fixtures**: massive shared test data that no one understands
8. **Testing private methods**: if it's complex enough to test, extract it

## How to verify your tests are good

- **Mutation testing**: change production code — does a test fail?
- **Refactor test**: rewrite a test in a different way — same assertions?
- **New person test**: can someone understand the feature from tests alone?
- **Bug regression**: when a bug is found, add a test that would have caught it
- **Delete a line**: remove a random line of production code — does something break?

## Framework-specific notes

### Vitest 3 (2026)
- Use `describe` for grouping, `it`/`test` for cases
- `beforeEach` for setup, `afterEach` for cleanup
- `vi.fn()` / `jest.fn()` for mocks, `vi.spyOn()` for spies
- `vi.hoisted()` for variables referenced in `vi.mock()` (Vitest 3 requirement)
- `vi.restoreAllMocks()` in `afterEach` — always clean up
- `restoreMocks: true` in vitest.config as default

```ts
// ✅ Vitest 3: vi.hoisted() for mock variables
const { mockFn } = vi.hoisted(() => ({ mockFn: vi.fn() }));
vi.mock('./service', () => ({ doThing: mockFn }));
```

### Playwright 1.50+ (2026)
- `test.describe` for grouping, `test` for cases
- `page.locator('[data-testid="..."]')` for element selection
- `expect(locator).toBeVisible()` for assertions
- `page.route()` + HAR recording for deterministic E2E
- `routeFromHAR()` for offline CI
- Custom fixtures for auth setup (not manual login in each test)

### pytest 8
- Fixtures for setup, `conftest.py` for shared fixtures
- `@pytest.mark.parametrize` for data-driven tests
- `pytest.raises` for exception testing
- `tmp_path` fixture for file system tests

## How to verify

- [ ] Test behavior, not implementation?
- [ ] Arrange-Act-Assert structure?
- [ ] One assertion concept per test?
- [ ] Mock at boundaries only (not internals)?
- [ ] `vi.restoreAllMocks()` in afterEach?
- [ ] No fixed timeouts (use auto-wait / fake timers)?
- [ ] Tests independent (no order dependency)?
- [ ] Coverage: 80%+ for business logic?

## When triggered

- Test files (*.test.*, *.spec.*, *_test.*, test_*.*)
