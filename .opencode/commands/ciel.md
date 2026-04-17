---
description: Load the ciel skill to classify task depth and route through the Ciel pipeline
---
You must load the `ciel` skill now using the Skill tool: `skill({ name: "ciel" })`.

Then follow the skill instructions to classify the user's task depth and route through the appropriate pipeline.

User's input:
```
$ARGUMENTS
```

If `$ARGUMENTS` is empty, load the skill anyway — it will classify the current context.
