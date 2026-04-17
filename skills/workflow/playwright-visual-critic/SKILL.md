---
name: playwright-visual-critic
description: Wraps Playwright MCP to give Ciel visual critique capability — launches the dev server, navigates to a target page, captures the accessibility tree and (optionally) a screenshot, then dispatches @ciel-critic to analyze layout, contrast, focus order, and responsive behavior. Prefers accessibility-tree analysis over pixel screenshots (deterministic, 2-5KB vs 100KB+). Requires Playwright MCP to be configured (install with `bash install.sh --with-mcp=playwright`).
allowed-tools: Read, Grep, Glob, Bash
context: fork
agent: explorer
---

# playwright-visual-critic — See before shipping UI

UI bugs invisible to code review: clipped text, contrast failures, broken focus order, mobile overflow. The 2026 pattern is NOT "screenshot → vision model"; it's "accessibility tree → structured critique", which is 20-50x cheaper and more accurate.

---

## Prerequisites

Playwright MCP must be installed and registered:

```bash
# One-time setup
bash ~/.claude/plugins/ciel/scripts/install.sh --with-mcp=playwright

# OR manually (Claude Code)
claude mcp add playwright --transport stdio -- npx @playwright/mcp@latest
```

Verify with: `claude mcp list | grep playwright`.

If not installed → STOP and instruct the user to run the command above. Do not attempt to critique without it.

---

## Inputs

```
TARGET_URL: [http://localhost:3000/page OR a deployed preview URL]
VIEWPORT: [mobile | tablet | desktop | all]
FOCUS_AREAS: [layout | contrast | keyboard-nav | responsive | all]
RECENT_CHANGES: [components/pages modified in the current diff]
```

---

## Phase 1 — Launch environment

If TARGET_URL is a local dev server:
```bash
# In a separate terminal or background
npm run dev &
# Wait for it to be responsive
until curl -sf "$TARGET_URL" > /dev/null; do sleep 1; done
```

If dev server isn't up, halt and request it.

---

## Phase 2 — Capture via Playwright MCP

Invoke Playwright MCP tools in this order:

1. **`browser_navigate`** — `{ url: TARGET_URL }`
2. **`browser_resize`** — for each viewport in VIEWPORT (375 mobile, 768 tablet, 1440 desktop)
3. **`browser_snapshot`** — accessibility tree (returns structured YAML/JSON)
4. **`browser_take_screenshot`** — only if VISUAL_REGRESSION=true (cost optimization)
5. **`browser_console_messages`** — check for JS errors / a11y violations

Save each snapshot to `/tmp/ciel-visual-<id>/<viewport>.yaml`.

---

## Phase 3 — Dispatch @ciel-critic

Because OpenCode plugin hooks (`tool.execute.before/after`) do NOT see MCP tool calls (gap #2319), the critic MUST be dispatched explicitly — auto-dispatch won't trigger.

Prompt to critic:
```
MODE=VISUAL
ACCESSIBILITY_TREE_PATHS: [/tmp/ciel-visual-<id>/mobile.yaml, .../desktop.yaml]
SCREENSHOT_PATHS: [optional]
FOCUS_AREAS: [list from input]
CONTEXT: [recent PR diff affecting the target pages]
```

The critic runs the `relire-critic` + `accessibility-wcag-auditor` checks on the captured state.

---

## Phase 4 — Visual critique checklist

Critic must verify per viewport:

### Layout
- [ ] No horizontal overflow (accessibility tree has no element with `scrollable: true` on x-axis for main content)
- [ ] No clipped text (elements with `hidden: true` while `expected: visible`)
- [ ] No zero-size interactive elements (touch targets ≥ 24×24px per WCAG 2.5.8)

### Contrast & color
- [ ] Text contrast ≥ 4.5:1 (normal text) / 3:1 (large text) — report any `contrast_ratio < threshold` from the accessibility tree
- [ ] Color is not the sole signal (error states have icon/text, not just red)

### Keyboard & focus
- [ ] Every interactive element in the tree has `focusable: true`
- [ ] Focus order matches visual order (tree `focus_index` is monotonic through the visual hierarchy)
- [ ] No focus trap unless intentional (modal dialogs)
- [ ] `:focus-visible` ring is present (no `outline: none` without alternative)

### Responsive
- [ ] At 375px width, primary content fits without zoom
- [ ] Navigation collapses to mobile pattern (drawer / bottom-nav) — not truncated desktop nav

### Semantic structure
- [ ] One `<h1>` per page
- [ ] `<main>`, `<nav>`, `<header>`, `<footer>` landmarks present
- [ ] Form inputs have associated labels (tree `label_id` populated)

### Console
- [ ] No JS errors
- [ ] No React / Vue / Svelte warnings
- [ ] No axe-core violations (if integrated)

---

## Output format

```
## VISUAL CRITIQUE

### Target
<url> — <3 viewports captured>

### Findings by viewport
**Mobile (375px)**
[BLOCK] <selector> — text clipped ("Subscri...")
[WARN]  <selector> — contrast 3.2:1 (needs 4.5:1)
[INFO]  <selector> — touch target 22×22px (needs ≥24×24)

**Tablet (768px)**
(none)

**Desktop (1440px)**
[WARN] <selector> — focus order skips the language selector

### Console
[BLOCK] Uncaught TypeError: x is undefined (at bundle.js:4213)

### Summary
BLOCK: 2
WARN:  2
INFO:  1

### Recommended fixes
1. <selector>: `max-width: 100%` + `overflow-wrap: anywhere`
2. <selector>: change background to #<hex> for 4.5:1
3. <selector>: add `tabindex="3"` or restructure DOM order
```

---

## Guardrails

- **Accessibility tree first, screenshots last** — tree is deterministic, screenshots are brittle and expensive to analyze.
- **Do not attempt if MCP not installed** — halt cleanly with install instructions.
- **Timebox**: 3 viewports × 5 minutes analysis = 15 min hard cap.
- **Don't critique Lighthouse perf metrics here** — that's `performance-engineering`'s job. Stay on visual + a11y.
- **Auth-gated pages**: if TARGET_URL requires login, instruct the user to seed a test session cookie first. Do not attempt to handle login credentials in the skill.
- **Local dev SSL**: if the dev server uses self-signed certs, use `--ignore-https-errors` in the Playwright MCP config, not by disabling cert checks globally.

---

## When triggered

- Any PR touching `components/` or `pages/` in a frontend project
- User command: "review this UI / critique this page"
- After a large CSS refactor (safety net)
- Before shipping a new public page

---

## References

- Playwright MCP — playwright.dev/docs/getting-started-mcp
- github.com/microsoft/playwright-mcp — official implementation
- alexop.dev — "Building an AI QA Engineer with Claude Code and Playwright MCP" (real-world pattern)
- WCAG 2.2 — w3.org/WAI/WCAG22/Understanding/ (AA criteria used in the checklist)
