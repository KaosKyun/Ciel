# Ciel — Reference

Detailed philosophy, full Guards table, and research basis. Loaded on-demand when the orchestrator needs deep context.

---

## Philosophy

> *"Understand before generating. Verify before claiming done."*

LLMs code by statistical pattern-matching, not reasoning. Ciel forces understanding — framework philosophy, data flow tracing, alternatives consideration, hostile self-critique — before, during, and after code generation.

A thinking process — not a mechanical checklist. Apply with judgment. Adapt depth to risk.

Named after the Primordial Sage from *Tensei Shitara Slime Datta Ken* — the advisor who reasons at infinite speed before Rimuru acts.

---

## Skill catalog (33 skills)

### Orchestrator (1)
- `ciel` — this skill, routes to the others

### Workflow (13) — replaces the old monolithic pipeline

| Skill | Replaces | Mandatory for |
|-------|----------|---------------|
| `depth-classifier` | Depth Gauge table | Ambiguous depth |
| `quoi-framer` | CRÉER step 1 QUOI | All |
| `avec-quoi-versioner` | CRÉER step 2 AVEC QUOI | Standard + Critical |
| `stride-analyzer` | CRÉER step 4 SÉCURITÉ (3 passes) | Critical |
| `pattern-fitness-check` | CRÉER step 5 CODEBASE fitness | All |
| `evaluer-sizer` | CRÉER step 6 ÉVALUER | Standard + Critical |
| `flux-narrator` | CRÉER step 7 FLUX | Standard + Critical |
| `faire-gatekeeper` | CRÉER step 8 FAIRE gates | All |
| `security-regression-check` | CRÉER step 8b | Critical |
| `relire-critic` | CRÉER step 9 RELIRE | All (inline for Trivial, agent for Standard+) |
| `prouver-verifier` | CRÉER step 10 PROUVER | All |
| `critiquer-auditor` | Full CRITIQUER 7-step flow | PR/audit reviews |
| `meta-critiquer` | META-CRITIQUER 30s reflection | All |

### Research (6) — isolated fork via researcher agent

| Skill | Purpose |
|-------|---------|
| `research-web-sources` | WebFetch official docs + WebSearch best practices |
| `research-github-issues` | `site:github.com/[lib]/issues` for symptoms |
| `research-forums` | StackOverflow, Reddit, HN fallback |
| `validate-source-credibility` | Score sources (official > maintainer > GH > SO > blog) |
| `synthesize-findings` | Merge outputs into FINDINGS / ANTI-PATTERNS / PHILOSOPHY / API SURFACE / UNCERTAINTIES |
| `fact-check-claims` | Grep source or fetch docs before asserting |

### Domain (8) — auto-activated by paths glob

| Skill | Paths trigger |
|-------|---------------|
| `frontend-mastery` | React/Vue/Svelte files |
| `backend-mastery` | Server framework files |
| `database-mastery` | `*.sql`, `migrations/**`, `prisma/**` |
| `security-hardening` | `auth/**`, `security/**`, Token/Password/Secret names |
| `api-architecture` | `routes/**`, `controllers/**`, `*.proto` |
| `observability` | logging/metrics/tracing code |
| `performance-engineering` | Performance-tagged tasks |
| `refactoring-patterns` | Refactor tasks or duplication ≥ 2 |

### Utility (5)

| Skill | Purpose |
|-------|---------|
| `commit-writer` | Conventional-format commit messages |
| `pr-body-generator` | PR body with Summary + Test plan + Closes #XXX |
| `issue-closer` | Close linked issues with evidence comment |
| `changelog-updater` | Append versioned entry with fix/revert ratio |
| `staging-verifier` | Correct Monitor/Bash run_in_background usage for staging |

### Meta (4) — self-improvement

| Skill | Purpose |
|-------|---------|
| `ciel-improve` | Analyze sessions → propose skill rewrites (patch-set for approval) |
| `skill-creator` | Create new skill from conversation pattern (validated scaffold) |
| `skill-variant-evaluator` | AutoResearch: generate + eval + compare skill variants |
| `learnings-capture` | Mine conversation for corrections → append to learnings.md or overlay |

---

## Guards — 35 failure modes

