---
name: ciel
description: Invoke the Ciel deep-reasoning orchestrator. Classifies depth, routes pipeline, dispatches @ciel-* skills.
---

Invoke the `ciel` skill with the user's arguments:

```
$ARGUMENTS
```

If `$ARGUMENTS` is empty, invoke the skill with no argument — it will classify the current context.

The full logic (depth classifier, intent routing, pipeline selection) lives in the `ciel` skill. Modify the skill, not this workflow, to change behavior.
