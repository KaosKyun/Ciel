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

## Guards — 39 failure modes

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
| Dispatch gate bypass | >5 inline Bash/Read/Grep calls without any `Task()` on a Standard+ task | ABORT inline work, emit `Task(subagent_type="ciel-*")` immediately with `[ASSUMED]` markers for any inferred inputs |
| Dispatch gate deadlock on mechanical phase | After implementation is complete, the counter is still at the investigation-phase value. The gate fires and blocks Read/Bash — including `rm /tmp/ciel-counter-*` (the documented reset path). Mechanical work (changelog, VERSION, commit, PR) is stalled. | When entering a purely mechanical phase (no more investigation needed), dispatch a no-op `Task("GATE_RESET")` first to reset the counter, then proceed with changelog/commit/push. Do NOT attempt `rm` the counter file as a shortcut — it is blocked by the same gate. |
| Hook name drift | Consumer `settings.json` references a hook filename that does not exist in `hooks/` (silent "No such file or directory" on every tool call) | On every hook rename in the repo: grep all published `settings.json` templates and downstream consumer docs for the old name. Version-bump the plugin. |
| Self-authored rule drift | A rule written in this session (e.g., a new SKILL.md paragraph, a new reference guard) is not reliably followed in subsequent turns; short-term memory decays across tool outputs and compacts. Observed in the v2.4.4→v2.4.7 audit where the `[CIEL N/5]` counter rule was applied exactly once before the agent forgot it. | Mechanical enforcement — hooks, gates, external state files — required for any rule that must hold across >5 turns. Pure SKILL.md text is advisory; without a hook-side counter or settings.json gate, the rule decays within 1-2 turns of its author writing it. v2.5.0 `pre-tool-count.sh` / `post-tool-count.sh` is the canonical example. |
| Release discipline drift | `feat:`/`fix:` commits accumulate on default branch but VERSION / CHANGELOG / git tag / `gh release` never catch up. Pipeline step 16-17 (`changelog-updater` + `release-publisher`) are opt-in and only triggered on a version-bump PR that no one creates. Observed v2.0 → v2.5.1: 20+ features shipped, zero tags — fixed in the v2.6.0 rattrapage. | Stop-hook `release-gate` (v2.7.0 `hooks/stop.sh`) — when on the default branch AND 3+ conventional `feat:`/`fix:`/`feat!:`/`fix!:` commits exist past the last `git describe --tags --abbrev=0`, prepend a reminder to the meta-critiquer block. Snooze for 60 min: `touch .ciel-release-snooze`. Claude Code only in v2.7.0; OpenCode parity pending `session.idle` `.d.ts` verification. |
| `install.sh --update` TTY failure | `--update` uninstalls (wipes manifest) then spawns `curl \| bash` re-install without forwarding `-y`; the interactive `read -rp` prompt fails without a TTY → exit 1, manifest gone, install half-complete. | Never invoke `bash scripts/install.sh --update` bare in non-interactive context. Use `echo "A" \| bash scripts/install.sh` for fresh install, or fix the installer to forward `--yes` to the spawned sub-shell. Track as open UX bug. |
| Cost-quality optimization without baseline | A plan reduces model tier (Sonnet→Haiku) or raises a safety-net threshold (RELIRE 3→5) on researcher, explorer, or critic without measuring (a) bugs caught by the component at the current threshold, (b) dispatch overhead (850K × N agents) in the total cost calculation, (c) qualitative output difference on real sessions. Observed in the v2.10.0 optimization plan: micro-agent architecture claimed "70% cost reduction" without counting 850K×3 overhead for complex tasks, and RELIRE threshold raised without incident log data. | Any cost optimization on a safety-net component requires: baseline bug-catch log, honest differential cost analysis including dispatch overhead, and live test on 5 real sessions before merging. |
| PostToolUse matcher missing `Agent` tool name | Counter resets never fire in Claude Code sessions (Claude Code uses `Agent` as tool name; OpenCode uses `Task`). Gate reaches 15 and locks permanently — including blocking the `rm /tmp/ciel-counter-*` Bash call documented as the reset path, causing a deadlock that can only be resolved by the user manually deleting the counter file. Observed v2.10.0. | PostToolUse matcher for `post-tool-count.sh` must include BOTH `Task\|Agent`. On every hook maintenance change, verify: `grep -E "Task\|Agent" settings.json`. The script itself already handles both names — the matcher is the only failure point. |

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
