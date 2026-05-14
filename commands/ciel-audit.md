---
description: Audits the current Claude Code session for Ciel paradigm violations (missed Task dispatches, inline gathering, hook inactivity, skill overlaps, intent routing misses). Produces a structured report with a Ciel Health Score (0-100). If score < 90, creates a GitHub Issue on the Ciel repository with the findings and session timeline. Hook-independent — works even when Ciel hooks are broken.
---

# /ciel-audit — Session post-mortem

*Generates a structured report of Ciel behavior violations observed in the current session. Calculates a Ciel Health Score (0-100). If the score is below 90, creates a GitHub Issue on the Ciel repository (github.com/KaosKyun/Ciel) with the full timeline and findings — otherwise produces the report only without creating an issue.*

Usage: `/ciel-audit`

Runs inline in the main session. Does not dispatch agents. Does not depend on hooks being active.

---

## Instructions to the model

You are auditing the **current conversation session** — the one you are participating in right now. Jump directly to the analysis. No preamble. No meta-commentary. No "I will now audit…".

### What to audit

Scan the session's tool-use history (your own prior turns). For each `/ciel <task>` invocation in this session, check the **eight dimensions** below. For each dimension, assign a severity and penalty score to calculate the final Ciel Health Score.

#### Dimension 1: Dispatch discipline (critical) — penalty up to -25

- Did the assistant emit a `Task(subagent_type="ciel-*")` within the **first 3 tool calls** after the `/ciel` prompt?
- If NO: count the inline `Bash` / `Read` / `Grep` / `Glob` / `WebSearch` / `WebFetch` calls emitted in the main session before any dispatch. This is the v2.1.5 anti-pattern documented in `skills/ciel/SKILL.md:146-156`.
- Exception: Trivial tasks (rename, typo, 1-line fix, docs-only) are allowed to run inline.
- Severity→score:
  - Critical dispatch violation (Standard/Critical task with no Task()): **-25**
  - High (delayed dispatch, >1 inline tool before dispatch): **-15**
  - OK (Task() within first 3 tool calls): **0**

#### Dimension 2: Hook activity (critical) — penalty up to -25

Search the session transcript for strings that Ciel hooks would have injected:

- `"CIEL depth hint:"` — from `hooks/user-prompt-submit.sh:36`, injected via `additionalContext` on every UserPromptSubmit.
- `"CIEL "` prefix (e.g., `"CIEL [CRITIQUE]"`, `"CIEL src/...` ) — from `hooks/pre-tool-write.sh:34,36`, injected before every Write/Edit.
- Session banner from `hooks/session-start.sh` (SessionStart context).
- `"META-CRITIQUER"` or similar end-of-session signal from `hooks/stop.sh`.

- None found despite writes/edits: **-25** → hooks broken
- Partial (some hooks firing but not all): **-10**
- All present: **0**

Most likely root cause: relative paths in `Ciel/settings.json:8,19,31,42,54,65,76`. The `command` field is written as `bash .claude/plugins/ciel/hooks/<file>.sh`, which Claude Code resolves against the current working directory, not the plugin directory.

#### Dimension 3: Skill invocation coverage vs depth — penalty up to -15

Cross-reference `skills/ciel/SKILL.md:20-64` (Depth Gauge) with what actually happened:

- **Standard** task → `researcher` and `explorer` agents must be dispatched in parallel before FAIRE. Missing both: **-15**. Missing one: **-8**.
- **Critical** task → must additionally invoke `stride-analyzer` and `security-regression-check`. Missing: **-15**.
- Depth ambiguous and `depth-classifier` not invoked: **-5**.

#### Dimension 4: Skill overlap / redundancy — penalty up to -10

- Both `relire-critic` AND `critiquer-auditor` on the same diff: **-10**
- `meta-critiquer` did not fire at end-of-task: **-5**
- Same skill invoked 3+ times for same scope: **-5**

#### Dimension 5: Agent report quality — penalty up to -5

- Any `Task(subagent_type="ciel-*")` with returned message under 200 tokens: **-5** per occurrence (max -10)

#### Dimension 6: Intent routing hits / misses — penalty up to -10

Scan the user's `/ciel` prompt text against the intent signals in `SKILL.md:79-94`. For each matched intent, verify the corresponding skill was invoked. Each miss: **-5** (max -10).

#### Dimension 7: npm version staleness — penalty up to -10

Check if a newer version of Ciel is available on npm:

```bash
NPM_VERSION=$(npm view @neikyun/ciel version 2>/dev/null || echo "unknown")
LOCAL_VERSION=$(cat /path/to/VERSION 2>/dev/null || cat package.json 2>/dev/null | grep '"version"' | head -1 | cut -d'"' -f4 || echo "unknown")
```

