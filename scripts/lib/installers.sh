#!/usr/bin/env bash
# Ciel — Platform Installers Library
# Purpose: Install Ciel into specific platforms

set -euo pipefail

# Source platform detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/platform.sh"

# ─── Claude Code Installer ───────────────────────────────────────────────────

install_claude_code() {
  local ciel_dir="$1"
  local project_root="${2:-$(pwd)}"
  local user_scope="${3:-false}"
  
  info "Installing Ciel for Claude Code..."
  
  # Create plugin directory
  local plugin_dir="$HOME/.claude/plugins/ciel"
  mkdir -p "$plugin_dir"
  
  # Copy plugin files
  cp -r "$ciel_dir/hooks/" "$plugin_dir/"
  cp -r "$ciel_dir/skills/" "$plugin_dir/" 2>/dev/null || true
  cp -r "$ciel_dir/agents/" "$plugin_dir/" 2>/dev/null || true
  
  ok "Installed plugin to $plugin_dir"
  
  # Configure project or user settings
  local config_file
  if [ "$user_scope" = "true" ]; then
    config_file="$HOME/.claude/settings.json"
    mkdir -p "$(dirname "$config_file")"
  else
    config_file="$project_root/.claude/settings.json"
    mkdir -p "$(dirname "$config_file")"
  fi
  
  # Backup existing config
  if [ -f "$config_file" ]; then
    cp "$config_file" "${config_file}.bak-$(date +%Y%m%dT%H%M%S)"
  fi
  
  # Generate hook configuration
  cat > "$config_file" <<EOF
{
  "hooks": {
    "SessionStart": {
      "command": "$ciel_dir/hooks/session-start.sh",
      "stdin": true
    },
    "UserPromptSubmit": {
      "command": "$ciel_dir/hooks/user-prompt-submit.sh",
      "stdin": true
    },
    "PreToolUse": {
      "command": "$ciel_dir/hooks/pre-tool-write.sh",
      "stdin": true,
      "matcher": "Write|Edit"
    },
    "PostToolUse": {
      "command": "$ciel_dir/hooks/post-tool-write.sh",
      "stdin": true,
      "matcher": "Write|Edit"
    },
    "PreCompact": {
      "command": "$ciel_dir/hooks/pre-compact.sh",
      "stdin": true
    },
    "Stop": {
      "command": "$ciel_dir/hooks/stop.sh",
      "stdin": true
    }
  }
}
EOF
  
  ok "Configured hooks in $config_file"
  return 0
}

uninstall_claude_code() {
  local plugin_dir="$HOME/.claude/plugins/ciel"
  
  if [ -d "$plugin_dir" ]; then
    rm -rf "$plugin_dir"
    ok "Removed plugin directory: $plugin_dir"
  fi
  
  # Remove project hooks (user settings preserved)
  if [ -f "./.claude/settings.json" ]; then
    rm "./.claude/settings.json"
    ok "Removed project settings"
  fi
}

# ─── OpenCode Installer ──────────────────────────────────────────────────────


# ─── OpenCode Installer ──────────────────────────────────────────────────────

