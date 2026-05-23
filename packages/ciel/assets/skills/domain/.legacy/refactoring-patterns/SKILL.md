---
name: refactoring-patterns
description: Expert in safe refactoring patterns — extract method/helper, strangler fig, branch by abstraction, seam-first refactor, parallel change. Used before removing or reducing code, and when duplication hits 2+ copies. Invoked alongside pattern-fitness-check when refactoring is the primary task.
allowed-tools: Read, Grep
---

# refactoring-patterns — Safe refactoring

Applied when the task is explicitly a refactor, or when `pattern-fitness-check` detects duplication ≥ 2 requiring extraction.

---

## Core patterns

### 1. Extract method / function

When a block is used 2+ times OR has a clear single responsibility within a longer function:
- Name it after what it does (not how)
- Pure function if possible (no side effects)
- Parameters: only what's needed
- Return type: single responsibility = single return type

### 2. Strangler Fig

Gradual replacement of legacy code:
- Phase 1: put new code behind a feature flag, route a subset of traffic to it
- Phase 2: expand traffic, keep legacy as fallback
- Phase 3: 100% new, legacy dormant
- Phase 4: delete legacy after stable period (weeks to months)

Use when: replacing a core component that other code depends on heavily.

### 3. Branch by Abstraction

Introduce an abstraction layer, migrate callers one by one:
- Create interface that covers both old and new
- Switch callers to interface
- Implement new underneath interface
- Remove old implementation

Use when: ripping out a library or framework; changing API shape widely.

### 4. Parallel Change (Expand-Contract)

For API changes that must remain backward compat:
- **Expand**: add new field/method alongside old
- **Migrate**: update callers to use new
- **Contract**: remove old after all callers migrated

Use when: public APIs, shared libraries, column renames.

### 5. Seam-first refactor

When no tests exist, introduce a seam (injection point) first:
- Extract dependency to constructor param / argument
- Mock the dependency in tests
- Refactor the original code with test coverage
- Refactor the dependency itself once tests pass

Use when: legacy code without test coverage.

---

## Process

### 1. Identify refactor type

- Duplication extraction → extract method/class
- Legacy replacement → strangler fig
- Wide API change → branch by abstraction
- API rename → parallel change
- Untested code → seam-first

### 2. Check blast radius

```bash
grep -rn "callerOfOldApi\|oldFunctionName" src/
```

Count call sites. 20+ call sites = multi-PR refactor; don't attempt in one pass.

### 3. Plan rollback

Every refactor step must be revertable:
- Each step compiles + tests pass
- No step exposes a broken state between deployments

### 4. Preserve behavior

Refactor ≠ behavior change:
- All existing tests pass
- No observable change in API / responses / DB state

---

## Output format

```
## REFACTORING INSIGHTS

### Refactor type
- <extract | strangler | branch by abstraction | parallel change | seam-first>

### Blast radius
- Call sites: <N files>
- Estimated PR count: <1 | multi (N)>

### Step plan
1. <step — revertable>
2. <step — revertable>
3. ...

### Behavior preservation
- Tests covering current behavior: <list — exist | missing ⚠️>
- Existing contract docs: <URL or file>

### Risks
- <risk> — <mitigation>
```

---

## How to verify

- [ ] Refactor type identified (extract/strangler/branch-by-abstraction/parallel-change/seam-first)?
- [ ] Blast radius assessed (call sites counted)?
- [ ] Every step compiles + tests pass?
- [ ] Behavior preserved (all existing tests still pass)?
- [ ] Rollback plan exists for each step?
- [ ] Not mixing refactor + feature in same PR?

## Guardrails

- **Never refactor without tests** — introduce seam first
- **Every step compiles + passes tests** — no "big bang" refactors
- **Preserve behavior** — refactor is behavior-preserving by definition
- **Don't mix refactor + feature** in same PR — makes review harder + rollback impossible
- **Set a timebox** — refactors can grow indefinitely. Cap and ship incremental progress.

---

## When triggered

- Task mentions: refactor, cleanup, extract, replace, migrate
- Duplication ≥ 2 copies detected by `pattern-fitness-check`
- Removing code (works with `faire-gatekeeper` removal gate)
- Pre-deletion of large components
