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
  # Order matters: Claude first, then others
  if [ -f "./.claude/settings.json" ] || [ -d "./.claude" ]; then
    echo "claude"
    return 0
  fi
  
  if [ -f "./opencode.json" ] || [ -d "./.opencode" ]; then
    echo "opencode"
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
  if command -v claude &>/dev/null; then
    echo "claude"
    return 0
  fi
  
  if command -v opencode &>/dev/null; then
    echo "opencode"
    return 0
  fi
  
  echo "unknown"
}

# ─── Platform Names ──────────────────────────────────────────────────────────

get_platform_name() {
  local platform="$1"
  case "$platform" in
    claude)     echo "Claude Code" ;;
    opencode)   echo "OpenCode" ;;
    cursor)     echo "Cursor" ;;
    windsurf)   echo "Windsurf" ;;
    codex)      echo "Codex CLI" ;;
    kilocode)   echo "Kilo Code" ;;
    ollama)     echo "Ollama" ;;
    lmstudio)   echo "LM Studio" ;;
    *)          echo "Unknown ($platform)" ;;
  esac
}
