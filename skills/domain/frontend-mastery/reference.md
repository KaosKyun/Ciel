# frontend-mastery — Reference

## React — bypass signals

| Signal | Why it's wrong | Idiomatic replacement |
|--------|----------------|------------------------|
| `window.location.href = ...` in component | Bypass router, breaks history/SSR | `useNavigate()` / `<Link>` / `router.push` |
| `document.getElementById(...)` | Bypass ref system | `useRef` + DOM access via ref |
| `setState` during render | Infinite loop | `useEffect` or event handler |
| `useEffect(() => fetch(), [])` | Stale closure on refetch needs | TanStack Query / SWR / built-in React 19 `use()` |
| No dependency array on `useEffect` | Runs every render | Add explicit deps |
| Mutate state directly (`state.push()`) | No re-render, stale UI | `setState([...prev, item])` |
| `any` everywhere | Erases type safety | Proper types, `unknown` with guards |

## React 19 specifics

- Server Components: async components at server boundary; no hooks inside
- `use()` hook: unwraps promises/contexts conditionally
- Actions: form mutations with `<form action={...}>` + `useActionState`
- `useOptimistic` for optimistic UI updates
- `useFormStatus` inside form children (no prop drilling)
- Transitions: `useTransition` for non-urgent state

## Vue 3 — bypass signals

| Signal | Idiomatic replacement |
|--------|------------------------|
| `this.$el` manipulation | `ref()` with template ref |
| Options API in new code (no migration) | Composition API |
| `reactive({})` for primitives | `ref(0)` |
| Prop mutation | `emit()` + parent handler |
| `v-html` with user input | `v-html` with sanitizer or avoid |

## Svelte 5 — bypass signals

| Signal | Idiomatic replacement |
|--------|------------------------|
| `$:` reactive statement in new code | `$state` + `$derived` runes |
| Manual store subscription | `$:`/`$derived` with store auto-subscribe (legacy) or runes |
| `bind:this` + DOM manipulation | `action` directive for DOM ops |

## Accessibility baseline

Every interactive element must have:
- Accessible name (label, aria-label, or text content)
- Keyboard activation (Enter + Space on buttons, arrow keys on lists)
- Focus indicator (outline visible, not suppressed)
- Screen reader text for icon-only buttons

Landmarks: `<main>`, `<nav>`, `<header>`, `<footer>` on every page.

Color contrast: WCAG AA minimum (4.5:1 normal text, 3:1 large text).

## State management decision tree

1. Local to one component? → `useState` / `ref()` / `$state`
2. Shared across 2-3 nearby components? → prop drilling or compound components
3. Cross-cutting UI state (theme, modal state)? → Context / `provide`/`inject` / Svelte context
4. Server data? → TanStack Query / SWR / Apollo
5. Cross-page complex state? → Zustand / Pinia / XState

**Anti-pattern**: Redux for everything. Redux is overkill for most apps; consider it only for time-travel debugging or very complex state machines.

## Form patterns

### Controlled form
- Each input value in state
- `onChange` updates state
- Full control, easy validation
- Performance cost on large forms (every keystroke re-renders)

### Uncontrolled with ref
- DOM owns the state
- `ref` reads on submit
- Less React overhead
- Harder to integrate with external validation

### Form library (React Hook Form, Formik, VeeValidate)
- Handles both, plus validation + errors + async submit
- Minimal re-renders
- Recommended for complex forms (> 5 fields)

## Rendering strategies

| Strategy | Use case | Framework |
|----------|----------|-----------|
| CSR (client render) | Interactive, post-login | React SPA, Vue SPA |
| SSR (server render) | SEO, fast TTFB | Next.js, Nuxt, SvelteKit |
| SSG (static) | Marketing, docs | Next.js, Astro, Docusaurus |
| ISR (incremental) | Content that changes daily | Next.js |
| RSC (React Server Components) | Default in Next.js 13+, reduce JS bundle | React 19 + Next.js |
| Streaming | Fast meaningful paint | Next.js, Remix |

## Common anti-patterns

- **useEffect fetch loops**: fetch in effect → setState → re-render → effect runs again
- **Key as index on reorderable list**: breaks React reconciliation, UI bugs
- **Derived state in state**: computing state from props in useState → use `useMemo` or compute at render
- **Prop drilling > 3 levels**: flag for context or composition
- **Styled-components inside map callback**: creates new styled component per render
- **Sync with external state via useState + useEffect**: use `useSyncExternalStore`

## Testing

- Unit: component renders correctly with props
- Integration: component + service/store interaction
- E2E: user flow across components

Use Testing Library (RTL / VTL / SvelteTL) — queries match how users see UI. Avoid querying by implementation detail (class name, test id) when accessible role works.

Mock at the right layer: server worker (MSW) for network, not individual fetch calls.
