---
description: Displays the current Ciel environment status — active version, loaded skills, registered hooks, last session state, and configuration health. A diagnostic entry point for "is Ciel working?" questions.
subtask: false
---

# /ciel-status — Ciel Environment Health Check

*Displays the current Ciel environment status: version, skills, hooks, and config.*

Usage: `/ciel-status`

## Instructions

1. **Run integrity check first**: Execute `npx ciel-init check` — this verifies version against NPM AND checks all Ciel files are present, opencode.json references the plugin, agents/commands exist, etc.

2. **If CLI not available** (npx fails), fall back to manual checks:
   - Check `.ciel/memory.json` for installed version
   - Verify `opencode.json` is valid JSON with Ciel plugin reference
   - Verify `.opencode/plugins/ciel.js` (or `.ts`) exists
   - Verify `.opencode/agents/` has all 5 agent definitions
   - Verify `.opencode/commands/ciel*.md` exist (commands)
   - Verify `.ciel/map.json` and `.ciel/memory.json` exist and are parseable
   - Verify `AGENTS.md` exists and references Ciel pipeline
   - Verify `opencode.json` has `instructions: ["AGENTS.md"]`

3. **Present results** — show a clear summary: what's OK, what's missing, version status.

## When triggered

- User asks "is Ciel working?" or "check Ciel health"
- After ciel-init to verify installation
- Debugging hook failures or missing depth classification
- User reports missing commands or broken Ciel behavior
