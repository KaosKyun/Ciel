# AGENTS.md — Ciel deep-reasoning workflow (Codex, v3.0.0)

Source: https://github.com/KaosKyun/Ciel

Principle: **"Understand before generating. Verify before claiming done."**

Ciel is installed as Codex-native primitives:

- **Hook** (`.codex/hooks.json`) — `UserPromptSubmit` injects depth-classification hint into every prompt.
- **Subagents** (`.codex/agents/ciel-*.md`) — spawn with `@ciel-researcher`, `@ciel-explorer`, `@ciel-critic`, `@ciel-improver`.
- **Commands** (`.codex/commands/ciel*.md`) — invoke with `/ciel`, `/ciel-improve`, `/ciel-eval`, `/ciel-create-skill`, `/ciel-recommend`, `/ciel-update`.

---

## Depth gauge — classify BEFORE starting

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-line fix | quoi-framer → pattern-fitness-check → faire-gatekeeper → inline review → push |
| **Standard** | hook, route, component, service | Full pipeline, spawn @ciel-researcher + @ciel-explorer in parallel before coding |
| **Critical** | auth, DB schema, security, payment | Full pipeline + STRIDE threat model + @ciel-critic mandatory |

Unsure → Standard. Touching user data or auth → Critical.

---

## 10-step pipeline (condensed)

1. **QUOI** — 1-sentence goal + NOT-X + definition of done
2. **AVEC QUOI** — read installed versions (not memory), load overlay
3. **RECHERCHE** — `@ciel-researcher` (Standard+Critical): official docs + anti-patterns + version changelog
4. **SÉCURITÉ** — STRIDE + killer checklist (Critical only)
5. **CODEBASE + FLUX** — `@ciel-explorer`: pattern fitness + data flow narration
6. **ÉVALUER** — sizing + 2 failure modes + alternatives + counterfactual
7. **FAIRE** — test-first (RED), alternatives gate, idiomatic gate, removal gate
8. **RELIRE** — `@ciel-critic` MODE=RELIRE: 3 RISQUE (functional + imports + data) + FIX/ACCEPT/DEFER
9. **PROUVER** — AVANT/APRÈS evidence + CI gate + PR body + issue comment
10. **META** — 30s post-task reflection: depth match? failure mode? user correction?

---

## Top 10 Guards

1. "I already know this" = red flag — research first
2. Verify before asserting — no citation = don't know it
3. DB columns: verify real schema before query
4. Test URL host:port must match handler host:port
5. Pattern copied blindly → fitness check fails
6. Self-critique in same context = same blind spots → spawn @ciel-critic
7. No alternative considered → back to ÉVALUER
8. Scope drift at 3+ files → re-read QUOI
9. Write test FIRST (RED), not after
10. "No error in logs" ≠ proof — trigger scenario, see positive signal

---

## Automatic context injection (hook)

The `.codex/hooks.json` `UserPromptSubmit` hook classifies depth from your prompt and appends a hint via `additionalContext`. The hint fires on every prompt — you don't need to invoke Ciel manually.
