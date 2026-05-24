---
description: Audits the current session for Ciel v7 paradigm violations — dispatch discipline, hook activity, skill coverage, agent quality, memory health. Produces a structured report with Ciel Health Score (0-100). Creates GitHub Issue if score < 90. Hook-independent — works even when Ciel hooks are broken.
---

# /ciel-audit — Session Post-Mortem

*Generates a structured report of Ciel behavior violations observed in the current session with a Ciel Health Score (0-100). If score < 90, creates a GitHub Issue on KaosKyun/Ciel.*

Usage: `/ciel-audit`

Runs inline. No agent dispatch. Works without hooks.

## Audit Dimensions (10)

Score starts at 100. Subtract penalties for each violation found.

### D1: Dispatch discipline (up to -25)
Did the assistant dispatch `ciel-researcher` + `ciel-explorer` in parallel within the first 3 tool calls after the user prompt on Standard+ tasks?
- Missing both on Standard/Critical: **-25**
- Delayed dispatch (>1 inline tool before dispatch): **-15**
- Exception: Trivial tasks (rename, typo) allowed inline.

### D2: Hook activity (up to -25)
Search session transcript for Ciel hook injections:
- `"CIEL depth hint:"` (UserPromptSubmit)
- `"CIEL"` prefix on pre-write warnings
- SessionStart banner
- None found despite writes/edits: **-25** (hooks broken)
- Partial (some firing): **-10**

### D3: Skill coverage vs depth (up to -15)
- Standard task: missing researcher+explorer dispatch: **-15** each
- Critical task: missing stride-analyzer: **-15**
- Depth ambiguous + depth-classifier not invoked: **-5**

### D4: Skill overlap / redundancy (up to -10)
- Both relire-critic AND critiquer-auditor on same diff: **-10**
- meta-critiquer did not fire at end-of-task: **-5**

### D5: Agent report quality (up to -10)
- Any agent return under 200 tokens: **-5** per occurrence (max -10)

### D6: Intent routing (up to -10)
Cross-reference user prompt intent signals with skills invoked. Each miss: **-5** (max -10).

### D7: Version staleness (up to -10)
Check npm for newer `@neikyun/ciel` version. Remote > local: **-10**.

### D8: Platform health (up to -5)
Verify Claude Code (3+ agents, session-start.sh, settings.json) and OpenCode (plugin, 3+ agents, 5+ commands). Missing platform: **-3** to **-5**.

### D9: Memory health (up to -15)
- `.ciel/memory/index.json` missing: **-10**
- Episodes empty: **-5**
- Auto-memory contamination (MEMORY.md newer than Ciel episodes): **-5**

### D10: Memory insight quality (up to -10)
Run `python3 .claude/hooks/memory-engine.py analyze`. Check: promotion candidates, dead anchors, recursion drift, tag explosion.

## Scoring

**Ciel Health Score** = 100 - sum(penalties)

| Score | Status | Issue created? |
|-------|--------|----------------|
| 90-100 | Excellent | No |
| 0-89 | Needs improvement | Yes |

## Report Format

Output MUST start with `# Ciel Session Audit Report` and end with `**End of audit report.**`.

For violations: provide evidence (turn number, tool calls), root cause hypothesis (file:line), and proposed fix (concrete edit). No preamble, no meta-commentary, no emoji.

## GitHub Issue (score < 90 only)

1. Check for duplicate: `gh issue list --repo KaosKyun/Ciel --label audit --state open`
2. Create with title: `[CIEL-AUDIT] YYYY-MM-DD - VIOLATIONS FOUND (Score: N/100)`
3. Labels: `audit`, `ciel`
4. Body: session timeline + full audit report
5. Handle gracefully if `gh` unavailable — print report to stdout

## Constraints

- Do NOT fix violations in-session. Report only.
- Do NOT dispatch agents. Inline only.
- Do NOT create issues for score >= 90.
- Do NOT create duplicate issues.
- Target length: 200-400 lines for violations, 50 for PASS.