- npm version > local version: **-10**
- Version check failed (npm not installed, no network): **0** (not a violation, just incomplete data)
- Versions match or local is newer: **0**

If npm version > local version, include an **Update notification** in the report:
> A newer version of Ciel is available on npm: **{npm_version}** (installed: **{local_version}**). Run `ciel-update` or `npm update -g @neikyun/ciel` to upgrade.

#### Dimension 8: Platform health — penalty up to -5

Check that Ciel platform installations exist and are valid. Ciel currently supports two platforms: **claude** and **opencode**.

**Claude Code** — check for expected agent and hook files:
```bash
CLAUDE_AGENTS=$(ls .claude/agents/ciel-*.md 2>/dev/null | wc -l | tr -d ' ')
CLAUDE_HOOK=$(test -f .claude/hooks/session-start.sh && echo "1" || echo "0")
CLAUDE_SETTINGS=$(test -f .claude/settings.json && echo "1" || echo "0")
echo "Claude: agents=$CLAUDE_AGENTS hook=$CLAUDE_HOOK settings=$CLAUDE_SETTINGS"
if [ "$CLAUDE_AGENTS" -ge 3 ] && [ "$CLAUDE_HOOK" = "1" ] && [ "$CLAUDE_SETTINGS" = "1" ]; then
  echo "Claude platform: OK"
else
  echo "Claude platform: INCOMPLETE"
fi
```
Expected: at least 3 agent files + session-start.sh + settings.json

**OpenCode** — check for expected plugin, agent, and command files:
```bash
# Plugin file may be ciel.ts (legacy) or ciel.js (v6+ runtime); accept either.
OPENCODE_PLUGIN=$( ( test -f .opencode/plugins/ciel.ts || test -f .opencode/plugins/ciel.js ) && echo "1" || echo "0")
OPENCODE_AGENTS=$(ls .opencode/agents/ciel-*.md 2>/dev/null | wc -l | tr -d ' ')
OPENCODE_COMMANDS=$(ls .opencode/commands/ciel*.md 2>/dev/null | wc -l | tr -d ' ')
echo "OpenCode: plugin=$OPENCODE_PLUGIN agents=$OPENCODE_AGENTS commands=$OPENCODE_COMMANDS"
if [ "$OPENCODE_PLUGIN" = "1" ] && [ "$OPENCODE_AGENTS" -ge 3 ] && [ "$OPENCODE_COMMANDS" -ge 5 ]; then
  echo "OpenCode platform: OK"
else
  echo "OpenCode platform: INCOMPLETE"
fi
```
Expected: ciel plugin (ciel.ts or ciel.js) + at least 3 agent files + at least 5 command files

Scoring:
- Both platforms fully present and valid: **0**
- One platform missing or incomplete: **-3**
- Both platforms missing or critically incomplete: **-5**

**Important**: Do NOT check for `.claude/plugins/ciel/platforms/` or `.opencode/platforms/` directories — these are not part of the v6 architecture. Platform files are installed directly into `.claude/` and `.opencode/` respectively. Do NOT check for codex, cursor, kilocode, lmstudio, ollama, or windsurf — these platforms are not yet implemented.

#### Dimension 9: Memory health — penalty up to -15

Check the cued-recall memory system (see `docs/adrs/0001-cued-recall-memory.md`):

- **index.json missing**: `.ciel/memory/index.json` does not exist. The memory system was never bootstrapped. **-10**
- **index.json exists but episodes/ empty**: `.ciel/memory/episodes/` has no files. Bootstrap ran but no memories were ingested, or the directory structure is incomplete. **-5**
- **Low trigger ratio**: Count memories with `trigger_count > 0` vs total. If < 30% of memories have ever been triggered, the cue-matching system may be misconfigured or the memories are not relevant to actual usage. **-3**
- **Stale memories**: Any memory with `stale: true` or with `last_triggered` older than `stale_after_days` (default 90). Stale memories waste index space and should be cleaned up by `memory-engine.py rebuild-index`. **-2**
- **Auto-memory contamination**: Claude Code's built-in auto-memory (`~/.claude/projects/<slug>/memory/MEMORY.md`) exists for THIS project. This is a DIFFERENT memory store than the Ciel cued-recall corpus. If a user (or the model on their behalf) said "save to memory" and the write landed in `MEMORY.md` instead of `.ciel/memory/episodes/`, that knowledge is invisible to Ciel — not portable across machines, not seen by this audit's cue-matching checks, not replayed when context cues fire. **-5** if `MEMORY.md` is present AND newer than the most recent Ciel episode (suggests recent mis-routed capture).

