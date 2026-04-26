@AGENTS.md

## Claude Code specifics

### Pipeline v5 (16 steps)
DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE -> RECHERCHE -> SECURITE -> CODEBASE -> EVALUER -> ASK2 -> FAIRE -> ADR -> RELIRE -> PROUVER -> MEMOIRE -> META

### Hooks (defined in .claude/settings.json)
- PreToolUse: test-first gate, destructive command block
- PostToolUse: file tracking + RELIRE detection
- SubagentStop: META-CRITIQUER

### Subagents (in .claude/agents/)
- ciel-researcher (model: haiku, memory: user) -- external docs research
- ciel-explorer (model: sonnet, memory: project, isolation: worktree) -- codebase exploration
- ciel-critic (model: opus, memory: local) -- code review + feedback + investigation
- ciel-improver (model: sonnet) -- self-improvement

### SPIKE mode
Create `.ciel/exploration.active` file to enter spike mode (gates assouplies).
Subagent `ciel-explorer` uses `isolation: worktree` for safe exploration.

### Auto memory
Auto memory is enabled. Claude saves learnings across sessions.
Run `/memory` to view or edit. Memory per git repository at `~/.claude/projects/<project>/memory/`.

### Model config
Main: sonnet, Plan, Explore: haiku, Critic: opus via subagent definitions.
