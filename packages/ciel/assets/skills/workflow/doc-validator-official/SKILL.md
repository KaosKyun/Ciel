---
name: doc-validator-official
description: Before generating code that calls an external library, framework, or API, fetches the OFFICIAL documentation for the exact version in use and validates that each proposed API call (function name, signature, parameters, return type) exists as cited. Rejects reliance on Stack Overflow/blog posts when official docs exist. Forces citations for every non-trivial API use. The primary anti-hallucination gate for the RECHERCHE step.
allowed-tools: Read, Grep, Glob, Bash, WebFetch, WebSearch
---

# doc-validator-official — Official docs first, blogs never

LLM hallucination of APIs is the #1 coding failure mode (ISSTA 2025). Functions that don't exist, wrong version signatures, parameters invented, return types fabricated. Advanced RAG against official docs eliminates this class of bug.

---

## Inputs (infer before asking — see orchestrator's Autonomy protocol)

```
TARGET_STACK: [language + framework + version — e.g., "TypeScript 5.5 + React 19"]
PROPOSED_APIS: [list of function/class/method calls the implementation will use]
PACKAGE_SOURCES: [paths to package.json / go.mod / requirements.txt / Cargo.toml]
```

### Auto-inference sources (exhaust BEFORE asking the user)

- **PACKAGE_SOURCES** → `find. -maxdepth 3 -name 'package.json' -o -name 'go.mod' -o -name 'requirements.txt' -o -name 'pyproject.toml' -o -name 'Cargo.toml' -o -name 'Gemfile'` — pick up every manifest without asking.
- **TARGET_STACK** → derive from PACKAGE_SOURCES (read the files, extract versions of the key libs). Cross-check with `ciel-overlay.md`.
- **PROPOSED_APIS** → parse from the user's task description + any referenced code diff. If user said "use stripe to refund X", APIs = `stripe.refunds.create`, `stripe.paymentIntents.retrieve`, etc.

Only BLOCK if no manifest file exists at all (greenfield project with no deps yet) — then ask once "Which package.json / go.mod should I validate against?".

---

## Phase 1 — Extract exact versions

Read package manifests. For each lib in PROPOSED_APIS extract the pinned version:

```bash
# npm/yarn/pnpm
jq -r '.dependencies +.devDependencies | to_entries[] | "\(.key) \(.value)"' package.json

# go
grep -E '^\s*<lib>' go.mod

# python
grep -E '^<lib>' requirements.txt pyproject.toml
```

Record as `{lib_name, pinned_version, source_file:line}`.

If version is a range (`^1.2.0`) → resolve the actual installed version from lockfile (`package-lock.json`, `yarn.lock`, `uv.lock`, `Cargo.lock`). Never validate against a range.

---

## Phase 2 — Locate official docs

For each lib, find the CANONICAL doc URL for the exact version. Priority order:

1. **Versioned docs site** — `https://reactjs.org/docs/v19.0.0/` or `https://fastapi.tiangolo.com/release-notes/`
2. **Repo `/docs/` at the tag** — `https://github.com/org/repo/tree/v1.2.0/docs`
3. **README at the tag** — `https://github.com/org/repo/blob/v1.2.0/README.md`
4. **Context7 MCP** (if available) — provides up-to-date official docs for thousands of libs

### Reject these sources

- Stack Overflow answers (even highly upvoted — often stale)
- Medium/dev.to blog posts (version drift, author may have been wrong)
- AI-generated tutorials (recursion hazard)
- Forum posts without corroboration by official docs

These may GUIDE investigation but never JUSTIFY an API claim.

---

## Phase 3 — Validate each proposed API

For each item in PROPOSED_APIS:

1. **Fetch the official doc page** for that function/class.
2. **Verify the signature matches** — function exists, parameter names and types match, return type matches.
3. **Verify version availability** — "Added in vX.Y" metadata. If the pinned version < X.Y, the API doesn't exist in this project yet.
4. **Capture citation** — URL + section header + (if possible) quoted signature.

Output per API:
```
[VALID] lib.funcName(a: T1, b: T2): T3
  Source: <URL>#section
  Cited: "funcName(a, b) → T3 — Added in 1.4.0"
  Pinned: 1.5.2 ✓
```

