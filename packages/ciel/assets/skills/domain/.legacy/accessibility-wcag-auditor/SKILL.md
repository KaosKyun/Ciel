---
name: accessibility-wcag-auditor
description: Audits UI code and rendered output against WCAG 2.2 Level AA (2026 legal baseline — ADA Title II, EN 301 549). Covers the new 2.2 success criteria (Focus Not Obscured 2.4.11, Target Size 2.5.8, Accessible Authentication 3.3.8), plus contrast ratios, keyboard navigation, semantic HTML, ARIA correctness, and Core Web Vitals for accessibility (INP < 200ms). Runs via axe-core + manual review. Invoked on any frontend PR.
allowed-tools: Read, Grep, Glob, Bash
---

# accessibility-wcag-auditor — WCAG 2.2 AA is the 2026 floor

Automated tools catch 30-57% of a11y violations (WAI; Deque). The other 40% require manual review of semantics, keyboard flow, and intent. This skill covers both.

---

## Inputs

```
FRONTEND_FILES: [components / pages / templates in the diff]
RENDERED_URL: [if available — feeds playwright-visual-critic]
INTERACTIVE_PATTERNS: [modals, menus, forms, tabs — which are in the diff?]
```

---

## WCAG 2.2 AA — full criteria coverage

### Perceivable

- **1.1.1 Non-text Content** — every `<img>` has `alt` (empty `alt=""` for decorative, meaningful for content); every icon-only button has `aria-label`.
- **1.3.1 Info and Relationships** — use semantic HTML (`<nav>`, `<main>`, `<article>`, headings in order). Don't use `<div role="button">` where `<button>` works.
- **1.3.5 Identify Input Purpose** — `<input autocomplete="email|tel|postal-code|cc-number|...">` on forms.
- **1.4.3 Contrast (Minimum)** — 4.5:1 for normal text, 3:1 for large text (≥ 18pt or 14pt bold), 3:1 for UI components (WCAG 2.2).
- **1.4.10 Reflow** — no horizontal scroll at 320px width (except for content like data tables where scroll is the accepted fallback).
- **1.4.11 Non-text Contrast** — 3:1 for UI controls and graphical objects.
- **1.4.13 Content on Hover or Focus** — dismissible, hoverable, persistent.

### Operable

- **2.1.1 Keyboard** — all functionality via keyboard (no mouse-only interactions).
- **2.1.2 No Keyboard Trap** — Escape closes modals; Tab loops correctly.
- **2.4.3 Focus Order** — logical tab sequence matches visual order.
- **2.4.7 Focus Visible** — `:focus-visible` ring present; never `outline: none` without replacement.
- **2.4.11 Focus Not Obscured (WCAG 2.2 new)** — focused element not hidden behind sticky headers/footers. Check: `scroll-padding-top: 80px` or equivalent when sticky header is 80px tall.
- **2.5.8 Target Size (Minimum) (WCAG 2.2 new)** — interactive targets ≥ 24×24 CSS pixels (exceptions: inline text links, user-agent-default, equivalents of that size).
- **2.5.7 Dragging Movements (WCAG 2.2 new)** — if drag-and-drop exists, provide a single-pointer alternative (click-to-select-and-place).

### Understandable

- **3.2.2 On Input** — changing a form input doesn't auto-submit or navigate without warning.
- **3.3.2 Labels or Instructions** — every input has a `<label for>` OR `aria-label`/`aria-labelledby`. Placeholder is NOT a label.
- **3.3.7 Redundant Entry (WCAG 2.2 new)** — don't re-ask info the user gave earlier in the same session (pre-fill or make available).
- **3.3.8 Accessible Authentication (WCAG 2.2 new)** — no cognitive-test-as-auth (unless accessible alternative exists). Passwords + SSO are fine; image-puzzle CAPTCHA without audio alternative FAILS.

### Robust

- **4.1.2 Name, Role, Value** — custom components expose correct ARIA role + accessible name + current state (e.g., `<div role="checkbox" aria-checked="true">`).
- **4.1.3 Status Messages** — toasts/alerts use `role="status"` or `role="alert"`.

---

## Detection — automated layer

```bash
# 1. Lint with eslint-plugin-jsx-a11y (React) or equivalent
npx eslint --ext .tsx,.jsx src/

# 2. Run axe-core in test env
npx playwright test --project=chromium -- --grep @a11y

# 3. Lighthouse CI accessibility score ≥ 95
npx lhci autorun
```

