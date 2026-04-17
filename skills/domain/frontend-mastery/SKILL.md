---
name: frontend-mastery
description: Expert patterns for React, Vue, Svelte, Solid frontend development — hooks, state management, routing, forms, accessibility, rendering. Auto-activates on .tsx, .jsx, .vue, .svelte files. Invoked in parallel with researcher agent during CODEBASE/FLUX steps when frontend stack is detected. Focuses on idiomatic patterns, common bypass signals, and anti-patterns the framework wants you to avoid.
allowed-tools: Read, Grep, WebFetch
context: fork
agent: Explore
paths: "**/*.{tsx,jsx,vue,svelte,js,ts}"
---

# frontend-mastery — Frontend expert knowledge

Applied in parallel with `researcher` when a frontend task is detected. Contributes framework-idiomatic patterns + bypass signals specific to the component model.

For framework-specific cheatsheets (React, Vue, Svelte), see `reference.md`.

---

## Inputs

```
TASK: [1-sentence description]
STACK: [React | Vue | Svelte | Solid | other]
VERSION: [exact version from avec-quoi-versioner]
```

---

## Process

### 1. Identify framework

From stack + file extensions:
- `.tsx`/`.jsx` → React
- `.vue` → Vue
- `.svelte` → Svelte
- `.astro` → Astro (may embed React/Vue/Svelte)

### 2. Apply framework-specific pattern checks

- **Component boundaries**: is logic in the right layer (hook / component / service)?
- **State management**: local vs context vs external store — correct choice for use case?
- **Effect hygiene**: dependency arrays, cleanup functions, race conditions
- **Form patterns**: controlled vs uncontrolled, validation timing, accessibility
- **Routing**: framework router vs manual `window.location` bypass
- **Rendering**: server-side / client-side / streaming — match framework intent

### 3. Flag bypass signals

See `reference.md` for the full list per framework. Common across frameworks:

- Direct DOM manipulation when framework provides the abstraction
- Global state mutation when local state or context suffices
- Side effects during render (React: `setState` in render body)
- Stale closures over mutable data (React hooks + event handlers)
- Accessibility gaps: missing aria attributes, keyboard navigation, focus management

### 4. Cross-reference with researcher output

Apply knowledge from `synthesize-findings` (official docs + version changelog) to this domain. If framework docs say X but the codebase does Y → flag as ADAPT or DO NOT USE in pattern-fitness-check.

---

## Output format

```
## FRONTEND DOMAIN INSIGHTS — <framework> <version>

### Pattern recommendations
- <pattern> — <when to use> — <framework reason>

### Bypass signals detected
- <file:line> — <signal> — <suggested idiomatic replacement>

### Accessibility check
- <aria/keyboard/focus> — <status>

### Version-specific notes
- <feature> changed in <version> — <impact>

### CROSS-REFERENCES
- Conflicts with researcher findings: <none | list>
```

---

## Guardrails

- **Don't duplicate researcher output** — this skill adds framework-specific expertise; research is version-specific docs
- **Accessibility is not optional** — every frontend change touches a11y implicitly; flag gaps
- **Framework philosophy first** — if framework wants declarative state, propose declarative even if imperative works
- **Version-aware** — React 19 RSC differs from React 18; Vue 3 Composition differs from Options; Svelte 5 runes differ from 4

---

## When triggered

- `explorer` agent parallel dispatch when frontend files detected
- Task mentions component / UI / form / routing
- `paths` glob auto-activates on `.tsx/.jsx/.vue/.svelte/.js/.ts`