| Failure mode | How it manifests | Guard |
|---|---|---|
| Skipping RECHERCHE | "I already know this" / zero research output | "I already know this" = the red flag. Min: 1 WebSearch + 1 finding |
| False confidence | "I'm sure this API exists" without evidence | Verify before asserting. No citation = don't know it |
| Imports missing | Runtime ImportError on first run | API surface: read signatures of every called file before writing |
| DB columns wrong | Query crashes with "column does not exist" in prod | Verify real schema (migration or `pg_attribute`) before any query |
| Test URL mismatch | Test passes locally, fails in CI — MSW intercepts wrong host | FLUX test: trace request host:port vs handler host:port |
| Mock lifecycle error | Mock returns undefined / stale data | FLUX test: when does mock execute — module load or function call? |
| Pattern copied blindly | Correct syntax, wrong semantics | Fitness check: same problem? same constraints? Any no → adapt |
| Prior AI pattern | Existing code contradicts official docs | Pattern contradicts docs → DO NOT FOLLOW. Docs > existing code |
| Degeneration of thought | Self-critique finds 0 issues — same blind spots reinforced | Dispatch critic agent (fresh context) |
| Context overflow (silent) | Agent report < 200 tokens on Standard task | Re-dispatch with narrower scope. Truncated report = incomplete FAIRE |
| No alternative | "Obviously the right approach" | Alternatives gate: name X over Y or back to ÉVALUER |
| Framework bypass | `window.location` in React, `for`+raw SQL, `catch→null`, `as X` cast | Idiomatic gate: justify every bypass signal |
| Scope drift | "Simple fix" grows to 7 files | Alignment checkpoint at 3+ files: re-read QUOI |
| Removing without understanding | Removed X → breaks UX nobody tested | Removal gate: Who uses it? What replaces it? What degrades? |
| Proposing without calculating | "Let's cache all 3826 manga" — fails arithmetic | ÉVALUER sizing: back-of-envelope BEFORE proposing |
| Debugging wrong layer | 3 CSS fixes when bug was `navigate()` silent fail | 3-layer triage: handler called? simplest action works? only then CSS |
| Coding without mental model | Code pattern-matches but breaks — data flow not understood | FLUX: narrate full data flow before writing |
| First draft = final draft | Code works but messy | RELIRE: hostile critic before PROUVER |
| Fixation after failure | Same fix attempted 3 times, same result | After 2 failures: STOP. List 3 completely different approaches |
| TDD inversion | Tests written after implementation — pass by definition | Write failing test FIRST (RED) |
| Coverage theater | 95% coverage, zero meaningful assertions | Does this test verify behavior, or just execute code? |
| Confirmation bias | Tests only prove it works, never that it fails | Constraint synthesis: write 3 constraints BEFORE checking logs |
| Over-engineering | Change solves the problem but adds unnecessary complexity | Counterfactual: "What if we do NOTHING?" |
| Process bloat | SKILL.md grows, steps take longer than the task | Anti-entropy: every addition must simplify OR catch a real failure |
| Stale overlay | Overlay says React 18, project is React 19 | Per-month: check overlay versions vs real installed |
| Security fix adds surface | Fix closes vuln A but opens new unguarded endpoint | `security-regression-check`: grep diff for new params, removed auth, new external calls |
| CI ignored | "Staging works" declared while CI is red | `prouver-verifier` CI gate: `gh run list` must be success |
| Draft PR left open | CI green but PR stays draft | `meta-critiquer`: CI green + draft → convert to ready |
| Issue comment missing | Fix deployed but no evidence on the issue | Issue comment gate: add staging PID + AVANT/APRÈS before creating PR |
| Version changelog missed | Using Ktor 3.x but researching Ktor 2.x docs | RECHERCHE: installed version changelog checked for breaking changes |
| File re-read | Same file read 3 times in a session | After first read: note pointer. Re-read only if editing |
| Dead-end loop | Same broken approach attempted in new session | Session progress file: write `.claude/session-progress.md` with failed approaches |
| Dead code accumulation | Unused imports pile up across sessions | `meta-critiquer` #8: run ruff/knip/Detekt before session end |
| sleep + tail anti-pattern | `sleep 2 && tail -5 logs/file.log` blocked by harness | Use Monitor for streaming, Bash run_in_background for one-shot waits |
| Context window pollution | Large agent reports pasted verbatim — context burns fast | Agent result size cap: max 150 lines. Narrow scope if > 300 lines |

---

## Research basis

- Audit of 675 commits (62.8% fix/revert with v1.x monolithic skill, 2026-04-04)
- Anthropic Skills-first paradigm — "Stop building agents, build Skills" (Barry Zhang / Mahesh Murag, AI Engineer Code Summit)
- [MAR — Multi-Agent Reflexion](https://arxiv.org/html/2512.20845) — degeneration of thought in single-agent critique
- [SICA — Self-Improving Coding Agent](https://arxiv.org/html/2504.15228v2) — 17→53% improvement via self-edit + metrics
- [Reflexion](https://arxiv.org/abs/2405.06682) — self-reflection improves problem-solving, p < 0.001
- CriticBench 2024 — self-critique is the hardest critique mode for LLMs
- [Process debt research](https://planally.com/why-process-debt-is-the-new-tech-debt/) — monolithic process = friction = skipping
- OpenHands / JetBrains 2025 — observation masking reduces context burn
- ACON 2025 — memory pointers reduce token usage 40-60% on file-heavy tasks