or:
```
[INVALID] lib.funcName — NOT FOUND in v1.5.2 docs
  Similar: lib.otherFunc (did you mean this?)
  Action: rename or choose a different lib
```

or:
```
[AMBIGUOUS] lib.funcName exists but signature differs
  Doc says: funcName(a: string, opts?: Opts) → Promise<T>
  Proposed: funcName(a, b) — missing opts wrapping
  Action: rewrite call site to match doc signature
```

---

## Phase 4 — Citation enforcement

Every non-trivial API use in the final implementation MUST have a citation comment OR be documented in the PR description. Trivial = stdlib builtin (`Array.map`, `str.split`). Non-trivial = third-party lib, framework-specific, version-sensitive stdlib (e.g., `Intl.Segmenter`).

Citation format in code (optional, acceptable if 3+ APIs would clutter):
```typescript
// Per react.dev/reference/react/useTransition (v19)
const [isPending, startTransition] = useTransition();
```

Citation format in PR description (mandatory for Critical tasks):
```
## External APIs used
- `react.useTransition` — react.dev/reference/react/useTransition (v19)
- `drizzle-orm.select().from()` — orm.drizzle.team/docs/select (v0.33)
```

---

## Phase 5 — Training-cutoff awareness

If a lib in PROPOSED_APIS was released or had a major version AFTER your knowledge cutoff (January 2026), explicitly flag:

```
[CUTOFF-WARNING] lib <name> vX.Y (released 2026-MM-DD)
  Your training data does not reliably cover this version.
  MANDATORY: fetch live docs, do not rely on pattern-matching from memory.
```

---

## Output format

```
## DOC VALIDATION

### Versions resolved
- react 19.0.2 (from package-lock.json:1234)
- drizzle-orm 0.33.1 (from package-lock.json:5678)

### API validation
[VALID] react.useTransition — react.dev/.../useTransition (v19)
[VALID] drizzle-orm.select — orm.drizzle.team/docs/select (v0.33)
[INVALID] drizzle-orm.raw — not in v0.33, renamed to sql.raw in v0.30+
[AMBIGUOUS] react.use — signature changed in v19, proposed call uses v18 shape

### Cutoff warnings
- drizzle-orm 0.33 (released 2026-02) — post-cutoff, relied on live fetch

### Verdict
BLOCKING: 1 INVALID, 1 AMBIGUOUS — cannot proceed until resolved
```

---

## Guardrails

- **Never infer an API from "it should exist"** — if you can't cite the doc page, the API doesn't exist for your purposes.
- **Exact version, never range** — validating against a range produces false positives.
- **Reject blog/SO as primary source** — they may CONFIRM, never ESTABLISH.
- **Cutoff-flag everything post-January 2026** — your memory is wrong often enough to require external validation.
- **If docs don't exist** (tiny lib, no website, just README) → read the source directly at the tag. No README + no source available → replace the lib.
- **Budget**: 5 APIs × 2 min lookups = 10 min max. Beyond 10 APIs, batch via a single doc-site crawl or ask user to narrow.

---

## How to verify

- [ ] Exact versions extracted from lock files?
- [ ] Official docs located for each API call?
- [ ] Each proposed API validated (function name, signature, params, return type)?
- [ ] Citations enforced (file:line or URL for every API)?
- [ ] Training-cutoff awareness applied (if lib updated after cutoff)?
- [ ] VERDICT issued (VALID / INVALID / UNCERTAIN)?

## When triggered

- RECHERCHE step for Standard/Critical tasks using external libs
- Before any code using a lib published/updated after your knowledge cutoff
- When `@ciel-researcher` is dispatched for API design
- When user says "use library X" and you have no strong prior
- After `ai-failure-modes-detector` flags an invented-API risk

---

## References

- ISSTA 2025 — "LLM Hallucinations in Practical Code Generation: Phenomena, Mechanism, and Mitigation"
- arxiv 2404.00971 — "Beyond Functional Correctness: Exploring Hallucinations in LLM-Generated Code"
- Mintlify — AI hallucination prevention via accurate docs
- Context7 MCP — `@upstash/context7-mcp` for live official-doc retrieval
