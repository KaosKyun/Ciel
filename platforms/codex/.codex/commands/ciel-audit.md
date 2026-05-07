---
description: Audits the current Claude Code session for Ciel paradigm violations (missed Task dispatches, inline gathering, hook inactivity, skill overlaps, intent routing misses). Produces a structured report with a Ciel Health Score (0-100). If score < 75, creates a GitHub Issue on the Ciel repository with the findings and session timeline. Hook-independent — works even when Ciel hooks are broken.
---

# /ciel-audit — Session post-mortem

*Generates a structured report of Ciel behavior violations observed in the current session. Calculates a Ciel Health Score (0-100). If the score is below 75, creates a GitHub Issue on the Ciel repository (github.com/KaosKyun/Ciel) with the full timeline and findings — otherwise produces the report only without creating an issue.*

Usage: `/ciel-audit`

Runs inline in the main session. Does not dispatch agents. Does not depend on hooks being active.

---

## Instructions to the model

You are auditing the **current conversation session** — the one you are participating in right now. Jump directly to the analysis. No preamble. No meta-commentary. No "I will now audit…".

### What to audit

Scan the session's tool-use history (your own prior turns). For each `/ciel <task>` invocation in this session, check the **eight dimensions** below. For each dimension, assign a severity and penalty score to calculate the final Ciel Health Score.

#### Dimension 1: Dispatch discipline (critical) — penalty up to -25

- Did the assistant emit a `Task(subagent_type="ciel-*")` within the **first 3 tool calls** after the `/ciel` prompt?
- If NO: count the inline `Bash` / `Read` / `Grep` / `Glob` / `WebSearch` / `WebFetch` calls emitted in the main session before any dispatch.
- Exception: Trivial tasks (rename, typo, 1-line fix, docs-only) are allowed to run inline.
- Severity→score:
  - Critical dispatch violation: **-25**
  - High (delayed dispatch): **-15**
  - OK: **0**

#### Dimension 2: Hook activity (critical) — penalty up to -25

Search for Ciel hook signatures in the transcript:
- `"CIEL depth hint:"` — from `UserPromptSubmit` hook
- `"CIEL "` prefix on Write/Edit — from `pre-tool-write.sh`
- Session banner from `session-start.sh`
- `"META-CRITIQUER"` from `stop.sh`

- None found: **-25**
- Partial: **-10**
- All present: **0**

#### Dimension 3: Skill invocation coverage vs depth — penalty up to -15

- **Standard** task, missing both researcher+explorer: **-15**. Missing one: **-8**.
- **Critical** task, missing stride+security: **-15**.
- Depth ambiguous, no `depth-classifier`: **-5**.

#### Dimension 4: Skill overlap / redundancy — penalty up to -10

- Both `relire-critic` AND `critiquer-auditor`: **-10**
- `meta-critiquer` absent: **-5**
- Same skill 3+ times: **-5**

#### Dimension 5: Agent report quality — penalty up to -5

- Agent report under 200 tokens: **-5** per occurrence (max -10)

#### Dimension 6: Intent routing misses — penalty up to -10

Each intent→skill mapping miss: **-5** (max -10).

#### Dimension 7: npm version staleness — penalty up to -10

Check `npm view @neikyun/ciel version` vs local version. If npm > local: **-10**.

#### Dimension 8: Platform health — penalty up to -5

Expected: codex, cursor, kilocode, lmstudio, ollama, opencode, windsurf. Missing 1-2: **-3**. Missing 3+: **-5**.

---

### Scoring

**Ciel Health Score** = 100 - sum(penalties)

| Score | Issue? |
|-------|--------|
| 90-100 Excellent | No |
| 75-89 Good | No |
| 50-74 Needs improvement | **Yes** |
| 0-49 Critical | **Yes** |

---

### Report format

```markdown
# Ciel Session Audit Report

**Date**: <today>
**Ciel Health Score**: <N>/100 — <status>
**npm**: local v<X> | npm v<X> | <status>
**Platforms**: codex ✓ cursor ✓ kilo ✓ ...
**Session summary**: <N> invocations, <N> tool calls, <N> dispatches.
**Verdict**: <PASS | VIOLATIONS FOUND>

## Violations detected
...

## Scoring breakdown
| Dimension | Penalty |
...
**Health Score**: <N>/100

## Summary of fixes
1. ...
**End of audit report.**
```

### PASS verdict (no issue created)
```markdown
# Ciel Session Audit Report
**Ciel Health Score**: 100/100 — Excellent
**Verdict**: PASS
**No violations found.** No issue created.
**End of audit report.**
```

---

### GitHub Issue creation (only if score < 75)

1. Check duplicates: `gh issue list --repo KaosKyun/Ciel --label audit --state open --json title --jq '.[].title' | grep -c "^\[CIEL-AUDIT\]"`
2. Save report to `/tmp/ciel-audit-report-$(date +%Y%m%d).md`
3. Create issue with Python (avoids shell quoting):
   ```bash
   python3 -c "
   import subprocess, sys
   ymd, date_str, score, verdict = sys.argv[1:5]
   with open(f'/tmp/ciel-audit-report-{ymd}.md') as f: body = f.read()
   subprocess.run(['gh', 'issue', 'create',
       '--repo', 'KaosKyun/Ciel',
       '--title', f'[CIEL-AUDIT] {date_str} - {verdict} (Score: {score}/100)',
       '--label', 'audit,ciel', '--body', body])
   " "$(date +%Y%m%d)" "$(date +%Y-%m-%d)" "<score>" "<verdict>"
   ```
4. Include session timeline in the issue body.
5. On error (gh missing, no network): skip issue, output report to stdout.

**Labels**: `audit`, `ciel`

---

### What NOT to do

- Do NOT fix violations. Only produce the report and optionally create the issue.
- Do NOT invoke other Ciel skills. Self-contained.
- Do NOT dispatch `Task()` agents. Audit happens inline.
- Do NOT create issue if score >= 75.
- Do NOT create duplicate issues — run the check first.
