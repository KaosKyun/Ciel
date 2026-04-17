---
description: Trigger the Ciel agent for deep-reasoning workflow
---

# /ciel — Trigger Ciel Agent

**OpenCode users:** This command loads the Ciel skill, but to use the full Ciel agent with subagent dispatch, use:
```
@ciel $ARGUMENTS
```

## Instructions

If user typed `/ciel`, explain:
1. On Claude Code: loads skill and orchestrates inline
2. On OpenCode: use `@ciel` instead to activate the primary agent

**For OpenCode**: Switch to the Ciel agent or invoke it directly:
- Press `Tab` and select "ciel" agent
- Or type: `@ciel $ARGUMENTS`

**For Claude Code**: Load the skill:
```
skill({ name: "ciel" })
```

User's input:
```
$ARGUMENTS
```