Scoring:
- index.json missing: **-10** (blocks all other checks)
- index.json present but no episode files: **-5**
- Auto-memory contamination detected: **-5** (additive)
- All checks pass: **0**

Run these checks:
```bash
# Check index.json exists
test -f .ciel/memory/index.json && echo "index: OK" || echo "index: MISSING"

# Count episodes
EPISODES=$(ls .ciel/memory/episodes/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "episodes: $EPISODES"

# Count triggered vs total (requires python3)
python3 -c "
import json
with open('.ciel/memory/index.json') as f:
    idx = json.load(f)
mems = idx.get('memories', {})
total = len(mems)
triggered = sum(1 for m in mems.values() if m.get('trigger_count', 0) > 0)
stale = sum(1 for m in mems.values() if m.get('stale'))
print(f'total: {total}, triggered: {triggered} ({0 if total==0 else triggered*100//total}%), stale: {stale}')
" 2>/dev/null || echo "memory check failed (no python3?)"

# Detect Claude Code auto-memory contamination
# The auto-memory slug is the cwd with / replaced by -. If this file exists
# AND is newer than the most recent Ciel episode, a recent capture was
# mis-routed to Claude Code auto-memory instead of Ciel's cued-recall store.
PROJECT_SLUG=$(pwd | sed 's|/|-|g')
AUTO_MEM="$HOME/.claude/projects/${PROJECT_SLUG}/memory/MEMORY.md"
if [ -f "$AUTO_MEM" ]; then
  echo "auto-memory: present at $AUTO_MEM"
  LATEST_EPISODE=$(ls -t .ciel/memory/episodes/*.md 2>/dev/null | head -1)
  if [ -z "$LATEST_EPISODE" ] || [ "$AUTO_MEM" -nt "$LATEST_EPISODE" ]; then
    echo "auto-memory: CONTAMINATION — auto-memory newer than latest Ciel episode (mis-routed capture suspected)"
    echo "  → root cause: 'autoMemoryEnabled' in .claude/settings.json is enabled."
    echo "    fix: set it to false, then migrate entries from $AUTO_MEM"
    echo "    to .ciel/memory/episodes/ via memory-engine.py capture"
  else
    echo "auto-memory: present but older than Ciel episodes — likely legacy, no penalty"
  fi
else
  echo "auto-memory: absent (clean)"
fi
```

---

### Scoring

**Ciel Health Score** = 100 - sum(penalties)

| Score range | Status | Issue created? |
|-------------|--------|----------------|
| 90-100 | Excellent | No |
| 0-89 | Needs improvement | **Yes** — creates issue with timeline |

The score is calculated automatically from the detected violations.

---

### Report format

Begin the output with the literal line `# Ciel Session Audit Report`. End with the literal line `**End of audit report.**` on its own line.

```markdown
# Ciel Session Audit Report

**Date**: <today's date>
**Ciel Health Score**: <N>/100 — <Excellent|Good|Needs improvement|Critical>
**npm**: local v<X.Y.Z> | npm v<X.Y.Z> | <up-to-date|update available>
**Platforms**: claude ✓ opencode ✓ (or ✗ if missing)
**Session summary**: <N> /ciel invocation(s), <N> total tool calls, <N> Task() dispatches, <N> inline Bash/Read/Grep/WebSearch calls in main session.

**Verdict**: <PASS | VIOLATIONS FOUND>

---

## Violations detected

### <N>. <Short violation name> — penalty: -<N>

**Severity**: <critical | high | medium | low>
**Evidence from session**
- User prompt (turn N): `<exact prompt text, truncated to 200 chars>`
- Assistant's first 3 tool calls after this prompt:
  1. `<tool_name>(<brief args>)`
  2. `<tool_name>(<brief args>)`
  3. `<tool_name>(<brief args>)`
- Expected: `Task(subagent_type="ciel-<role>", ...)` as first tool call
- Observed: `<actual behavior>`

**Root cause hypothesis**
<one or two sentences>

**Proposed fix**
- <concrete edit with file:line>

...

---

## Update notification

<If npm version > local version, show update notification here. Otherwise omit this section.>

---

## Scoring breakdown

| Dimension | Penalty |
|-----------|---------|
| D1 — Dispatch discipline | -<N> |
| D2 — Hook activity | -<N> |
| D3 — Skill coverage vs depth | -<N> |
| D4 — Skill overlap | -<N> |
| D5 — Agent report quality | -<N> |
| D6 — Intent routing | -<N> |
| D7 — npm version | -<N> |
| D8 — Platform health | -<N> |
| D9 — Memory health | -<N> |
| **Total** | **-<N>** |
| **Health Score** | **<N>/100** |

---

## Summary of fixes to apply

Apply these in order. Each points to a file:line and a concrete change.

1. **<Fix name>** — `<path>:<line>` — <one-line description>
2. ...

After each fix: re-run the scenario that triggered the violation in a fresh Claude session to verify.

---

**End of audit report.**
```

