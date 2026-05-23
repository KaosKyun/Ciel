---
name: frontend-mastery
description: Expert patterns for React, Vue, Svelte, Solid frontend development — hooks, state management, routing, forms, accessibility, rendering. Auto-activates on .tsx, .jsx, .vue, .svelte files. Focuses on idiomatic patterns, common bypass signals, and anti-patterns the framework wants you to avoid.
allowed-tools: Read, Grep, WebFetch
paths: "**/*.{tsx,jsx,vue,svelte,js,ts}"
---

# frontend-mastery — Frontend expert knowledge

## What this covers
Framework-idiomatic patterns + bypass signals specific to the component model. Ensures code matches how the framework WANTS problems solved, not just how they CAN be solved.

## Core principle
**Framework philosophy first.** If React 19 wants data fetching on the server, don't fetch on the client. If Svelte 5 uses runes, don't use stores. Match the framework's intent.

## Key patterns (2026)

### React 19 — Server-first rendering

```jsx
// ❌ BEFORE: Client waterfall
function Author({id}) {
  const [author, setAuthor] = useState('');
  useEffect(() => { fetch(`/api/authors/${id}`).then(d => setAuthor(d)); }, [id]);
  return <span>{author.name}</span>;
}

// ✅ AFTER: Server Component (default in React 19)
async function Author({id}) {
  const author = await db.authors.get(id);
  return <span>{author.name}</span>;
}
```

- Server Components are the default — no `"use client"` needed for static rendering
- `use()` hook replaces `useEffect` for data fetching in client components
- Push `"use client"` boundaries down — keep client tree minimal
- Suspense + `use()` for priority splitting

### Svelte 5 — Runes over stores

```svelte
<!-- ❌ BEFORE: Svelte 4 store -->
<script>
  import { writable } from 'svelte/store';
  const count = writable(0);
</script>

<!-- ✅ AFTER: Svelte 5 rune -->
<script>
  let count = $state(0);
</script>
```

### Vue 3 — Composition API + `ref()`

```vue
<!-- ❌ BEFORE: Options API -->
<script>
export default {
  data() { return { count: 0 } },
  methods: { increment() { this.count++ } }
}
</script>

<!-- ✅ AFTER: Composition API -->
<script setup>
const count = ref(0);
const increment = () => count.value++;
</script>
```

## Bypass signals to detect

- Direct DOM manipulation when framework provides the abstraction
- Global state mutation when local state or context suffices
- Side effects during render (React: `setState` in render body)
- Stale closures over mutable data (React hooks + event handlers)
- `useEffect` + fetch when Server Components suffice
- `"use server"` on components (it's for Server Functions, not components)
- Accessibility gaps: missing aria attributes, keyboard navigation, focus management

## Anti-patterns

- **Client-side data waterfall** — `useEffect` chains → use Server Components
- **Over-hydration** — shipping interactive JS for static content
- **Store overuse** — global store for component-local state
- **`useEffect` for synchronization** — `useSyncExternalStore` or `use()` instead
- **Missing cleanup** — event listeners, subscriptions, abort controllers in `useEffect`

## How to verify

- [ ] Server Components used for data fetching (not `useEffect` + fetch)?
- [ ] `"use client"` boundaries pushed down (minimal client tree)?
- [ ] State management: local > context > external store (correct escalation)?
- [ ] Effect dependency arrays complete and correct?
- [ ] Cleanup functions present for subscriptions/listeners?
- [ ] Accessibility: aria attributes, keyboard navigation, focus management?
- [ ] Framework version-specific patterns used (React 19 ≠ 18, Svelte 5 ≠ 4)?

## When triggered

- `explorer` agent parallel dispatch when frontend files detected
- Task mentions component / UI / form / routing
- `paths` glob auto-activates on `.tsx/.jsx/.vue/.svelte/.js/.ts`

## References

- React 19 RSC — https://react.dev/reference/rsc/server-components
- Svelte 5 runes — https://svelte.dev/docs/svelte/$state
- Vue 3 Composition — https://vuejs.org/guide/extras/composition-api-faq.html
