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
- If NO: count inline `Bash` / `Read` / `Grep` / `WebSearch` / `WebFetch` calls emitted in the main session before any dispatch.
- **Budget check**: Did the assistant emit **more than 5** inline Bash/Read/Grep/WebSearch/WebFetch calls before any `Task()` dispatch? If yes, flag as **critical** per `.opencode/agents/ciel.md` context-budget rules.
- Exception: Trivial tasks (rename, typo, docs) allowed inline.
- **OpenCode context:** Primary agent is `ciel`. Check if subagents were @mentioned.

#### 2. Plugin hook activity (critical)

Search session for plugin-injected strings:

- `"[CIEL] Depth:"` — from `experimental.chat.messages.transform`
- `"[CIEL] "` or `"[CIEL CRITIQUE]"` — from `tool.execute.after` on Write/Edit
- `"[CIEL RELIRE REQUIRED]"` — from `experimental.chat.system.transform`
- `"[CIEL] Session started"` — from `session.created` event

If **none** appear despite Write/Edit calls → **plugin inactive**, severity critical.

Most likely root cause: Plugin not loaded, or `opencode.json` missing `"plugin": ["./.opencode/plugins/ciel.ts"]`.

#### 3. Primary agent usage

- Did the assistant use the single `ciel` primary agent for the full pipeline (analyse → plan → implement → verify)?
- If task was analysis/planning → should stay in `ciel` and dispatch subagents, NOT code directly
- If task was implementation → should follow FAIRE gates (test-first, alternatives, idiomatic, quality)
- If wrong flow used → flag as medium severity.

#### 4. Subagent dispatch

For Standard/Critical tasks, verify:

- `@ciel-researcher` dispatched for external lib/API research
- `@ciel-explorer` dispatched for CODEBASE + FLUX steps
- `@ciel-critic MODE=RELIRE` dispatched after 5+ files modified
- `@ciel-critic MODE=CRITIQUER` for Critical tasks before merge
- **Depth ambiguity**: If depth was ambiguous and `depth-classifier` was not invoked → **medium severity**.

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
| "mcp server", "mcp config", ".mcp.json", "claude mcp" | `@ciel-explorer` then `@ciel-critic MODE=RCA` + `debug-reasoning-rca` |

##### 6b. Mid-session re-routing rule (v2.4.1)

For **every Edit/Write tool call** in the session, verify that the intent routing table above was re-scanned against the target file path.

- Example: if an edit targets `.github/workflows/*.yml`, `cicd-security-hardener` should have been dispatched even if the original task was something else.
- Example: if an edit targets `auth/` or `security/`, `stride-analyzer` should have been invoked even if the original depth was classified as Standard.
- If the file path implies a higher depth or a different skill than what was originally dispatched → flag as **high severity**.

#### 7. Skill overlap / redundancy

- Did the assistant invoke **both** `relire-critic` AND `critiquer-auditor` on the same diff? They should be mutually exclusive (`relire-critic` = post-FAIRE quick pass; `critiquer-auditor` = standalone audit of existing code).
- Did `meta-critiquer` fire at end-of-task? If the task ended and no `meta-critiquer` trace exists → flag as **low severity**.
- Any skill invoked **3+ times** for the same scope → flag as a **churn signal**.

#### 8. Context budget check

- Did the assistant use **lazy reading** (e.g., `Grep` before any full `Read` of a file being modified)? If a file was edited without being fully read first → flag as **medium severity**.
- Did the assistant suggest `/compact` or equivalent context compaction when context usage was **> 50%**? If not, and the session continued with degraded context → flag as **medium severity**.
- Did the assistant **mask old observations** (ignore prior tool results older than 3 turns without re-reading)? If old observations were referenced without re-verification → flag as **low severity**.

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
- Expected (per `.opencode/agents/ciel.md:<line>`): `@ciel-researcher` or `@ciel-explorer` dispatch
- Observed: inline `Read`/`Grep` — no dispatch

**Root cause hypothesis**
<one sentence: buried rule, missing gate, plugin not loaded, etc.>

**Incriminated Ciel files**
- `.opencode/agents/ciel.md:<line>` — <reason>
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

Session summary: <N> tasks, <N> tool calls, <N> Task() dispatches. All intents routed correctly. Plugin hooks active. No skill overlap. No dispatch discipline issues.

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
