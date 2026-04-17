---
description: Slash trigger for the `ciel` orchestrator skill. Use `/ciel <task>` to start depth-aware reasoning explicitly. The skill itself (auto-invoked on coding tasks) contains the full orchestration logic.
---

# /ciel — Slash trigger

Invoke the `ciel` skill via the Skill tool with the task argument:

```
$ARGUMENTS
```

If `$ARGUMENTS` is empty, invoke the skill with no argument — it will classify the current context and prompt for a task if needed.

---

**Note**: this command file is a thin wrapper. The orchestrator logic (depth classifier, intent routing, pipeline selection, agent dispatch rules) lives in `skills/ciel/SKILL.md`. Modify the skill, not this file, to change behavior.
