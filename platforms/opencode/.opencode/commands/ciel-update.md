---
command: ciel-update
description: Update Ciel to the latest version
subtask: false
---

# /ciel-update — Update Ciel

Force reinstall of all Ciel files. Useful after updating the npm package.

Usage: `/ciel-update`

## What it does

- Re-copies agent definitions
- Re-copies command definitions
- Re-patches `opencode.json`
- Refreshes `.ciel/` state directory
