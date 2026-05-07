---
name: ciel-audit
description: Audits the current session for Ciel paradigm violations. Produces a structured report with a Ciel Health Score (0-100). If score < 75, creates a GitHub Issue on the Ciel repository with findings and timeline. Hook-independent.
---

# /ciel-audit — Session post-mortem

*Generates a structured report of Ciel behavior violations observed in the current session. Calculates a Ciel Health Score (0-100). If the score is below 75, creates a GitHub Issue on the Ciel repository (github.com/KaosKyun/Ciel) with the full timeline and findings.*

Usage: `/ciel-audit`

Runs inline. Does not dispatch agents. Does not depend on hooks being active.

---

## Instructions to the model

You are auditing the **current conversation session**. Jump directly to the analysis. No preamble.

### What to audit — 8 dimensions with penalties

Scan the session's tool-use history. For each `/ciel <task>`, check:

1. **Dispatch discipline** (-25 to 0) — Task() within first 3 tool calls?
2. **Hook activity** (-25 to 0) — CIEL depth hint, CIEL prefix, session banner, META-CRITIQUER present?
3. **Skill coverage vs depth** (-15 to 0) — researcher+explorer dispatched on Standard? stride+security on Critical?
4. **Skill overlap** (-10 to 0) — relire+critiquer dup? meta-critiquer fired at end?
5. **Agent report quality** (-5 to 0) — under 200 tokens?
6. **Intent routing** (-10 to 0) — matched intent → correct skill?
7. **npm version staleness** (-10 to 0) — `npm view @neikyun/ciel version` > local?
8. **Platform health** (-5 to 0) — all 7 platforms present? (codex, cursor, kilocode, lmstudio, ollama, opencode, windsurf)

### Scoring

**Ciel Health Score** = 100 - sum(penalties)

| Score | Issue? |
|-------|--------|
| 90-100 | No |
| 75-89 | No |
| 50-74 | **Yes** |
| 0-49 | **Yes** |

### Report format

Begin with `# Ciel Session Audit Report`. End with `**End of audit report.**`.

```markdown
# Ciel Session Audit Report
**Date**: <today>
**Ciel Health Score**: <N>/100 — <status>
**npm**: local v<X> | npm v<X> | <status>
**Platforms**: codex ✓ ...
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

PASS verdict → no issue created.

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

### What NOT to do

- Do NOT fix violations. Only produce the report.
- Do NOT create issue if score >= 75.
- Do NOT create duplicate issues.
