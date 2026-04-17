---
description: "Audits the current session for Ciel paradigm violations — missed Task dispatches, inline gathering, hook inactivity. Produces a copy-paste report for fixing in a fresh session."
---

# /ciel-audit — Session post-mortem

*Generates a structured report of Ciel behavior violations observed in the current session.*

Usage: `/ciel-audit`

Runs inline in the main session. Does not dispatch agents. Does not depend on hooks being active.

---

## Instructions

You are auditing the **current conversation session**. Produce a markdown report of Ciel violations found. Begin with `# Ciel Session Audit Report` and end with `**End of audit report.**`

### What to audit

1. **Dispatch discipline** — did the assistant dispatch a Task() within the first 3 tool calls after `/ciel`?
2. **Hook activity** — search for `CIEL depth hint`, `CIEL [CRITIQUE]`, `META-CRITIQUER` signatures
3. **Skill coverage** — Standard tasks need researcher + explorer dispatched; Critical need stride-analyzer
4. **Agent report quality** — any Task() returning < 200 tokens = suspect truncation
5. **Intent routing** — map user prompts to expected skills

### Report format

```
# Ciel Session Audit Report

**Verdict**: <PASS | VIOLATIONS FOUND | HOOKS INACTIVE>

## Violations
1. <name> — severity: <critical|high|medium|low>
   **Evidence**: <tool calls>
   **Fix**: <file:line change>

**End of audit report.**
```

No preamble. No meta-commentary. No fixes applied — report only.
