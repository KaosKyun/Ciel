---
description: Analyze recent sessions for failure modes + user corrections. Proposes skill patch-sets for user approval. Never rewrites autonomously.
---

Invoke the `ciel-improve` skill via the Skill tool with the user's arguments:

```
$ARGUMENTS
```

If `$ARGUMENTS` is empty, invoke the skill with no argument — it will classify the current context and prompt for a task if needed.

The full logic (depth classifier, intent routing, pipeline selection, agent dispatch rules) lives in the `ciel-improve` skill itself. This command file is a thin trigger; modify the skill, not this file, to change behavior.
