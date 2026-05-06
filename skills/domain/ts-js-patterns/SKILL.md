---
name: ts-js-patterns
description: TypeScript and JavaScript language-specific patterns — type safety, async control flow, module boundaries, error handling idioms, and performance anti-patterns. Invoked when writing .ts/.js/.tsx/.jsx files. Complements frontend-mastery and backend-mastery (which cover framework patterns).
allowed-tools: Read, Grep, Bash
---

# TypeScript & JavaScript Patterns — Language-Level Idioms

## What this covers

Language-specific patterns that apply across all JS/TS projects, regardless of framework. Framework-specific patterns belong in frontend-mastery or backend-mastery.

## Core principle

**TypeScript is a tool, not a religion.** Use types to encode invariants, not to reproduce the runtime. Prefer `type` over `interface` for unions and intersections, `interface` for object shapes that may be extended.

## Type safety patterns

### Discriminated unions over inheritance

```typescript
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };
```

Prefer tagged unions to class hierarchies. The type checker enforces exhaustiveness.

### Branded types for primitives

```typescript
type UserId = string & { __brand: "UserId" };
type OrderId = string & { __brand: "OrderId" };
```

Prevents passing `UserId` where `OrderId` is expected, even though both are strings.

### Pattern matching over if/else chains

Use switch-on-discriminant or ternary chains for exhaustive type narrowing. Avoid deep if/else trees.

## Async control flow

- **Promise.allSettled** over Promise.all when one failure shouldn't abort the batch
- **AbortController** for cancellable operations — wire through your API layer
- **Never mix .then() and await** — pick one per code path
- **Top-level await** is fine in modules (ESM only)
- **Async iterators** for streaming data (for await...of)

## Module boundaries

- **Explicit exports** — prefer named exports over default exports (better refactoring, tree-shaking)
- **Barrel files** — use index.ts sparingly; they cause circular deps and slow type-checking in large projects
- **Isolate side effects** — module-level side effects (top-level await, global state) break testability

## Error handling

- **Never catch-and-null** — `catch { return null }` swallows diagnostic info
- **Result types** over try/catch for expected failures (validation, API errors)
- **try/catch** only for unexpected failures (network, filesystem)
- **Error causes** — chain errors with `new Error(msg, { cause: original })`

## Performance anti-patterns

- Spread operator in hot paths (creates copies)
- `.filter(x).map(y)` → prefer flatMap or a single loop
- **Unnecessary optional chaining** — `obj?.prop` when `obj` is guaranteed non-null
- **Hidden classes** — avoid deleting properties or changing object shapes dynamically

## When triggered

- Writing or reviewing .ts/.tsx/.js/.jsx files
- PRs involving type changes, module reorganization
- Debugging runtime type errors
