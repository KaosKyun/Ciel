---
name: research-web-sources
description: Fetches official documentation via WebFetch and searches best practices via WebSearch for a specific library+version. Produces findings with version-stamped URLs and at least 1 anti-pattern. Invoked in the RECHERCHE step of Standard and Critical Ciel tasks, dispatched by the researcher agent in fork context.
allowed-tools: WebSearch, WebFetch
context: fork
agent: Explore
---

# research-web-sources — Official docs + best practices

Meta-research skill #1 of 6. Fetches the primary source (official docs) + best-practice blog posts / maintainer articles for a specific library+version.

---

## Inputs

```
TASK: [1-sentence description]
TECHNOLOGY: [lib name]
VERSION: [exact installed version — from avec-quoi-versioner]
QUESTION: [specific question]
```

---

## Process

### 1. Fetch official documentation

- Primary: WebFetch the official docs URL (from `ciel-overlay.md` or derived)
- If docs for the exact version aren't available, fetch the latest + note the version gap
- Focus on the specific API/feature in question — don't fetch whole doc site

### 2. WebSearch for best practices

Queries (run at least 2):
- `[feature] [lib] [version] best practices`
- `[feature] [lib] idiomatic way`
- Quote multiple sources if available

### 3. Identify framework philosophy

From docs: how does this framework WANT this problem solved? Not just what the API is — the intended approach.

- "In Ktor 3, pagination is handled via query params on routes, leveraging the built-in `call.parameters` API. The framework prefers explicit over magic."
- "In React 19, state updates are co-located with components via hooks; global state via Context or external stores like Zustand is reserved for truly cross-cutting concerns."

### 4. Extract anti-patterns (MANDATORY — at least 1)

Queries:
- `[lib] [feature] common mistakes anti-patterns`
- `[lib] [version] pitfalls avoid`

Cite at least one documented anti-pattern with source URL.

---

## Output format

```
## RESEARCH — <tech> <version>

### FINDINGS
- <finding — specific, with version>
- <finding — include source URL>

### ANTI-PATTERNS À ÉVITER
- <anti-pattern> — <source URL or "official docs">

### PHILOSOPHY DU FRAMEWORK
<1-2 sentences: how the framework wants this solved>

### API SURFACE (verified)
- <import/function verified at: URL or file:line>
- <response format verified from: source>

### INCERTITUDES
- <unknown — flagged for main session>
```

---

## Guardrails

- **Minimum output**: ≥ 1 WebSearch result + ≥ 1 documented finding. Zero output = step not done.
- **Version stamp required**: every finding includes the version it applies to
- **Docs contradict memory → trust docs**
- **Docs unavailable**: state it explicitly, don't fill gaps with assumptions
- **No preamble**: return only the structured report, no "I found that..."

---

## When triggered

- `researcher` agent, RECHERCHE step on Standard/Critical tasks
- User explicit request: "research <lib> <feature>"
- When task mentions a library that's not fully understood
