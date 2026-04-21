#!/usr/bin/env bash
# Ciel — Platform Detection Library
# Purpose: Auto-detect which AI coding platform is in use

set -euo pipefail

# ─── Platform Detection ──────────────────────────────────────────────────────

# Detect if running inside a specific platform
# Returns: platform name or "unknown"
detect_platform() {
  local forced_platform="${CIEL_FORCE_PLATFORM:-}"
  
  # If forced via env var, use it
  if [ -n "$forced_platform" ]; then
    echo "$forced_platform"
    return 0
  fi
  
  # Check project files first (most reliable)
  if [ -f "./opencode.json" ] || [ -d "./.opencode" ]; then
    echo "opencode"
    return 0
  fi
  
  if [ -f "./.claude/settings.json" ] || [ -d "./.claude" ]; then
    echo "claude"
    return 0
  fi
  
  if [ -d "./.cursor" ]; then
    echo "cursor"
    return 0
  fi
  
  if [ -d "./.windsurf" ]; then
    echo "windsurf"
    return 0
  fi
  
  if [ -d "./.codex" ]; then
    echo "codex"
    return 0
  fi
  
  if [ -d "./.kilocode" ] || [ -d "./.kilo" ]; then
    echo "kilocode"
    return 0
  fi
  
  # Check CLI availability
  if command -v opencode &>/dev/null && ! command -v claude &>/dev/null; then
    echo "opencode"
    return 0
  fi
  
  if command -v claude &>/dev/null; then
    echo "claude"
    return 0
  fi
  
  # Check for Ollama (always available if installed)
  if command -v ollama &>/dev/null; then
    echo "ollama"
    return 0
  fi
  
  # Check for LM Studio CLI
  if command -v lmstudio &>/dev/null; then
    echo "lmstudio"
    return 0
  fi
  
  echo "unknown"
  return 1
}

# ─── Platform Validation ─────────────────────────────────────────────────────

# Validate that a platform is properly configured
# Args: $1 = platform name
# Returns: 0 if valid, 1 if invalid
validate_platform() {
  local platform="$1"
  
  case "$platform" in
    claude)
      [ -d "$HOME/.claude" ] || return 1
      ;;
    opencode)
      [ -d "$HOME/.config/opencode" ] || [ -d "$HOME/.opencode" ] || return 1
      ;;
    cursor)
      [ -d "$HOME/.cursor" ] || return 1
      ;;
    windsurf)
      [ -d "$HOME/.code-server" ] || [ -d "$HOME/.vscode" ] || return 1
      ;;
    codex)
      [ -d "$HOME/.codex" ] || return 1
      ;;
    kilocode)
      [ -d "$HOME/.kilocode" ] || return 1
      ;;
    ollama|lmstudio)
      # Always valid if CLI exists
      return 0
      ;;
    *)
      return 1
      ;;
  esac
  
  return 0
}

# ─── Platform Helpers ────────────────────────────────────────────────────────

# Get platform display name
# Args: $1 = platform id
get_platform_name() {
  case "$1" in
    claude)     echo "Claude Code" ;;
    opencode)   echo "OpenCode" ;;
    cursor)     echo "Cursor" ;;
    windsurf)   echo "Windsurf" ;;
    codex)      echo "Codex CLI" ;;
    kilocode)   echo "Kilo Code" ;;
    ollama)     echo "Ollama" ;;
    lmstudio)   echo "LM Studio" ;;
    *)          echo "Unknown ($1)" ;;
  esac
}

# Get platform config file path
# Args: $1 = platform id, $2 = project root (optional)
get_platform_config() {
  local platform="$1"
  local project_root="${2:-$(pwd)}"
  
  case "$platform" in
    claude)
      if [ -f "$project_root/.claude/settings.json" ]; then
        echo "$project_root/.claude/settings.json"
      else
        echo "$HOME/.claude/settings.json"
      fi
      ;;
    opencode)
      if [ -f "$project_root/opencode.json" ]; then
        echo "$project_root/opencode.json"
      else
        echo "$HOME/.config/opencode/opencode.json"
      fi
      ;;
    cursor)
      echo "$HOME/.cursor/mcp.json"
      ;;
    windsurf)
      echo "$HOME/.code-server/mcp.json"
      ;;
    codex)
      echo "$HOME/.codex/config.json"
      ;;
    kilocode)
      echo "$HOME/.kilocode/config.json"
      ;;
    *)
      echo ""
      return 1
      ;;
  esac
}

# Check if platform CLI is installed
# Args: $1 = platform id
has_platform_cli() {
  case "$1" in
    claude)   command -v claude &>/dev/null ;;
    opencode) command -v opencode &>/dev/null ;;
    cursor)   command -v cursor &>/dev/null ;;
    windsurf) command -v code-server &>/dev/null || command -v code &>/dev/null ;;
    codex)    command -v codex &>/dev/null ;;
    kilocode) command -v kilocode &>/dev/null ;;
    ollama)   command -v ollama &>/dev/null ;;
    lmstudio) command -v lmstudio &>/dev/null ;;
    *)        false ;;
  esac
}

# Print platform installation instructions
# Args: $1 = platform id
print_install_instructions() {
  case "$1" in
    claude)
      cat <<'EOF'
Claude Code is not installed. Install with:
  npm install -g @anthropic-ai/claude-code
Or visit: https://claude.ai/download
EOF
      ;;
    opencode)
      cat <<'EOF'
OpenCode is not installed. Install with:
  npm install -g @opencode-ai/core
Or visit: https://opencode.ai/docs
EOF
      ;;
    cursor)
      cat <<'EOF'
Cursor is not installed. Download from:
  https://cursor.sh
EOF
      ;;
    windsurf)
      cat <<'EOF'
Windsurf is not installed. Download from:
  https://codeium.com/windsurf
EOF
      ;;
    codex)
      cat <<'EOF'
Codex CLI is not installed. Install with:
  npm install -g @openai/codex
EOF
      ;;
    kilocode)
      cat <<'EOF'
Kilo Code is not installed. Download from:
  https://kilocode.ai
EOF
      ;;
    ollama)
      cat <<'EOF'
Ollama is not installed. Install with:
  curl -fsSL https://ollama.ai/install.sh | sh
Or visit: https://ollama.ai
EOF
      ;;
    lmstudio)
      cat <<'EOF'
LM Studio is not installed. Download from:
  https://lmstudio.ai
EOF
      ;;
  esac
}
