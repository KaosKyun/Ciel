---
name: ciel-audit
description: Audits the current Claude Code session for Ciel paradigm violations (missed Task dispatches, inline gathering, hook inactivity, skill overlaps, intent routing misses). Produces a copy-paste markdown report the user pastes into a fresh session to apply fixes. Hook-independent — works even when Ciel hooks are broken.
---


# /ciel-audit — Session post-mortem

*Generates a structured report of Ciel behavior violations observed in the current session. The output is self-contained: the user copies it into a fresh Claude Code session with the prompt "Apply these Ciel fixes" and the new session applies the patches without seeing the original transcript.*

Usage: `/ciel-audit`

Runs inline in the main session. Does not dispatch agents. Does not depend on hooks being active.

---

## Instructions to the model

You are auditing the **current conversation session** — the one you are participating in right now. The user will copy your output into a NEW Claude Code session where they will say "Apply these Ciel fixes." The report must therefore be self-contained: reference Ciel files with absolute paths, include line numbers, and give enough detail that a fresh session can execute the fixes without any transcript context.

Jump directly to the report. No preamble. No meta-commentary. No "I will now audit…".

### What to audit

Scan the session's tool-use history (your own prior turns). For each `/ciel <task>` invocation in this session, check the six dimensions below.

#### 1. Dispatch discipline (critical)

- Did the assistant emit a `Task(subagent_type="ciel-*")` within the **first 3 tool calls** after the `/ciel` prompt?
- If NO: count the inline `Bash` / `Read` / `Grep` / `Glob` / `WebSearch` / `WebFetch` calls emitted in the main session before any dispatch. This is the v2.1.5 anti-pattern documented in `skills/ciel/SKILL.md:146-156`.
- Exception: Trivial tasks (rename, typo, 1-line fix, docs-only) are allowed to run inline.
- If the prompt implied Standard or Critical depth (new feature, multi-file change, auth/security, config system) and no `Task()` was emitted → **dispatch violation, severity critical**.

#### 2. Hook activity (critical — user suspects hooks are broken)

Search the session transcript for strings that Ciel hooks would have injected:

- `"CIEL depth hint:"` — from `hooks/user-prompt-submit.sh:36`, injected via `additionalContext` on every UserPromptSubmit.
- `"CIEL "` prefix (e.g., `"CIEL [CRITIQUE]"`, `"CIEL src/...` ) — from `hooks/pre-tool-write.sh:34,36`, injected before every Write/Edit.
- Session banner from `hooks/session-start.sh` (SessionStart context).
- `"META-CRITIQUER"` or similar end-of-session signal from `hooks/stop.sh`.

If **none** of these strings appear anywhere in the session despite multiple `/ciel` invocations or Write/Edit tool calls → conclude **hooks are inactive**, severity critical.

Most likely root cause: relative paths in `Ciel/settings.json:8,19,31,42,54,65,76`. The `command` field is written as `bash .claude/plugins/ciel/hooks/<file>.sh`, which Claude Code resolves against the current working directory, not the plugin directory. When `claude` is launched from any project folder (the common case), the path does not exist and the hook fails silently.

#### 3. Skill invocation coverage vs depth

Cross-reference `skills/ciel/SKILL.md:20-64` (Depth Gauge) with what actually happened:

- **Standard** task (new endpoint, hook, component, service) → `researcher` and `explorer` agents must be dispatched in parallel before FAIRE. If neither was dispatched → flag.
- **Critical** task (auth, DB schema, security, payment) → must additionally invoke `stride-analyzer` and `security-regression-check`. If missing → flag.
- If depth was ambiguous and `depth-classifier` was not invoked → flag as medium severity.

#### 4. Skill overlap / redundancy

- Did the assistant invoke BOTH `relire-critic` AND `critiquer-auditor` on the same diff? They should be mutually exclusive (relire = post-FAIRE quick pass; critiquer = standalone audit of existing code).
- Did `meta-critiquer` fire at end-of-task? If the task is ended and no meta-critiquer trace exists → flag as low severity.
- Any skill invoked 3+ times for the same scope → flag as a churn signal.

#### 5. Agent report quality

- Any `Task(subagent_type="ciel-*")` whose returned message is under 200 tokens? Per `SKILL.md:290`, this signals truncation — the agent probably failed or got no useful context. Flag with the subagent_type and the prompt used.

#### 6. Intent routing hits / misses

