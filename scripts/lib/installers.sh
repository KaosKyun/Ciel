#!/usr/bin/env bash
# Ciel — Platform Installers Library

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Claude Code Installer ───────────────────────────────────────────────────

install_claude_code() {
  local ciel_dir="$1"
  local project_root="${2:-$(pwd)}"
  local user_scope="${3:-false}"
  
  info "Installing Ciel for Claude Code..."
  
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  local plugin_dir="$HOME/.claude/plugins/ciel"
  mkdir -p "$plugin_dir"
  
  if [[ "$ciel_dir" == /tmp/* ]]; then
    # Curl mode - download from GitHub
    info "Downloading Ciel components from GitHub..."
    
    # Download hooks
    for hook in SessionStart.sh SessionEnd.sh PreToolUse.sh PostToolUse.sh PreCompact.sh PostCompact.sh; do
      curl -fsSL "$GITHUB_BASE/hooks/$hook" -o "$plugin_dir/$hook" 2>/dev/null && ok "Hook: $hook" || warn "Missing: $hook"
    done
    
    # Download skills
    mkdir -p "$plugin_dir/skills/ciel-critic" "$plugin_dir/skills/workflow"
    for skill in relire-critic critiquer-auditor stride-analyzer security-regression-check debug-reasoning-rca self-consistency-verifier; do
      curl -fsSL "$GITHUB_BASE/skills/ciel-critic/${skill}.md" -o "$plugin_dir/skills/ciel-critic/${skill}.md" 2>/dev/null || true
    done
    for skill in depth-classifier quoi-framer avec-quoi-versioner flux-narrator evaluer-sizer faire-gatekeeper prouver-verifier; do
      curl -fsSL "$GITHUB_BASE/skills/workflow/${skill}.md" -o "$plugin_dir/skills/workflow/${skill}.md" 2>/dev/null || true
    done
    
    # Download agents
    mkdir -p "$plugin_dir/agents"
    for agent in ciel-plan ciel-build ciel-researcher ciel-explorer ciel-critic ciel-improver; do
      curl -fsSL "$GITHUB_BASE/agents/${agent}.md" -o "$plugin_dir/agents/${agent}.md" 2>/dev/null || true
    done
    
    ok "Downloaded Ciel components"
  else
    # Local mode - copy files
    cp -r "$ciel_dir/hooks/" "$plugin_dir/" 2>/dev/null || true
    cp -r "$ciel_dir/skills/" "$plugin_dir/" 2>/dev/null || true
    cp -r "$ciel_dir/agents/" "$plugin_dir/" 2>/dev/null || true
    ok "Copied Ciel components"
  fi
  
  # Configure settings
  local config_file
  if [ "$user_scope" = "true" ]; then
    config_file="$HOME/.claude/settings.json"
  else
    config_file="$project_root/.claude/settings.json"
  fi
  mkdir -p "$(dirname "$config_file")"
  
  [ -f "$config_file" ] && cp "$config_file" "${config_file}.bak-$(date +%Y%m%dT%H%M%S)"
  
  cat > "$config_file" << 'EOFCONFIG'
{
  "hooks": {
    "SessionStart": {"command": "bash", "args": ["~/.claude/plugins/ciel/SessionStart.sh"]},
    "SessionEnd": {"command": "bash", "args": ["~/.claude/plugins/ciel/SessionEnd.sh"]},
    "PreToolUse": {"command": "bash", "args": ["~/.claude/plugins/ciel/PreToolUse.sh"]},
    "PostToolUse": {"command": "bash", "args": ["~/.claude/plugins/ciel/PostToolUse.sh"]},
    "PreCompact": {"command": "bash", "args": ["~/.claude/plugins/ciel/PreCompact.sh"]},
    "PostCompact": {"command": "bash", "args": ["~/.claude/plugins/ciel/PostCompact.sh"]}
  }
}
EOFCONFIG
  
  ok "Configured Claude Code hooks"
}

uninstall_claude_code() {
  local project_root="${1:-$(pwd)}"
  rm -rf "$HOME/.claude/plugins/ciel"
  rm -f "$project_root/.claude/settings.json"
  ok "Uninstalled Claude Code components"
}

# ─── OpenCode Installer ──────────────────────────────────────────────────────

install_opencode() {
  local ciel_dir="$1"
  local project_root="${2:-$(pwd)}"
  
  info "Installing Ciel for OpenCode..."
  
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  mkdir -p "$project_root/.opencode/plugins" "$project_root/.opencode/agents" "$project_root/.opencode/commands" "$project_root/.opencode/skills"
  
  if [[ "$ciel_dir" == /tmp/* ]]; then
    info "Downloading OpenCode files from GitHub..."
    
    curl -fsSL "$GITHUB_BASE/.opencode/plugins/ciel.ts" -o "$project_root/.opencode/plugins/ciel.ts" && ok "Plugin" || err "Failed to download plugin"
    
    for agent in ciel-plan ciel-build ciel-researcher ciel-explorer ciel-critic ciel-improver; do
      curl -fsSL "$GITHUB_BASE/.opencode/agents/${agent}.md" -o "$project_root/.opencode/agents/${agent}.md" 2>/dev/null && ok "Agent: $agent" || true
    done
    
    for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-recommend ciel-audit; do
      curl -fsSL "$GITHUB_BASE/.opencode/commands/${cmd}.md" -o "$project_root/.opencode/commands/${cmd}.md" 2>/dev/null && ok "Command: $cmd" || true
    done
    
    mkdir -p "$project_root/.opencode/skills/ciel-critic" "$project_root/.opencode/skills/workflow"
    for skill in relire-critic critiquer-auditor stride-analyzer security-regression-check debug-reasoning-rca self-consistency-verifier; do
      curl -fsSL "$GITHUB_BASE/.opencode/skills/ciel-critic/${skill}.md" -o "$project_root/.opencode/skills/ciel-critic/${skill}.md" 2>/dev/null || true
    done
    curl -fsSL "$GITHUB_BASE/.opencode/skills/workflow/depth-classifier.md" -o "$project_root/.opencode/skills/workflow/depth-classifier.md" 2>/dev/null || true
  else
    cp "$ciel_dir/.opencode/plugins/ciel.ts" "$project_root/.opencode/plugins/" && ok "Plugin copied"
    cp -r "$ciel_dir/.opencode/agents/" "$project_root/.opencode/agents/" 2>/dev/null || true
    cp -r "$ciel_dir/.opencode/commands/" "$project_root/.opencode/commands/" 2>/dev/null || true
    cp -r "$ciel_dir/.opencode/skills/" "$project_root/.opencode/skills/" 2>/dev/null || true
    ok "Copied OpenCode components"
  fi
  
  # Update opencode.json
  local config_file="$project_root/opencode.json"
  [ -f "$config_file" ] && cp "$config_file" "${config_file}.bak-$(date +%Y%m%dT%H%M%S)"
  
  if [ -f "$config_file" ]; then
    if ! grep -q "ciel" "$config_file" 2>/dev/null; then
      local temp_config=$(mktemp)
      jq '.plugins = (.plugins // []) + ["./plugins/ciel.ts"]' "$config_file" > "$temp_config" && mv "$temp_config" "$config_file"
      ok "Updated opencode.json"
    fi
  else
    echo '{"plugins": ["./plugins/ciel.ts"]}' > "$config_file"
    ok "Created opencode.json"
  fi
}

uninstall_opencode() {
  local project_root="${1:-$(pwd)}"
  rm -f "$project_root/.opencode/plugins/ciel.ts"
  rm -rf "$project_root/.opencode/agents" "$project_root/.opencode/commands" "$project_root/.opencode/skills"
  ok "Uninstalled OpenCode components"
}

# ─── Generic Platform Installer ──────────────────────────────────────────────

install_generic() {
  local platform="$1"
  local ciel_dir="$2"
  local project_root="${3:-$(pwd)}"
  
  local platform_name
  case "$platform" in
    cursor) platform_name="Cursor" ;;
    windsurf) platform_name="Windsurf" ;;
    codex) platform_name="Codex" ;;
    kilocode) platform_name="KiloCode" ;;
    *) platform_name="$platform" ;;
  esac
  
  info "Installing Ciel for $platform_name..."
  
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  local target_dir
  
  case "$platform" in
    cursor) target_dir="$project_root/.cursor/rules" ;;
    windsurf) target_dir="$project_root/.windsurf/rules" ;;
    codex) target_dir="$project_root/.codex" ;;
    kilocode) target_dir="$project_root/.kilocode/rules" ;;
  esac
  
  mkdir -p "$target_dir"
  
  if [[ "$ciel_dir" == /tmp/* ]]; then
    curl -fsSL "$GITHUB_BASE/platforms/$platform/ciel.md" -o "$target_dir/ciel.md" 2>/dev/null && ok "Installed" || warn "Download failed"
  else
    cp "$ciel_dir/platforms/$platform/ciel.md" "$target_dir/" 2>/dev/null && ok "Installed" || warn "Copy failed"
  fi
}
