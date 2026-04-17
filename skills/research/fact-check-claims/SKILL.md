---
name: fact-check-claims
description: Before asserting any API/version/behavior claim in code or reports, greps the source code or fetches docs to verify. Guards against the "false confidence" failure mode — confident assertions without evidence. Invoked before any assertion is committed to the final output, especially around DB schemas, import paths, response shapes, and version-specific behavior.
allowed-tools: Read, Grep, WebFetch
context: fork
agent: Explore
---

# fact-check-claims — Verify before asserting

Meta-research skill #6 of 6. The guard against false confidence. LLMs routinely state confidently wrong things — DB column names, function signatures, response shapes. This skill demands proof.

---

## Inputs

```
CLAIM: [the specific assertion to verify — e.g. "The users table has a 'last_login' column"]
CONTEXT: [what's being built that relies on this claim]
SOURCES_TO_CHECK: [optional list of files/URLs to verify against]
```

---

## Process

### 1. Classify the claim type

- **Code claim**: function signature, import path, type definition → verify in source
- **DB claim**: table exists, column exists, index exists → verify in migrations or schema
- **API claim**: response shape, HTTP status, header → verify in real response or docs
- **Version claim**: "In Ktor 3.0.0, X behaves like Y" → verify in changelog or release notes
- **Environment claim**: "CI uses Node 20" → verify in workflow file

### 2. Verify from authoritative source

| Claim type | Verify against |
|-----------|----------------|
| Code | `Read` + `Grep` on actual source file |
| DB schema | `Read` migration files OR `pg_attribute` via Bash |
| API response | `curl` real endpoint OR real response saved in repo fixtures |
| Version behavior | WebFetch official changelog for that version |
| Environment | `Read` workflow / Dockerfile / CI config |

### 3. Produce verification record

For each claim, record:
- VERIFIED with evidence (file:line or URL + quote)
- UNVERIFIED — source not available, state explicitly
- CONTRADICTED — evidence says otherwise, provide the contradicting finding

Never mark as VERIFIED without evidence.

---

## Output format

```
## FACT CHECK

Claim: "<exact claim>"

Result: <VERIFIED | UNVERIFIED | CONTRADICTED>

Evidence:
- <file:line with quote>
- <URL with relevant excerpt>

[If UNVERIFIED]
Missing sources: <what couldn't be checked and why>
Recommendation: <how to proceed — don't assert until verified, or accept uncertainty>

[If CONTRADICTED]
Contradicting finding: <what source actually says>
Correction: <the corrected claim>
```

---

## Guardrails

- **No "probably true"**: VERIFIED or not. Assumed-true claims get UNVERIFIED status.
- **Evidence granularity**: a URL alone is weak; include the specific quote/line
- **Claim atomicity**: break compound claims into atomic parts — "The users table has columns `id`, `email`, `last_login`" → 3 claims to verify individually
- **Version-sensitivity**: version-specific claims MUST include version verification
- **Don't substitute memory**: if the source to verify against isn't accessible, mark UNVERIFIED — don't fill with "I think I remember this"

---

## When triggered

- Before `synthesize-findings` finalizes any assertion
- Before code generation asserts behavior the researcher might have been wrong about
- When user says "are you sure?"
- When `relire-critic` produces a RISQUE that questions an assertion
- Automatically on any assertion about DB schemas, import paths, response shapes