Scan the user's `/ciel` prompt text against the intent signals in `SKILL.md:79-94`. For each matched intent, verify the corresponding skill was invoked.

Examples of intent→skill mapping to verify:
- "debug", "why did X fail", "production bug", "incident", "RCA" → `debug-reasoning-rca`
- "use library X", "call API Z" → `doc-validator-official` BEFORE writing code
- "review this UI", "visual regression" → `playwright-visual-critic`
- "accessibility", "a11y", "WCAG" → `accessibility-wcag-auditor`
- Changes to `.github/workflows/` → `cicd-security-hardener`

**MCP config / MCP servers** is currently **not listed** in the routing table. If the user's prompt was about MCP config/servers and no skill routed correctly, the fix is to **add a new row** to `SKILL.md:79-94`:

```
| "mcp server", "mcp config", ".mcp.json", "claude mcp" | `debug-reasoning-rca` + config inspection | `@ciel-explorer` then `@ciel-critic` MODE=RCA |
```

---

### Report format — output exactly this structure

Begin the output with the literal line `# Ciel Session Audit Report`. End with the literal line `**End of audit report.**` on its own line. The user copies everything between those two markers.

```markdown
# Ciel Session Audit Report

**Date**: <today's date>
**Session summary**: <N> /ciel invocation(s), <N> total tool calls, <N> Task() dispatches, <N> inline Bash/Read/Grep/WebSearch calls in main session.

**Verdict**: <PASS | VIOLATIONS FOUND | HOOKS INACTIVE | VIOLATIONS FOUND + HOOKS INACTIVE>

---

## Violations detected

### 1. <Short violation name> — severity: <critical | high | medium | low>

**Evidence from session**
- User prompt (turn N): `<exact prompt text, truncated to 200 chars>`
- Assistant's first 3 tool calls after this prompt:
  1. `<tool_name>(<brief args>)`
  2. `<tool_name>(<brief args>)`
  3. `<tool_name>(<brief args>)`
- Expected (per `skills/ciel/SKILL.md:<line>`): `Task(subagent_type="ciel-<role>", ...)` as first tool call
- Observed: `Bash("claude mcp list")` inline — dispatch never happened

**Root cause hypothesis**
<one or two sentences pointing to the structural reason — buried rule, missing gate, broken hook, etc.>

**Incriminated Ciel files**
- `Ciel/skills/ciel/SKILL.md:<start-end>` — <reason>
- `Ciel/commands/ciel.md:<line>` — <reason>
- `Ciel/settings.json:<line>` — <reason>

**Proposed fix**
- <bullet 1: concrete edit with file:line>
- <bullet 2: concrete edit with file:line>
- <bullet 3 if needed>

### 2. <next violation>
…

---

## Summary of fixes to apply

Apply these in order. Each points to a file:line and a concrete change. Work at path `/Users/<user>/Documents/Projet/Ciel/Ciel/` (or wherever the Ciel repo is cloned).

1. **<Fix name>** — `Ciel/<path>:<line>` — <one-line description>
2. **<Fix name>** — `Ciel/<path>:<line>` — <one-line description>
3. …

After each fix: re-run the scenario that triggered the violation in a fresh Claude session to verify.

---

**End of audit report.**
```

### If no violations are found

Output a single short section:

```markdown
# Ciel Session Audit Report

**Verdict**: PASS

Session summary: <N> /ciel invocation(s), <N> tool calls, <N> Task() dispatches. All intents routed correctly. Hook signatures present. No skill overlap. No dispatch discipline issues.

**End of audit report.**
```

### Tone and length

- **Mechanically actionable, not narrative**. File paths, line numbers, before/after snippets.
- Target length: 400–800 lines of markdown for a session with 2–3 violations. Shorter if PASS. Longer OK if many violations found.
- No rhetorical preamble. No meta-commentary about the audit process itself. No emoji. No closing remarks after the `**End of audit report.**` marker.

### What NOT to do

- Do NOT apply fixes in the current session. Only produce the report.
- Do NOT invoke other Ciel skills. This command is fully self-contained.
- Do NOT dispatch `Task()` agents. Audit happens inline in the main session using only your conversation memory and `Read` on Ciel files if needed to cite exact line numbers.
- Do NOT ask clarifying questions. Produce the report with the information you have.
- Do NOT restart, rerun, or attempt to fix the session in-flight. The report is the deliverable.
