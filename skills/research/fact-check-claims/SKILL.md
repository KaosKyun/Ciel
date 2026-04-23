---
name: fact-check-claims
description: Before asserting any API/version/behavior claim in code or reports, greps the source code or fetches docs to verify. Guards against "false confidence" — confident assertions without evidence. Invoked before any assertion is committed to final output.
allowed-tools: Read, Grep, WebFetch
context: fork
agent: researcher
---

# fact-check-claims — Verify before asserting

## What this covers
Meta-research skill #6 of 6. The guard against false confidence. LLMs routinely state confidently wrong things — DB column names, function signatures, response shapes. This skill demands proof.

## Core principle
**VERIFIED or not. There is no "probably true."** If you can't point to evidence (file:line or URL), mark it UNVERIFIED.

## Inputs

```
CLAIM: [the specific assertion to verify]
CONTEXT: [what's being built that relies on this claim]
SOURCES_TO_CHECK: [optional list of files/URLs to verify against]
```

## Process

### 1. Classify the claim type

| Type | Verify against |
|------|----------------|
| Code (function signature, import) | `Read` + `Grep` on actual source |
| DB (table/column exists) | Migration files or `pg_attribute` |
| API (response shape, status) | `curl` real endpoint or fixtures |
| Version behavior | WebFetch official changelog |
| Environment (Node version, etc.) | Workflow / Dockerfile / CI config |

### 2. Verify from authoritative source

Run the appropriate verification command. Record the evidence.

### 3. Produce verification record

```
VERIFIED   — with evidence (file:line or URL + quote)
UNVERIFIED — source not available, state explicitly
CONTRADICTED — evidence says otherwise
```

Never mark as VERIFIED without evidence.

## Common patterns

### Good fact-check

```
## FACT CHECK

Claim: "The users table has a 'last_login' column"

Result: VERIFIED

Evidence:
- migration/20260315_add_last_login.sql:3 — `ALTER TABLE users ADD COLUMN last_login TIMESTAMPTZ`
- pg_attribute confirms: users.last_login exists (type: timestamptz, notnull: false)
```

### Bad fact-check

```
The users table probably has a last_login column. I remember seeing it.
```

Problems: no evidence, "probably" = UNVERIFIED, no file:line reference.

## Anti-patterns

- **"Probably true"** — VERIFIED or not. Assumed-true = UNVERIFIED.
- **URL alone as evidence** — weak; include the specific quote/line
- **Compound claims not broken down** — "users table has id, email, last_login" → 3 claims
- **Version-specific without version check** — "In Ktor 3.0, X works" → verify in changelog
- **Memory substitution** — if source isn't accessible, mark UNVERIFIED

## How to verify

- [ ] Claim classified (code/DB/API/version/environment)?
- [ ] Verification command run (grep/read/curl/webfetch)?
- [ ] Result is VERIFIED / UNVERIFIED / CONTRADICTED?
- [ ] VERIFIED claims have file:line or URL + quote?
- [ ] Compound claims broken into atomic parts?
- [ ] Version-specific claims include version number?

## When triggered

- Before `synthesize-findings` finalizes any assertion
- Before code generation asserts behavior the researcher might be wrong about
- When user says "are you sure?"
- When `relire-critic` produces a RISQUE questioning an assertion
- Automatically on assertions about DB schemas, imports, response shapes
