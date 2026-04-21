---
description: Audit current session for Ciel paradigm violations. Produces copy-paste report for fixes. Hook-independent — works even if hooks broken. OpenCode-native.
---

# /ciel-audit — Session post-mortem (OpenCode)

*Generates a structured report of Ciel behavior violations observed in the current OpenCode session. The output is self-contained: copy into a fresh session with "Apply these Ciel fixes" and the new session applies patches without seeing original transcript.*

Usage: `/ciel-audit`

Runs inline. Does not dispatch agents. Does not depend on hooks being active.

---

## Instructions to the model

You are auditing the **current OpenCode session**. The user will copy your output into a NEW session. The report must be self-contained: reference Ciel files with absolute paths, include line numbers.

Jump directly to the report. No preamble. No meta-commentary.

### What to audit (OpenCode-specific)

Scan the session's tool-use history. For each task, check:

#### 1. Dispatch discipline (critical)

- Did the assistant dispatch `@ciel-researcher` / `@ciel-explorer` / `@ciel-critic` via `Task()` within **first 3 tool calls** for Standard/Critical tasks?
- If NO: count inline `Bash` / `Read` / `Grep` / `WebSearch` / `WebFetch` calls before any dispatch.
- Exception: Trivial tasks (rename, typo, docs) allowed inline.
- **OpenCode context:** Primary agents are `ciel-plan` and `ciel-build`. Check if user switched via Tab, or if subagents were @mentioned.

#### 2. Plugin hook activity (critical)

Search session for plugin-injected strings:

- `"[CIEL] Depth:"` — from `experimental.chat.messages.transform`
- `"[CIEL] "` or `"[CIEL CRITIQUE]"` — from `tool.execute.after` on Write/Edit
- `"[CIEL RELIRE REQUIRED]"` — from `experimental.chat.system.transform`
- `"[CIEL] Session started"` — from `session.created` event

If **none** appear despite Write/Edit calls → **plugin inactive**, severity critical.

Most likely root cause: Plugin not loaded, or `opencode.json` missing `"plugin": ["./.opencode/plugins/ciel.ts"]`.

#### 3. Primary agent usage

- Did user switch between `ciel-plan` and `ciel-build` via Tab for appropriate tasks?
- If task was analysis/planning → should use `ciel-plan`
- If task was implementation → should use `ciel-build`
- If wrong agent used → flag as medium severity

#### 4. Subagent dispatch

For Standard/Critical tasks, verify:

- `@ciel-researcher` dispatched for external lib/API research
- `@ciel-explorer` dispatched for CODEBASE + FLUX steps
- `@ciel-critic MODE=RELIRE` dispatched after 5+ files modified
- `@ciel-critic MODE=CRITIQUER` for Critical tasks before merge

Missing dispatch → flag with severity based on task depth.

#### 5. Agent report quality

- Any `Task(subagent_type="ciel-*")` with output < 200 tokens? → truncation signal, flag with subagent_type.

#### 6. Intent routing

Scan user prompts for intent signals:

| Intent keywords | Expected skill/agent |
|----------------|---------------------|
| "debug", "why failed", "RCA" | `@ciel-critic MODE=RCA` + `debug-reasoning-rca` |
| "use library X", "API" | `@ciel-researcher` + `doc-validator-official` |
| "review UI", "visual" | `@ciel-critic` + `playwright-visual-critic` (if MCP configured) |
| "accessibility", "a11y" | `@ciel-explorer` + `accessibility-wcag-auditor` |
| "CI", "workflow", ".github" | `@ciel-explorer` + `cicd-security-hardener` |

---

### Report format

Begin with `# Ciel OpenCode Audit Report`. End with `**End of audit report.**`

```markdown
# Ciel OpenCode Audit Report

**Date**: <today's date>
**Session summary**: <N> tasks, <N> tool calls, <N> Task() dispatches, <N> inline calls in main session.

**Verdict**: <PASS | VIOLATIONS FOUND | PLUGIN INACTIVE | VIOLATIONS + PLUGIN INACTIVE>

---

## Violations detected

### 1. <Violation name> — severity: <critical | high | medium | low>

**Evidence from session**
- User prompt (turn N): `<exact prompt, truncated to 200 chars>`
- Assistant's first 3 tool calls:
  1. `<tool_name>(<brief args>)`
  2. `<tool_name>(<brief args>)`
  3. `<tool_name>(<brief args>)`
- Expected (per `.opencode/agents/ciel-plan.md:<line>`): `@ciel-researcher` or `@ciel-explorer` dispatch
- Observed: inline `Read`/`Grep` — no dispatch

**Root cause hypothesis**
<one sentence: buried rule, missing gate, plugin not loaded, etc.>

**Incriminated Ciel files**
- `.opencode/agents/ciel-plan.md:<line>` — <reason>
- `.opencode/plugins/ciel.ts:<line>` — <reason>
- `opencode.json:<line>` — <reason>

**Proposed fix**
- `<file>:<line>` — <concrete edit>
- `<file>:<line>` — <concrete edit>

### 2. <next violation>
...

---

## Summary of fixes to apply

Apply in order. Work at `/Users/neikyun/Documents/Projet/Ciel/`.

1. **<Fix name>** — `.opencode/<path>:<line>` — <description>
2. **<Fix name>** — `.opencode/<path>:<line>` — <description>

After each fix: re-run scenario in fresh session to verify.

---

**End of audit report.**
```

### If PASS

```markdown
# Ciel OpenCode Audit Report

**Verdict**: PASS

Session summary: <N> tasks, <N> tool calls, <N> Task() dispatches. All intents routed correctly. Plugin hooks active. No skill overlap.

**End of audit report.**
```

### Tone and length

- **Actionable, not narrative** — file paths, line numbers, snippets.
- Target: 400–800 lines for 2–3 violations. Shorter if PASS.
- No preamble. No emoji. No closing after `**End of audit report.**`

### What NOT to do

- Do NOT apply fixes in current session — only produce report.
- Do NOT invoke other Ciel skills — self-contained.
- Do NOT dispatch `Task()` agents — audit uses conversation memory only.
- Do NOT ask clarifying questions — produce report with available info.
