---
name: ai-failure-modes-detector
description: Detects the six canonical failure modes of LLM-generated code — invented APIs, hallucinated dependencies, version drift, async/sync mismatch, confident-wrong logic, and extrinsic hallucination (plausible but unverifiable output). Runs self-consistency triple-generation checks, AST-based dependency audits, and uncertainty scoring. Triggers BEFORE merging agent-authored code, especially when the author is an LLM. Partners with doc-validator-official (API-level) and self-consistency-verifier (semantic-level).
allowed-tools: Read, Grep, Glob, Bash
---

# ai-failure-modes-detector — Catch confident-wrong before it lands

LLM-generated code compiles more often than it's correct. Six failure modes account for >90% of post-merge incidents in agentic PRs (ISSTA 2025). This skill runs each check systematically.

---

## Inputs (infer before asking — see orchestrator's Autonomy protocol)

```
CODE_UNDER_REVIEW: [file paths OR diff hunk]
AUTHOR: [human | LLM | mixed]
PROPOSED_DEPS: [new dependencies being added, if any]
TEST_COVERAGE: [files that have tests | files without]
```

### Auto-inference sources (exhaust BEFORE asking the user)

- **CODE_UNDER_REVIEW** → `git diff HEAD~1` (last commit) or `git diff main...HEAD` (branch diff) — usually the intent. If user said "this file", extract from prompt.
- **AUTHOR** → check the last commit's message / co-author trailer. `Co-Authored-By: Claude` or `Generated with Claude Code` → LLM. Otherwise human. If unsure, assume `mixed` (safer default).
- **PROPOSED_DEPS** → `git diff HEAD~1 -- package.json go.mod requirements.txt` → list added entries. Zero added → skip dep-hallucination check.
- **TEST_COVERAGE** → for each changed file in CODE_UNDER_REVIEW, check if a corresponding `*.test.*` / `*_test.go` / `test_*.py` exists next to it.

Never ask the user for AUTHOR — always inferable from git. Never ask for TEST_COVERAGE — always checkable via filesystem.

---

## The six failure modes

### 1. Invented APIs

Function/class/method that doesn't exist in the library at the pinned version.

**Detection**:
- Grep every import and every method call on imported symbols
- Cross-reference with `node_modules/<pkg>/package.json` + type definitions
- For dynamic imports (`await import()`), inspect at runtime if possible

**Signal**: import resolves but `<symbol>` not in the `.d.ts` or `__init__.py`.

### 2. Hallucinated dependencies

`npm package` or `pip package` that doesn't exist on the registry (or typo-squat).

**Detection**:
- For each new dep in PROPOSED_DEPS: `npm view <pkg> --json` or `pip index versions <pkg>`
- Check publisher reputation (weekly downloads, last publish date, repo link present)
- Typo-squat check: Levenshtein distance ≤ 2 from a popular package name is SUSPICIOUS

**Signal**: registry returns 404, or package has < 100 downloads/week with no repo.

### 3. Version drift

Code uses an API that exists but at a different version than pinned.

**Detection**:
- For each external API call, check "Added in vX.Y" / "Deprecated in vX.Y" metadata
- Compare against pinned version in lockfile

**Signal**: API exists in v2, code pins v1 — silently broken.

### 4. Async/sync mismatch

Sync call in an async codebase or a Promise-returning function not awaited.

**Detection** (TS):
- `@typescript-eslint/no-floating-promises`
- Grep for `fetch(`, `fs.readFileSync` (sync in async) or unawaited `async` functions
- Any `Promise<T>` returned from a function whose callers don't `await`

**Detection** (Python):
- Sync `requests.get()` inside an `async def`
- `asyncio.run()` called inside an event loop

**Signal**: type checker emits "Promise returned but not awaited" OR sync call blocks in async context.

### 5. Confident-wrong logic

Code is syntactically and typing-wise valid, passes linting, but is semantically wrong:
- Off-by-one on pagination
- Wrong operator (`>=` where `>` needed)
- Negated boolean
- Swapped arguments of same type

**Detection**:
- Run existing tests (if present) — failing tests is the first signal
- Invariant check: can you state in 1 sentence what the code guarantees? Does it actually guarantee it?
- For any numerical boundary, ask: "off-by-one in either direction — which breaks?"

**Signal**: behavior divergence between stated goal and actual execution.

### 6. Extrinsic hallucination

Output is plausible but references facts outside the code that cannot be verified:
- Cites a spec section that doesn't exist
- Comments claim "per RFC 7231 §5.3" when section 5.3 doesn't cover that
- Error codes invented (`ERR_USER_QUOTA_EXCEEDED` — is that really thrown?)

**Detection**:
- Every code comment with a source claim → spot-check
- Every user-facing string (error codes, log messages) → grep for prior use in the codebase

**Signal**: claim cannot be corroborated.

---

## Report format

```
## AI-FAILURE-MODES VERDICT

### Author
LLM (auto-detected via commit message pattern | user-declared)

### Findings by mode
1. Invented APIs:
   [BLOCK] src/auth.ts:42 — `jwt.verifyStrict()` not in jsonwebtoken@9.0.2 (use `verify()` with `algorithms` option)

2. Hallucinated deps:
   (none — all 3 new deps exist on npm, >10k weekly downloads)

3. Version drift:
   [WARN] src/db.ts:18 — `drizzle.innerJoin()` added in v0.30, pinned 0.29 — upgrade drizzle-orm

4. Async/sync mismatch:
   [BLOCK] src/upload.ts:55 — `fs.writeFileSync()` inside async handler — blocks event loop

5. Confident-wrong:
   [WARN] src/pagination.ts:22 — `offset = page * pageSize` — off-by-one on page=0

6. Extrinsic:
   [INFO] src/rate-limit.ts:10 — comment cites "per RFC 6585 §4" — RFC 6585 does not have §4; 429 is §4 of RFC 6585 (comment is right, citation format wrong)

### Summary
BLOCK: 2
WARN: 2
INFO: 1
```

---

## Guardrails

- **BLOCK means don't merge** — invented APIs, hallucinated deps, and async/sync mismatches are production-breaking.
- **WARN means discuss in review** — not auto-blocking but requires human acknowledgment.
- **Run against diff, not whole repo** — old code isn't the subject; the new change is.
- **When tests are absent**, confidence in "confident-wrong" findings drops — request tests be added before clearing the review.
- **Don't false-positive on stubs** — intentional mocks in `__mocks__/` or `test-helpers/` may reference not-yet-implemented APIs; verify context.
- **Typo-squat false positives**: popular packages sometimes have close cousins (`request` vs `request-promise`) — check download count AND repo history before flagging.

---

## How to verify

- [ ] All 6 failure modes checked (invented APIs, hallucinated deps, version drift, async/sync, confident-wrong, extrinsic)?
- [ ] Each finding has evidence (file:line or URL)?
- [ ] VERDICT issued (CLEAN / FINDINGS)?
- [ ] Author identified (LLM vs human)?
- [ ] External API calls validated against official docs?

## When triggered

- Post-write hook when AUTHOR=LLM and task is Standard/Critical
- Before any PR merge authored wholly or partially by an agent
- After `@ciel-explorer` completes CODEBASE review
- User command: "audit this code for AI mistakes"

---

## References

- ISSTA 2025 — "LLM Hallucinations in Practical Code Generation: Phenomena, Mechanism, and Mitigation"
- arxiv 2601.19106 — "Detecting and Correcting Hallucinations in LLM-Generated Code"
- arxiv 2404.00971 — "Beyond Functional Correctness"
- Anthropic 2604.08906 — agentic framework failure taxonomy