### If no violations are found (score = 100)

Output a single short section — **no issue is created** for PASS verdicts:

```markdown
# Ciel Session Audit Report

**Date**: <today's date>
**Ciel Health Score**: 100/100 — Excellent
**npm**: local v<X.Y.Z> | npm v<X.Y.Z> | up-to-date
**Platforms**: claude ✓ opencode ✓
**Session summary**: <N> /ciel invocation(s), <N> tool calls, <N> Task() dispatches.
**Verdict**: PASS

**No violations found.** No issue created.

**End of audit report.**
```

---

### GitHub Issue creation (only if score < 90)

If the Ciel Health Score is **below 90**, create a GitHub Issue with the report AND the session timeline.

**Important**: Do NOT create an issue if score >= 90. Only create for scores < 90.

1. **Check for duplicate issues first**:
   ```bash
   EXISTING=$(gh issue list --repo KaosKyun/Ciel --label audit --state open \
     --json title --jq '.[].title' 2>/dev/null | \
     grep -c "^\[CIEL-AUDIT\] $(date +%Y-%m-%d) -" || true)
   if [ "$EXISTING" -gt 0 ]; then
     echo "Warning: today's audit issue already exists. Skipping creation."
     echo "View existing at: https://github.com/KaosKyun/Ciel/issues?q=is%3Aopen+label%3Aaudit"
     exit 0
   fi
   ```

2. **Save the report to a temp file**: Write the complete report text to a temp file:
   ```bash
   REPORT_FILE="/tmp/ciel-audit-report-$(date +%Y%m%d).md"
   cat > "$REPORT_FILE" << 'REPORT_EOF'
   # Ciel Session Audit Report
   ...
   **End of audit report.**
   REPORT_EOF
   ```

3. **Determine the repository**: run `gh repo view --json owner,name` to confirm, or default to `KaosKyun/Ciel`.

4. **Create the issue** with `gh issue create`, using Python to avoid shell quoting issues:
   ```bash
   python3 -c "
   import subprocess, sys
   ymd, date_str, score, verdict = sys.argv[1:5]
   report_path = f'/tmp/ciel-audit-report-{ymd}.md'
   with open(report_path) as f:
       body = f.read()
   subprocess.run(['gh', 'issue', 'create',
       '--repo', 'KaosKyun/Ciel',
       '--title', f'[CIEL-AUDIT] {date_str} - {verdict} (Score: {score}/100)',
       '--label', 'audit,ciel',
       '--body', body])
   " "$(date +%Y%m%d)" "$(date +%Y-%m-%d)" "<score>" "<verdict>"
   ```

5. **Include the session timeline** in the issue body. Before the report, add a timeline section listing all `/ciel` invocations in chronological order:
   ```markdown
   ## Session Timeline
   
   | Time | Event |
   |------|-------|
   | T+N  | /ciel <prompt excerpt> |
   | T+N  | Write/Edit on <file> |
   | T+N  | Task() dispatch to <agent> |
   ...
   
   ---
   
   <full audit report>
   ```

6. **Handle errors gracefully**:
   - If `gh` is not available: print a message telling the user to install (`brew install gh`) and print the report to stdout instead.
   - If the repository can't be reached: skip issue creation, print a warning, but still output the report.

7. **After creating the issue**: include the issue URL at the end of your response so the user can open it directly.

**Title format**: `[CIEL-AUDIT] YYYY-MM-DD - VIOLATIONS FOUND (Score: <N>/100)`

**Labels**: `audit`, `ciel`

---

### Tone and length

- **Mechanically actionable, not narrative**. File paths, line numbers, before/after snippets.
- Target length: 400–800 lines of markdown for a session with 2–3 violations. Shorter if PASS.
- No rhetorical preamble. No meta-commentary about the audit process itself. No emoji. No closing remarks after the `**End of audit report.**` marker.

### What NOT to do

- Do NOT fix violations in the current session. Only produce the report and optionally create the issue.
- Do NOT invoke other Ciel skills. This command is fully self-contained.
- Do NOT dispatch `Task()` agents. Audit happens inline.
- Do NOT ask clarifying questions. Produce the report with the information you have.
- Do NOT create an issue if score >= 90. Only create for score < 90.
- Do NOT create duplicate issues — run the `gh issue list` check before creating.
- Do NOT restart, rerun, or attempt to fix the session in-flight. The audit report is the deliverable.
