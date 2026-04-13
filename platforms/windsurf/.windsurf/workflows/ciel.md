# Ciel — Deep-Reasoning Workflow

Follow the Ciel CREER pipeline for the task described below.

## Steps

1. **QUOI** — Classify depth: Trivial / Standard / Critical. Expected result in one sentence. Define NOT-X (what the solution must NOT do). What counts as "done"?

2. **AVEC QUOI** — Read real installed versions from package.json / build files. Load ciel-overlay.md if present.

3. **RECHERCHE** (Standard/Critical) — WebSearch for official docs + anti-patterns + framework philosophy. Minimum: 1 search result + 1 documented finding.

4. **SECURITE** (Critical only) — STRIDE analysis: Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation. Killer checklist: same validation everywhere? SQL parameterized? Identity server-side?

5. **CODEBASE** (Standard/Critical) — Grep existing patterns. Fitness check: same problem? same constraints? Mini repo-map: signatures, dependents, hub check.

6. **EVALUER** (Standard/Critical) — Back-of-envelope sizing. Pre-mortem: 2 ways this fails. Alternative: "I chose X over Y because [reason]." Counterfactual: "What if we do nothing?"

7. **FLUX** (Standard/Critical) — Narrate: "When user does X -> Y fires -> Z handles -> state changes -> output." Identify boundaries, assumptions, break points.

8. **FAIRE** — Implement with idiomatic gate. Quality gates: complexity < 15, nesting < 4, function < 50 lines. Alignment checkpoint at 3+ files.

9. **RELIRE** — 3 specific critiques: `RISQUE: [what could fail] parce que [root cause] -- IMPACT: [consequence]`. Resolve each: FIX / ACCEPT / DEFER.

10. **PROUVER** — Tests pass. Staging verified. CI green.

## Task

$ARGUMENTS
