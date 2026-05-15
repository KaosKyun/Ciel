---
name: playwright-visual-critic
description: How to review UI visually using Playwright MCP — launch dev server, capture accessibility tree (not screenshots), check layout/contrast/focus/responsive at multiple viewports, and produce structured findings. Prefers accessibility-tree analysis over pixel screenshots (deterministic, 2-5KB vs 100KB+). Requires Playwright MCP configured.
allowed-tools: Read, Grep, Glob, Bash
---

# Playwright Visual Critique — See Before Shipping UI

## What this covers

How to visually review UI using Playwright MCP. UI bugs invisible to code review: clipped text, contrast failures, broken focus order, mobile overflow. The 2026 pattern is NOT "screenshot → vision model"; it's "accessibility tree → structured critique", which is 20-50x cheaper and more accurate.

## Core principle

**Accessibility tree first, screenshots last.** Tree is deterministic, cheap, and doesn't break on font/rendering differences. Screenshots are brittle and expensive to analyze.

## Prerequisites

Playwright MCP must be installed:

```bash
# One-time setup
claude mcp add playwright --transport stdio -- npx @playwright/mcp@latest
```

Verify with: `claude mcp list | grep playwright`.

If not installed → STOP and instruct the user to run the command above. Do not attempt to critique without it.

## Methodology

### Capture via Playwright MCP

1. **`browser_navigate`** — navigate to target URL
2. **`browser_resize`** — for each viewport (375 mobile, 768 tablet, 1440 desktop)
3. **`browser_snapshot`** — accessibility tree (structured YAML/JSON)
4. **`browser_take_screenshot`** — only if visual regression check needed (cost optimization)
5. **`browser_console_messages`** — check for JS errors / a11y violations

### Visual critique checklist

**Layout**
- No horizontal overflow (no element with `scrollable: true` on x-axis for main content)
- No clipped text (elements with `hidden: true` while `expected: visible`)
- No zero-size interactive elements (touch targets ≥ 24×24px per WCAG 2.5.8)

**Contrast & color**
- Text contrast ≥ 4.5:1 (normal text) / 3:1 (large text)
- Color is not the sole signal (error states have icon/text, not just red)

**Keyboard & focus**
- Every interactive element has `focusable: true`
- Focus order matches visual order (tree `focus_index` is monotonic)
- No focus trap unless intentional (modal dialogs)
- `:focus-visible` ring is present (no `outline: none` without alternative)

**Responsive**
- At 375px width, primary content fits without zoom
- Navigation collapses to mobile pattern (drawer / bottom-nav) — not truncated desktop nav

**Semantic structure**
- One `<h1>` per page
- `<main>`, `<nav>`, `<header>`, `<footer>` landmarks present
- Form inputs have associated labels (tree `label_id` populated)

**Console**
- No JS errors
- No React / Vue / Svelte warnings
- No axe-core violations (if integrated)

## Key points

- **Do not attempt if MCP not installed** — halt cleanly with install instructions
- **Timebox**: 3 viewports × 5 minutes analysis = 15 min hard cap
- **Don't critique Lighthouse perf metrics here** — stay on visual + a11y
- **Auth-gated pages**: instruct the user to seed a test session cookie first. Do not attempt to handle login credentials
- **Local dev SSL**: use `--ignore-https-errors` in Playwright MCP config for self-signed certs

## Common anti-patterns

1. **Screenshot-first analysis**: pixel screenshots are brittle, break on font differences, and cost 20-50x more to process
2. **No viewport variation**: mobile bugs are the most common and the most missed — always test at 375px
3. **Ignoring console output**: JS errors and framework warnings often point to the root cause
4. **Critiquing without MCP installed**: will fail silently or produce empty results — always verify prerequisites

## How to verify

- **All viewports checked**: mobile, tablet, desktop — no skipped
- **Findings have selectors**: every issue points to a specific element in the accessibility tree
- **Severity classified**: BLOCK (broken), WARN (bad practice), INFO (minor)
- **Console clean**: no JS errors or framework warnings

## References

- Playwright MCP — playwright.dev/docs/getting-started-mcp
- github.com/microsoft/playwright-mcp — official implementation
- alexop.dev — "Building an AI QA Engineer with Claude Code and Playwright MCP" (real-world pattern)
- WCAG 2.2 — w3.org/WAI/WCAG22/Understanding/ (AA criteria used in the checklist)
