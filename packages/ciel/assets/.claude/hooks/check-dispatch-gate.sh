#!/bin/bash
# Ciel — PreToolUse hook for Read|Bash
# Trigger: PreToolUse on Read|Bash
# Purpose: BLOCK inline source-code research until ciel-researcher is dispatched.
#   Forces the model to dispatch researcher + explorer in parallel before
#   reading source files or running research commands (grep, cat, curl, rg, etc.).
# Always allows: config files, project docs, CI files, state files.
# Escape hatch: [CIEL_GATE_BYPASS] anywhere in the tool input bypasses the gate.
# Dispatch tracker: /tmp/ciel_dispatched.* (created by SubagentStart hooks)

INPUT=$(cat 2>/dev/null || echo "{}")

# ── Depth check ──
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
TASK_DEPTH="Standard"
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.ciel/last-depth" ]; then
  TASK_DEPTH=$(cat "$PROJECT_DIR/.ciel/last-depth" 2>/dev/null || echo "Standard")
fi

# Trivial + Spike tasks always pass — no dispatch required
[ "$TASK_DEPTH" = "Trivial" ] && exit 0
[ "$TASK_DEPTH" = "Spike" ] && exit 0

# ── Bypass check ──
if echo "$INPUT" | grep -q '\[CIEL_GATE_BYPASS\]'; then
  echo "[CIEL] Dispatch gate bypassed via [CIEL_GATE_BYPASS]" >&2
  exit 0
fi

# ── Dispatch check ──
# If any Ciel agent has been dispatched this session, allow inline research.
# /tmp/ciel_dispatched.* files are created by SubagentStart hooks for
# ciel-researcher, ciel-explorer, and ciel-critic.
if ls /tmp/ciel_dispatched.* >/dev/null 2>&1; then
  exit 0
fi

# ── Extract target ──
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_name', ''))
except:
    print('')
" 2>/dev/null || echo "")

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    print(ti.get('file_path', ti.get('path', '')))
except:
    print('')
" 2>/dev/null || echo "")

BASH_CMD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    print(ti.get('command', ''))
except:
    print('')
" 2>/dev/null || echo "")

# ── Read gate ──
# Always-allow list: config files the model MUST be able to read for DOCS step.
# These are needed BEFORE any dispatch — CLAUDE.md, AGENTS.md, .ciel/*, .claude/*,
# SKILL.md, package.json, README, Makefile, VERSION, docker-compose, CI configs.
if [ "$TOOL_NAME" = "Read" ] && [ -n "$FILE_PATH" ]; then
  if echo "$FILE_PATH" | grep -qE '(^|/)\.(ciel|claude|github|opencode)(/|$|\.)'; then
    exit 0
  fi
  if echo "$FILE_PATH" | grep -qE '(^|/)(CLAUDE\.md|AGENTS\.md|ciel-overlay\.md|package\.json|README|Makefile|VERSION|Dockerfile|docker-compose|\.gitignore|tsconfig.*\.json|\.env\.example)$'; then
    exit 0
  fi
  if echo "$FILE_PATH" | grep -qE '(^|/)SKILL\.md$'; then
    exit 0
  fi
  if echo "$FILE_PATH" | grep -qE '\.(yml|yaml|toml|cfg|ini|conf|json|md|txt|css|html|xml|svg)$'; then
    # Config/docs files — allow (but NOT source code like .ts in JSON disguise)
    # The depth classification + pipeline docs phase needs broad config access
    exit 0
  fi

  # Source code file — BLOCK until researcher dispatched
  echo "[CIEL DISPATCH GATE] BLOCKED: Read $(basename "$FILE_PATH") before researcher dispatch" >&2
  echo "" >&2
  echo "  Depth: $TASK_DEPTH — no Ciel agent dispatched yet." >&2
  echo "  Ciel pipeline requires dispatching ciel-researcher + ciel-explorer" >&2
  echo "  in parallel BEFORE reading source code. This ensures official docs," >&2
  echo "  anti-patterns, and codebase patterns are checked first." >&2
  echo "" >&2
  echo "  To proceed without dispatch: add [CIEL_GATE_BYPASS] to the tool input." >&2
  echo "  But prefer dispatching — it prevents the blind-pattern-copy anti-pattern." >&2
  exit 2
fi

# ── Bash gate ──
# Allow infrastructure commands (ls, find, git status, mkdir, cd, npm, node -v, etc.)
# Block research commands that read/search source files without dispatch.
if [ "$TOOL_NAME" = "Bash" ] && [ -n "$BASH_CMD" ]; then
  # Always-allow patterns: infrastructure, package management, git meta
  if echo "$BASH_CMD" | grep -qE '^(ls |find |git (status|diff|log|branch|remote|config|stash|add |commit|push|pull|fetch|checkout|switch|restore)|mkdir |cd |npm |npx |node -[vp]|pnpm |yarn |cargo |pip |poetry |python3 -c|which |type |command -v|echo |cat .*(\.json|\.md|\.yml|\.yaml|\.toml|\.lock|VERSION|Makefile|README|\.gitignore)|gh (pr|issue|release|run|repo|workflow))'; then
    exit 0
  fi

  # Research commands that scan/read source code — BLOCK
  if echo "$BASH_CMD" | grep -qE '(grep |rg |ag |cat .*\.(kt|ts|tsx|js|jsx|py|go|rs|rb|java|php|scala|swift|cs|cpp|c|h|vue|svelte)|tail |head |curl |wget )'; then
    echo "[CIEL DISPATCH GATE] BLOCKED: Research Bash before researcher dispatch" >&2
    echo "" >&2
    echo "  Depth: $TASK_DEPTH — no Ciel agent dispatched yet." >&2
    echo "  Command: $(echo "$BASH_CMD" | cut -c1-80)" >&2
    echo "  Dispatch ciel-researcher + ciel-explorer first." >&2
    echo "  Or add [CIEL_GATE_BYPASS] if this is infrastructure." >&2
    exit 2
  fi
fi

exit 0
