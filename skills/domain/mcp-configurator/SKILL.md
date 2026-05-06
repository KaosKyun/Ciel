---
name: mcp-configurator
description: How to configure, register, and troubleshoot MCP servers for Claude Code (settings.json mcpServers) and OpenCode (.mcp.json). Covers Playwright, Context7, and custom MCP servers. Invoked when the user asks about MCP, servers fail to connect, or a skill requires MCP tools.
allowed-tools: Read, Grep, Bash
---

# MCP Configurator — Server Registration & Troubleshooting

## What this covers

How to configure MCP servers so that tools like Playwright (visual critique) and Context7 (live docs) are available. MCP failures are silent — a mistyped command or missing env var means the tool just doesn't appear.

## Core principle

**MCP config is JSON — one typo breaks everything.** After any edit, verify with `mcp list` or check the server's stderr log.

## Server types

### Standard (Claude Code settings.json)

```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"],
      "env": {}
    },
    "context7": {
      "command": "npx",
      "args": ["@context7/mcp-server"]
    }
  }
}
```

### Sandboxed (Claude Code — user settings)

Same structure in `~/.claude/settings.json` under the `mcpServers` key. Sandboxed servers can access files outside the project.

### OpenCode (.mcp.json)

Place `.mcp.json` at project root with the same `mcpServers` structure. OpenCode reads this file on startup.

## Common failure patterns

| Symptom | Cause | Fix |
|---------|-------|-----|
| Tool not showing up | Server failed to start | Check `npx <package>` works standalone |
| "Command not found" | Missing dependency | `npm install -g <package>` or use `npx` |
| Permission denied | Wrong path in command | Use absolute path or verify `which npx` |
| Timeout on first use | Server downloading | Wait — first `npx` run downloads the package |

## Verification

```bash
# Test a server starts
npx @playwright/mcp@latest --help

# Check if MCP tools are registered (Claude Code)
# Tools appear in the tool list when the server connects
```

## When triggered

- CIEL SKILL.md references Playwright or Context7 MCP
- User reports MCP tools not appearing
- Setting up a new project with Ciel