If any of these aren't set up → suggest adding them (not a blocker, but a debt item).

---

## Detection — manual layer (what tools miss)

1. **Semantic correctness** — read the JSX/HTML. Are landmarks right? One `<h1>`? Headings in order (no h1→h3 jumps)?
2. **Keyboard walkthrough** — mentally tab through the page. Does focus go everywhere it should? Does it skip ornament? Can you activate every button with Enter/Space?
3. **Label correctness** — does every input label actually describe what to enter? Or is it a CSS-placeholder pattern?
4. **Error recovery** — when a form submits with errors, does focus move to the first error? Is the error text associated with the input via `aria-describedby`?
5. **Modal correctness** — Escape closes, focus returns to trigger, focus trapped inside while open, `aria-modal="true"`, initial focus on a sensible element.

---

## Report format

```
## A11Y AUDIT (WCAG 2.2 AA)

### Automated layer
- eslint-plugin-jsx-a11y: 3 errors, 8 warnings
- axe-core: 2 violations (serious), 5 (moderate)
- Lighthouse a11y score: 87 (target ≥ 95)

### Manual findings
[BLOCK] components/LoginForm.tsx:28 — placeholder used as label (`<input placeholder="Email" />` no `<label>`)
        Criterion 3.3.2 — label required
        Fix: add `<label htmlFor="email">Email</label>` + `id="email"`

[BLOCK] components/Modal.tsx — no focus trap, Escape key does nothing
        Criterion 2.1.2 + 2.4.3
        Fix: use <dialog> native element OR focus-trap-react

[WARN]  components/Header.tsx — sticky header 80px; focus ring obscured on tall elements below
        Criterion 2.4.11 (WCAG 2.2 new)
        Fix: `scroll-padding-top: 80px` on the scrolling container

[WARN]  components/IconButton.tsx — target 20×20px
        Criterion 2.5.8 (WCAG 2.2 new)
        Fix: wrap with `padding` to reach 24×24 hit area

[INFO]  components/UserList.tsx — color-only status (red dot for offline)
        Criterion 1.4.1
        Fix: add sr-only text or icon + label

### Summary
BLOCK: 2  — legal compliance risk (ADA / EN 301 549)
WARN:  2  — WCAG 2.2 new criteria (new enforcement from April 2026)
INFO:  1

### Quick wins
1. Add proper labels to all form inputs (est 15 min)
2. Switch to native `<dialog>` for modal (est 30 min)
```

---

## How to verify

- [ ] Automated layer: eslint-plugin-jsx-a11y + axe-core + Lighthouse?
- [ ] All images have alt text (empty for decorative)?
- [ ] Form inputs have `<label>` (not placeholder-only)?
- [ ] Focus visible (`:focus-visible` ring, no `outline: none`)?
- [ ] Contrast ratios meet 4.5:1 (text) / 3:1 (UI components)?
- [ ] Keyboard: all functionality accessible, no traps?
- [ ] WCAG 2.2 new: Focus Not Obscured (2.4.11), Target Size (2.5.8)?

## Guardrails

- **Legal baseline**: WCAG 2.2 AA is mandated by ADA Title II (April 2026) and EN 301 549 (EU). BLOCK findings are legal risk, not stylistic.
- **Don't over-ARIA**: `role="button"` on a `<button>` is wrong. `aria-label` on an element with visible text that already matches is wrong. No ARIA is better than wrong ARIA.
- **Color contrast tool**: use an actual calculator (`@adobe/leonardo-contrast-colors` or browser DevTools), not eyeballing.
- **Test with real AT** (assistive tech) when stakes are high — VoiceOver on macOS, NVDA on Windows. Automated + manual + real AT is the full pipeline.
- **Cognitive accessibility** is under-covered by automation — plain language, predictable flows, error tolerance. Flag as INFO where evident.
- **Don't gate non-UI PRs** — a backend change doesn't require this audit.

---

## When triggered

- Any PR touching `components/`, `pages/`, templates, or CSS affecting layout/color
- Pre-release of a user-facing feature
- After `playwright-visual-critic` captures accessibility tree
- User command: "audit this for accessibility"

---

## References

- WCAG 2.2 official — w3.org/WAI/WCAG22/
- WebAIM contrast checker — webaim.org/resources/contrastchecker/
- axe-core — github.com/dequelabs/axe-core
- MDN ARIA — developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA
- ADA Title II final rule — justice.gov (April 2024, enforcement April 2026)