install_opencode() {
  local ciel_dir="$1"
  local project_root="${2:-$(pwd)}"
  
  info "Installing Ciel for OpenCode..."
  
  # Create .opencode directory if needed
  mkdir -p "$project_root/.opencode"
  
  # GitHub base URL for downloads
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  
  # Check if running from temp dir (curl mode) or local repo
  if [[ "$ciel_dir" == /tmp/* ]]; then
    # Curl mode - download files from GitHub
    info "Downloading OpenCode files from GitHub..."
    
    # Create directories
    mkdir -p "$project_root/.opencode/plugins"
    mkdir -p "$project_root/.opencode/agents"
    mkdir -p "$project_root/.opencode/commands"
    mkdir -p "$project_root/.opencode/skills"
    
    # Download plugin
    if ! curl -fsSL "$GITHUB_BASE/.opencode/plugins/ciel.ts" -o "$project_root/.opencode/plugins/ciel.ts" 2>/dev/null; then
      err "Failed to download plugin"
      return 1
    fi
    ok "Downloaded plugin"
    
    # Download agents
    for agent in ciel-plan ciel-build ciel-researcher ciel-explorer ciel-critic ciel-improver; do
      if curl -fsSL "$GITHUB_BASE/.opencode/agents/${agent}.md" -o "$project_root/.opencode/agents/${agent}.md" 2>/dev/null; then
        ok "Downloaded agent: $agent"
      else
        warn "Failed to download agent: $agent"
      fi
    done
    
    # Download commands
    for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-recommend ciel-audit; do
      if curl -fsSL "$GITHUB_BASE/.opencode/commands/${cmd}.md" -o "$project_root/.opencode/commands/${cmd}.md" 2>/dev/null; then
        ok "Downloaded command: $cmd"
      else
        warn "Failed to download command: $cmd"
      fi
    done
    
    # Download skills (ciel-critic)
    mkdir -p "$project_root/.opencode/skills/ciel-critic"
    for skill in relire-critic critiquer-auditor stride-analyzer security-regression-check debug-reasoning-rca self-consistency-verifier; do
      if curl -fsSL "$GITHUB_BASE/.opencode/skills/ciel-critic/${skill}.md" -o "$project_root/.opencode/skills/ciel-critic/${skill}.md" 2>/dev/null; then
        ok "Downloaded skill: ciel-critic/$skill"
      else
        warn "Failed to download skill: ciel-critic/$skill"
      fi
    done
    
    # Download skills (workflow)
    mkdir -p "$project_root/.opencode/skills/workflow"
    for skill in depth-classifier; do
      if curl -fsSL "$GITHUB_BASE/.opencode/skills/workflow/${skill}.md" -o "$project_root/.opencode/skills/workflow/${skill}.md" 2>/dev/null; then
        ok "Downloaded skill: workflow/$skill"
      else
        warn "Failed to download skill: workflow/$skill"
      fi
    done
    
  else
    # Local repo mode - copy files
    mkdir -p "$project_root/.opencode/plugins"
    cp "$ciel_dir/.opencode/plugins/ciel.ts" "$project_root/.opencode/plugins/" || {
      err "Failed to copy plugin"
      return 1
    }
    
    cp -r "$ciel_dir/.opencode/agents/" "$project_root/.opencode/agents/" 2>/dev/null || true
    cp -r "$ciel_dir/.opencode/commands/" "$project_root/.opencode/commands/" 2>/dev/null || true
    cp -r "$ciel_dir/.opencode/skills/" "$project_root/.opencode/skills/" 2>/dev/null || true
    ok "Copied plugin and agents"
  fi
  
  # Update opencode.json
  local config_file="$project_root/opencode.json"
  local backup_file="${config_file}.bak-$(date +%Y%m%dT%H%M%S)"
  
  if [ -f "$config_file" ]; then
    cp "$config_file" "$backup_file"
  fi
  
  # Check if Ciel plugin is already registered
  if [ -f "$config_file" ]; then
    if ! grep -q "ciel" "$config_file" 2>/dev/null; then
      # Add plugin to existing config
      local temp_config
      temp_config=$(mktemp)
      jq '.plugins = (.plugins // []) + ["./plugins/ciel.ts"]' "$config_file" > "$temp_config" && \
        mv "$temp_config" "$config_file"
      ok "Updated opencode.json"
    fi
  else
    # Create new config
    cat > "$config_file" <<EOFCONFIG
{
  "plugins": ["./plugins/ciel.ts"]
}
EOFCONFIG
    ok "Created opencode.json"
  fi
  
  ok "Ciel installed for OpenCode"
}
uninstall_opencode() {
  local project_root="${1:-$(pwd)}"
  
  # Remove plugin
  rm -f "$project_root/.opencode/plugins/ciel.ts"
  
  # Remove agents
  rm -rf "$project_root/.opencode/agents"
  
  # Remove commands
  rm -rf "$project_root/.opencode/commands"
  
  # Restore opencode.json from backup if exists
  local latest_backup
  latest_backup=$(ls -t "$project_root/opencode.json.bak-"* 2>/dev/null | head -1)
  if [ -n "$latest_backup" ]; then
    mv "$latest_backup" "$project_root/opencode.json"
    ok "Restored opencode.json from backup"
  fi
  
  ok "Uninstalled OpenCode components"
}

# ─── Generic Platform Installer ──────────────────────────────────────────────

install_generic() {
  local platform="$1"
  local ciel_dir="$2"
  local project_root="${3:-$(pwd)}"
  
  info "Installing Ciel for $(get_platform_name "$platform")..."
  
  local platform_dir="$ciel_dir/platforms/$platform"
  
  if [ ! -d "$platform_dir" ]; then
    warn "No platform artifacts found for $platform"
    return 1
  fi
  
  # Copy platform-specific files
  case "$platform" in
    cursor)
      mkdir -p "$project_root/.cursor/rules"
      cp "$platform_dir/.cursor/rules/ciel.mdc" "$project_root/.cursor/rules/" 2>/dev/null || true
      ;;
    windsurf)
      mkdir -p "$project_root/.windsurf/rules"
      cp -r "$platform_dir/.windsurf/rules/"* "$project_root/.windsurf/rules/" 2>/dev/null || true
      ;;
    codex)
      cp "$platform_dir/AGENTS.md" "$project_root/" 2>/dev/null || true
      cp -r "$platform_dir/.codex/"* "$project_root/.codex/" 2>/dev/null || true
      ;;
    kilocode)
      mkdir -p "$project_root/.kilocode/rules"
      cp "$platform_dir/.kilocode/rules/ciel.md" "$project_root/.kilocode/rules/" 2>/dev/null || true
      mkdir -p "$project_root/.kilo/agents"
      cp -r "$platform_dir/.kilo/agents/"* "$project_root/.kilo/agents/" 2>/dev/null || true
      ;;
    ollama)
      cp "$platform_dir/Modelfile" "$project_root/" 2>/dev/null || true
      info "To use with Ollama: ollama create ciel -f $project_root/Modelfile"
      ;;
    lmstudio)
      cp "$platform_dir/ciel.preset.json" "$project_root/" 2>/dev/null || true
      cp "$platform_dir/system-prompt.md" "$project_root/" 2>/dev/null || true
      ;;
  esac
  
  ok "Installed $(get_platform_name "$platform") components"
  return 0
}

uninstall_generic() {
  local platform="$1"
  local project_root="${2:-$(pwd)}"
  
  case "$platform" in
    cursor)
      rm -f "$project_root/.cursor/rules/ciel.mdc"
      ;;
    windsurf)
      rm -rf "$project_root/.windsurf/rules"
      ;;
    codex)
      rm -f "$project_root/AGENTS.md"
      rm -rf "$project_root/.codex"
      ;;
    kilocode)
      rm -rf "$project_root/.kilocode/rules"
      rm -rf "$project_root/.kilo/agents"
      ;;
    ollama)
      rm -f "$project_root/Modelfile"
      ;;
    lmstudio)
      rm -f "$project_root/ciel.preset.json"
      rm -f "$project_root/system-prompt.md"
      ;;
  esac
  
  ok "Uninstalled $(get_platform_name "$platform") components"
}
