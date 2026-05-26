---
name: avec-quoi-versioner
description: Reads actual installed library versions from package.json, build.gradle, go.mod, Cargo.toml, pyproject.toml, Gemfile.lock — never trusts memory or assumptions. Loads ciel-overlay.md if present for project-specific stack context. Invoked before research to ensure all subsequent docs lookups target the correct versions.
allowed-tools: Read, Grep, Glob, Bash
---

# avec-quoi-versioner — Read real installed versions

Step 2 of CRÉER. The research quality is bounded by version accuracy. A skill that looks up "Ktor 2.x docs" when the project runs Ktor 3.x produces anti-patterns.

---

## Process

### 1. Detect package manager(s)

Scan project root for the following files (in order):

| File | Stack |
|------|-------|
| `package.json` + `package-lock.json` | npm / Node.js |
| `package.json` + `yarn.lock` | yarn |
| `package.json` + `pnpm-lock.yaml` | pnpm |
| `package.json` + `bun.lockb` | bun |
| `build.gradle.kts` / `build.gradle` | JVM / Gradle |
| `pom.xml` | Maven |
| `go.mod` + `go.sum` | Go |
| `Cargo.toml` + `Cargo.lock` | Rust |
| `pyproject.toml` + `poetry.lock` / `uv.lock` | Python |
| `requirements.txt` | Python (pip) |
| `Gemfile` + `Gemfile.lock` | Ruby |
| `composer.json` | PHP |
| `Package.swift` / `Package.resolved` | Swift |

Multiple lockfiles may exist (monorepo). Read them all.

### 2. Extract exact versions (not semver ranges)

For each relevant dependency in the task scope:

- Read the **lockfile** for the pinned version (not `package.json`'s range)
- For Gradle, run `./gradlew dependencies` if needed, or read `gradle.properties`
- For Go, `go.mod` already pins; verify with `go list -m all`
- For Maven, effective POM: `mvn help:effective-pom`

### 3. Load ciel-overlay.md

If present at project root, extract:

- `## Stack` section — project's declared stack
- `## Versions` section — URLs to docs
- Any project-specific rules in `## Règles projet-spécifiques`

### 4. State assumptions explicitly

For anything NOT verified from lockfile:

- "Assuming build tool X because [reason]."
- "Assuming PostgreSQL is running on default port because [reason]."

These assumptions must be flagged for `researcher` to verify.

---

## Output format

```
## AVEC QUOI

Stack detected:
- Frontend: <framework> <version> (from <file>)
- Backend: <framework> <version> (from <file>)
- Database: <type> <version> (from <file or overlay>)
- Test: <framework> <version> (from <file>)
- Build: <tool> <version>

Overlay:
- [Loaded: yes/no]
- [Relevant sections: Stack, Versions, Règles, Leçons]

Assumptions (NOT from lockfile):
- <assumption> — <reason>

Docs URLs (from overlay):
- <lib>: <url>
```

---

## Guardrails

- **Never assume a version** — if lockfile is absent, state "version unknown" and flag it
- **Range vs pinned**: always report the pinned version from the lockfile, not the `^1.2.3` range from the manifest
- **Monorepo caution**: multiple lockfiles may diverge across packages. Specify which package the version applies to.
- **Don't guess URLs**: only report doc URLs from the overlay. Let `researcher` agent WebSearch for the rest.

---

## How to verify

- [ ] Versions read from lock files (not package.json ranges)?
- [ ] ciel-overlay.md consulted for project-specific versions?
- [ ] Framework detected (React/Vue/Svelte/Ktor/Express/etc)?
- [ ] Version gaps flagged (installed vs latest)?
- [ ] Overlay updated if new versions discovered?

## When triggered

- Standard/Critical tasks, immediately after `quoi-framer`
- Before dispatching `researcher` agent (research quality depends on version accuracy)
- When user asks "what versions are we on?" or the task mentions a specific library
