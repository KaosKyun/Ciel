---
name: modern-patterns-checker
description: Scans proposed or existing code for obsolete patterns that LLMs tend to reproduce from stale training data — React class components instead of hooks, sync-when-async-is-standard, callback hell, Python 2 idioms, old Go error handling, jQuery in React codebases, CommonJS in ESM projects. Flags each anti-pattern with the 2026 canonical replacement and a link to the migration note. Referenced by ThoughtWorks Technology Radar April 2026.
allowed-tools: Read, Grep, Glob, Bash
context: fork
agent: explorer
---

# modern-patterns-checker — Don't ship 2019-era code in 2026

LLMs over-weight patterns that dominated their training set years ago. Without a guardrail, React class components, callback-based async, and sync-APIs-in-async-codebases keep leaking into new PRs. ThoughtWorks 2026 calls this "cognitive debt from AI autocompletion."

---

## Inputs

```
CODE_UNDER_REVIEW: [file paths OR diff hunk]
TARGET_STACK: [language + framework + version — resolved from package manifests]
```

---

## Anti-pattern catalogue (2026)

### TypeScript / JavaScript

| Anti-pattern | Canonical 2026 replacement |
|---|---|
| `class Foo extends React.Component` | Functional component + hooks |
| `componentDidMount / componentDidUpdate` | `useEffect` (or Server Component for data fetching) |
| `.then().catch()` chains > 2 links | `async/await` with `try/catch` |
| `require()` in a project with `"type":"module"` | `import` (ESM) |
| `var` | `const` / `let` |
| `null`-checks everywhere | Discriminated unions + `?.` / `??` |
| `any` as escape hatch | `unknown` + narrowing, or proper type |
| `lodash.get` / `lodash.set` | Optional chaining `?.` + `??` |
| `fetch().then(r => r.json()).then(...)` | `await fetch()` + `await r.json()` |
| `moment.js` | `Temporal` API (Node 22+) or `date-fns` |
| Redux for local UI state | `useState` / `useReducer` / Zustand |
| PropTypes | TypeScript types |

### Python

| Anti-pattern | Canonical 2026 replacement |
|---|---|
| `print` as debug | `logging` with structured fields |
| `%`-format or `.format()` | f-strings |
| `dict.has_key(k)` | `k in dict` |
| Nested `if` guards | Early-return pattern |
| Bare `except:` | `except SpecificError:` |
| `os.path.join` | `pathlib.Path` |
| Sync `requests` in async codebase | `httpx.AsyncClient` / `aiohttp` |
| `dataclass` without `slots=True` | `@dataclass(slots=True)` (3.10+) |
| `typing.List`, `typing.Dict` | Built-in `list`, `dict` (3.9+ PEP 585) |
| `from typing import Optional` | `X \| None` (3.10+ PEP 604) |

### Go

| Anti-pattern | Canonical 2026 replacement |
|---|---|
| `if err != nil { return err }` without wrapping | `fmt.Errorf("context: %w", err)` |
| Bare `err == sql.ErrNoRows` | `errors.Is(err, sql.ErrNoRows)` |
| Passing request context implicitly | Explicit `ctx context.Context` first arg |
| `interface{}` | `any` (Go 1.18+), or typed interface |
| `sync.Mutex` wrapping a slice | `sync.Map` or channel |

### SQL

| Anti-pattern | Canonical 2026 replacement |
|---|---|
| String concatenation for queries | Parameterized queries / prepared statements |
| `SELECT *` in production queries | Explicit column list |
| `N+1` loop queries | JOIN or batched `IN (...)` |
| Missing indexes on FK | Index on every foreign key |

### React (post-19)

| Anti-pattern | Canonical 2026 replacement |
|---|---|
| `useEffect` for data fetching | Server Components, `use()`, or TanStack Query |
| `useState` for derived values | `useMemo` or compute inline |
| Prop-drilling > 3 levels | Context, composition, or state library |
| Manual form state | `react-hook-form` or native `<form>` actions |

---

## Detection method

1. **Regex pass** (fast) — grep for obvious markers: `extends Component`, `componentDidMount`, `require(`, `var `, `any`, `.then(.*).then(`, etc.
2. **AST pass** (accurate, optional) — if `tsc` / `ruff` / `go vet` configured in the repo, run with strict rules.
3. **Context pass** — read `tsconfig.json`, `pyproject.toml`, `go.mod` to confirm the stack is modern enough to allow the replacement. Don't suggest `Temporal` if Node is pinned to 18.

---

## Report format

```
## MODERN-PATTERNS VERDICT

### Findings
[BLOCK]  components/Profile.tsx:24 — class component
         Replacement: functional + hooks
         Migration: react.dev/reference/react/Component#alternatives

[WARN]   lib/api.ts:55-70 — .then() chain (3 links)
         Replacement: async/await
         Rationale: readability + stack traces

[INFO]   tests/user.test.ts:8 — `any` as escape hatch
         Replacement: `unknown` + narrowing, or proper User type
         Rationale: loses type safety in test-critical code

### Stack-compatibility confirmed
- Node: 22.3 ✓ allows Temporal
- TS: 5.5 ✓ allows `satisfies` operator
- React: 19.0.2 ✓ allows Server Components

### Summary
BLOCK: 1  (must fix)
WARN:  1  (strongly advised)
INFO:  1  (opportunistic)
```

---

## Guardrails

- **Verify stack before recommending** — suggesting `Temporal` on Node 18 wastes a review cycle.
- **Don't aggregate-rewrite legacy** — flag, don't refactor wholesale. A single migration is a PR, not a silent edit.
- **Repo-level opt-outs respected** — if `.eslintrc` deliberately allows `var` or a deprecated pattern (grandfather clause for a legacy module), note and skip.
- **Citation required** — every suggestion links to the official migration doc or the MDN/React/Python guide. No link → drop the suggestion.
- **BLOCK only for compile-breaking or security-sensitive** — class components don't BLOCK a working PR; a missing parameterized query DOES.
- **Stop at 10 findings per file** — above 10, return "file needs a dedicated modernization task" rather than a linter dump.

---

## When triggered

- CODEBASE step after `explorer` reads the target files
- `@ciel-explorer` dispatched for PR review
- Before accepting LLM-generated code in a legacy codebase (high drift risk)
- After `@ciel-researcher` validates an API — this skill confirms the call site uses modern idioms

---

## References

- ThoughtWorks Technology Radar April 2026 — "curated shared instructions" volume
- React 19 migration guide — react.dev/blog/2024/04/25/react-19
- PEP 585 / PEP 604 — Python builtin-generics + union syntax
- Go 1.18 — `any` alias, generics
- MDN Async/Await — developer.mozilla.org/en-US/docs/Learn/JavaScript/Asynchronous
