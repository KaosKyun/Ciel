#!/bin/bash
# Ciel v9 — PreToolUse hook for Read|Bash
# Gate DISPATCH: blocks source-code Read/Bash until researcher+explorer dispatched.
# Always allows: config files, docs, CI files, .ciel/*, .claude/*
# Escape hatch: [CIEL_GATE_BYPASS] in tool input

INPUT=$(cat 2>/dev/null || echo "{}")

# ── Depth check ──
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
TASK_DEPTH="Standard"
if [ -n "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.ciel/last-depth" ]; then
  TASK_DEPTH=$(cat "$PROJECT_DIR/.ciel/last-depth" 2>/dev/null || echo "Standard")
fi
[ "$TASK_DEPTH" = "Trivial" ] && exit 0
[ "$TASK_DEPTH" = "Spike" ] && exit 0

# ── Bypass check ──
if echo "$INPUT" | grep -q '\[CIEL_GATE_BYPASS\]'; then
  echo "[CIEL] Dispatch gate bypassed" >&2
  exit 0
fi

# ── Dispatch check ──
if ls /tmp/ciel_dispatched.* >/dev/null 2>&1; then
  exit 0
fi

# ── Extract tool fields ──
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

# ── Read gate: allow config/docs, block source code ──
if [ "$TOOL_NAME" = "Read" ] && [ -n "$FILE_PATH" ]; then
  # Always-allow: .ciel, .claude, .github, project config, docs
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
    exit 0
  fi

  echo "[CIEL DISPATCH GATE] Blocked: Read $(basename "$FILE_PATH") before researcher dispatch" >&2
  echo "  Dispatch ciel-researcher + ciel-explorer in parallel first." >&2
  echo "  Or add [CIEL_GATE_BYPASS] to bypass." >&2
  exit 2
fi

# ── Bash gate: allow infra, block source-code research ──
if [ "$TOOL_NAME" = "Bash" ] && [ -n "$BASH_CMD" ]; then
  if echo "$BASH_CMD" | grep -qE '^(ls |find |git (status|diff|log|branch|remote|config|stash|add |commit|push|pull|fetch|checkout|switch|restore)|mkdir |cd |npm |npx |node -[vp]|pnpm |yarn |cargo |pip |poetry |python3 -c|which |type |command -v|echo |cat .*(\.json|\.md|\.yml|\.yaml|\.toml|\.lock|VERSION|Makefile|README|\.gitignore)|gh (pr|issue|release|run|repo|workflow))'; then
    exit 0
  fi

  if echo "$BASH_CMD" | grep -qE '(grep |rg |ag |cat .*\.(kt|ts|tsx|js|jsx|py|go|rs|rb|java|php|scala|swift|cs|cpp|c|h|vue|svelte)|tail |head |curl |wget )'; then
    echo "[CIEL DISPATCH GATE] Blocked: research Bash before dispatch" >&2
    echo "  Command: $(echo "$BASH_CMD" | cut -c1-80)" >&2
    echo "  Dispatch ciel-researcher + ciel-explorer first, or use [CIEL_GATE_BYPASS]." >&2
    exit 2
  fi
fi

exit 0
