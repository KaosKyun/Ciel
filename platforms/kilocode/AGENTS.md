# AGENTS.md — Ciel deep-reasoning workflow (Kilo Code, v2.8.0)

Source: https://github.com/KaosKyun/Ciel

Principle: **"Understand before generating. Verify before claiming done."**

Ciel is installed as Kilo Code-native primitives:

- **Rules** (`.kilocode/rules/ciel.md`) — always-on depth guards + prose hook equivalents.
- **Subagents** (`.kilo/agents/ciel-*.md`) — invoke with `@ciel-researcher`, `@ciel-explorer`, `@ciel-critic`, `@ciel-improver`.
- **No hooks** — pre/post-write behavior is documented as prose guards in the rules file.

---

## Depth gauge

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-line fix | quoi-framer → pattern-fitness-check → inline review → push |
| **Standard** | hook, route, component | Full pipeline, dispatch @ciel-researcher + @ciel-explorer in parallel |
| **Critical** | auth, DB schema, security | Full pipeline + STRIDE + @ciel-critic mandatory |

---

## 10-step pipeline (condensed)

1. QUOI — 1-sentence goal + NOT-X + definition of done
2. AVEC QUOI — real installed versions (not memory)
3. RECHERCHE — `@ciel-researcher` (Standard+Critical)
4. SÉCURITÉ — STRIDE (Critical only)
5. CODEBASE + FLUX — `@ciel-explorer`
6. ÉVALUER — sizing + 2 failure modes + alternatives
7. FAIRE — test-first (RED); alternatives gate; idiomatic gate
8. RELIRE — `@ciel-critic` MODE=RELIRE: 3 RISQUE + FIX/ACCEPT/DEFER
9. PROUVER — AVANT/APRÈS evidence + CI gate
10. META — 30s reflection

---

## Dispatch rules

| Agent | When |
|-------|------|
| `@ciel-researcher` | RECHERCHE (Standard+Critical) — isolated, no session bias |
| `@ciel-explorer` | CODEBASE+FLUX (Standard+Critical) — reads codebase fresh |
| `@ciel-critic` | RELIRE after FAIRE (Critical always; Standard if 3+ files or auth/security) |
| `@ciel-improver` | On `/ciel-improve` only |

Dispatch `@ciel-researcher` + `@ciel-explorer` **IN PARALLEL** before writing code.
