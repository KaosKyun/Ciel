#!/usr/bin/env bash
# Ciel — Platform Installers Library

set -euo pipefail

CIEL_CENTRAL="$HOME/.ciel"

# ─── Central Resources Installer (skills + commands) ─────────────────────────

install_central_resources() {
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  
  info "Installing central Ciel resources to $CIEL_CENTRAL..."
  mkdir -p "$CIEL_CENTRAL/skills/ciel-critic" "$CIEL_CENTRAL/skills/workflow" "$CIEL_CENTRAL/skills/research" "$CIEL_CENTRAL/skills/security" "$CIEL_CENTRAL/skills/domain" "$CIEL_CENTRAL/skills/meta" "$CIEL_CENTRAL/skills/utility"
  mkdir -p "$CIEL_CENTRAL/commands"
  
  # Skills
  for category in ciel-critic workflow research security domain meta utility; do
    for skill_file in $(curl -fsSL "https://api.github.com/repos/KaosKyun/Ciel/contents/skills/$category" 2>/dev/null | jq -r '.[].name' 2>/dev/null); do
      curl -fsSL "$GITHUB_BASE/skills/$category/$skill_file" -o "$CIEL_CENTRAL/skills/$category/$skill_file" 2>/dev/null || true
    done
  done
  
  # Commands (central copies)
  for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-audit; do
    curl -fsSL "$GITHUB_BASE/commands/${cmd}.md" -o "$CIEL_CENTRAL/commands/${cmd}.md" 2>/dev/null && ok "Central command: $cmd" || true
  done
  
  ok "Central resources installed"
}

create_skills_symlink() {
  local platform_dir="$1"
  local source_dir="${2:-$CIEL_CENTRAL/skills}"
  rm -rf "$platform_dir/skills"
  ln -sf "$source_dir" "$platform_dir/skills"
  [ -L "$platform_dir/skills" ] && ok "Symlink: skills → $source_dir" || warn "Symlink failed"
}

sync_local_skills_to_central() {
  local ciel_dir="$1"
  if [ -d "$ciel_dir/skills" ] && [[ "$ciel_dir" != /tmp/* ]]; then
    info "Syncing local skills to central store..."
    mkdir -p "$CIEL_CENTRAL/skills"
    # Copy all skill categories from project to central (recursive for nested skills)
    for category_dir in "$ciel_dir/skills"/*/; do
      local category_name
      category_name=$(basename "$category_dir")
      mkdir -p "$CIEL_CENTRAL/skills/$category_name"
      # Handle both flat files and nested skill directories
      for item in "$category_dir"*; do
        if [ -f "$item" ]; then
          cp "$item" "$CIEL_CENTRAL/skills/$category_name/" 2>/dev/null || true
        elif [ -d "$item" ]; then
          local item_name
          item_name=$(basename "$item")
          mkdir -p "$CIEL_CENTRAL/skills/$category_name/$item_name"
          cp -r "$item/"* "$CIEL_CENTRAL/skills/$category_name/$item_name/" 2>/dev/null || true
        fi
      done
    done
    ok "Local skills synced to central store"
  fi
}

# ─── Claude Code Installer ───────────────────────────────────────────────────

install_claude_code() {
  local ciel_dir="$1"
  local project_root="${2:-$(pwd)}"
  local user_scope="${3:-false}"
  
  info "Installing Ciel for Claude Code..."
  
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  local plugin_dir="$HOME/.claude/plugins/ciel"
  local commands_dir="$HOME/.claude/commands"
  # Force clean install — remove old hooks to prevent stale files
  rm -rf "$plugin_dir"
  mkdir -p "$plugin_dir" "$plugin_dir/agents" "$commands_dir"
  
  # Sync local skills to central store (mode local uniquement)
  if [[ "$ciel_dir" != /tmp/* ]]; then
    sync_local_skills_to_central "$ciel_dir"
  fi
  
  # Install central resources FIRST
  [ ! -d "$CIEL_CENTRAL/skills" ] && install_central_resources || ok "Central resources exist"
  
  if [[ "$ciel_dir" == /tmp/* ]]; then
    info "Downloading Claude Code components..."
    
    # Hooks
    for hook in session-start.sh stop.sh pre-tool-write.sh post-tool-write.sh pre-compact.sh user-prompt-submit.sh memory-bootstrap.sh memory-engine.py session-version-check.sh pre-agent-gate.sh subagent-stop.sh; do
      curl -fsSL "$GITHUB_BASE/hooks/$hook" -o "$plugin_dir/$hook" 2>/dev/null && ok "Hook: $hook" || warn "Missing: $hook"
    done
    chmod +x "$plugin_dir"/*.sh "$plugin_dir"/memory-engine.py 2>/dev/null || true
    
    # Agents
    for agent in ciel ciel-researcher ciel-explorer ciel-critic ciel-improver; do
      curl -fsSL "$GITHUB_BASE/.opencode/agents/${agent}.md" -o "$plugin_dir/agents/${agent}.md" 2>/dev/null && ok "Agent: $agent" || true
    done
    
    # Commands (symlinks to central)
    for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-audit; do
      rm -f "$commands_dir/$cmd.md"
      ln -sf "$CIEL_CENTRAL/commands/$cmd.md" "$commands_dir/$cmd.md" && ok "Command: /$cmd" || warn "Command: $cmd"
    done
    
    create_skills_symlink "$plugin_dir"
  else
    cp -r "$ciel_dir/hooks/" "$plugin_dir/" 2>/dev/null || true
    cp -r "$ciel_dir/agents/" "$plugin_dir/" 2>/dev/null || true
    # Create command symlinks
    for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-audit; do
      rm -f "$commands_dir/$cmd.md"
      ln -sf "$CIEL_CENTRAL/commands/$cmd.md" "$commands_dir/$cmd.md" 2>/dev/null || true
    done
    create_skills_symlink "$plugin_dir" "$CIEL_CENTRAL/skills"
  fi
  
  # Configure settings
  local config_file
  [ "$user_scope" = "true" ] && config_file="$HOME/.claude/settings.json" || config_file="$project_root/.claude/settings.json"
  mkdir -p "$(dirname "$config_file")"
  [ -f "$config_file" ] && cp "$config_file" "${config_file}.bak-$(date +%Y%m%dT%H%M%S)"
  
  cat > "$config_file" << EOFCONFIG
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "true"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "true"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "true"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "true"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "true"
          }
        ]
      }
    ]
  }
}
EOFCONFIG
  
  ok "Configured Claude Code"
}

uninstall_claude_code() {
  rm -rf "$HOME/.claude/plugins/ciel"
  rm -f "$HOME/.claude/commands/ciel-"*.md
  ok "Uninstalled Claude Code"
}

# ─── OpenCode Installer ──────────────────────────────────────────────────────

install_opencode() {
  local ciel_dir="$1"
  local project_root="${2:-$(pwd)}"
  
  info "Installing Ciel for OpenCode..."
  
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  mkdir -p "$project_root/.opencode/plugins" "$project_root/.opencode/agents" "$project_root/.opencode/commands"
  
  # Sync local skills to central store (mode local uniquement)
  if [[ "$ciel_dir" != /tmp/* ]]; then
    sync_local_skills_to_central "$ciel_dir"
  fi
  
  # Install central resources FIRST
  [ ! -d "$CIEL_CENTRAL/skills" ] && install_central_resources || ok "Central resources exist"
  
  if [[ "$ciel_dir" == /tmp/* ]]; then
    info "Downloading OpenCode files..."
    
    # Plugin
    curl -fsSL "$GITHUB_BASE/.opencode/plugins/ciel.ts" -o "$project_root/.opencode/plugins/ciel.ts" && ok "Plugin" || err "Plugin failed"
    
    # Primary agents (ciel = merged plan+build)
    for agent in ciel ciel-researcher ciel-explorer ciel-critic ciel-improver; do
      curl -fsSL "$GITHUB_BASE/.opencode/agents/${agent}.md" -o "$project_root/.opencode/agents/${agent}.md" 2>/dev/null && ok "Agent: $agent" || true
    done
    
    # Note: OpenCode agents are already defined in .opencode/agents/ and configured in opencode.json
    # No subagents/ directory needed — avoids frontmatter format conflicts
    
    # Commands
    for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-audit; do
      curl -fsSL "$GITHUB_BASE/.opencode/commands/${cmd}.md" -o "$project_root/.opencode/commands/${cmd}.md" 2>/dev/null && ok "Command: $cmd" || true
    done
    
    create_skills_symlink "$project_root/.opencode" "$CIEL_CENTRAL/skills"
  else
    cp "$ciel_dir/.opencode/plugins/ciel.ts" "$project_root/.opencode/plugins/" && ok "Plugin copied"
    cp -r "$ciel_dir/.opencode/agents/" "$project_root/.opencode/agents/" 2>/dev/null || true
    cp -r "$ciel_dir/.opencode/commands/" "$project_root/.opencode/commands/" 2>/dev/null || true
    create_skills_symlink "$project_root/.opencode" "$CIEL_CENTRAL/skills"
  fi
  
  # Update opencode.json
  local config_file="$project_root/opencode.json"
  [ -f "$config_file" ] && cp "$config_file" "${config_file}.bak-$(date +%Y%m%dT%H%M%S)"

  if [ -f "$config_file" ]; then
    # Check if old wrong key "plugins" exists (needs migration)
    if grep -q '"plugins"' "$config_file" 2>/dev/null; then
      local tmp_config
      tmp_config=$(mktemp)
      # Migrate: rename "plugins" → "plugin" and fix path
      jq 'with_entries(if .key == "plugins" then .key = "plugin" else . end) | .plugin = ((.plugin // []) + ["./.opencode/plugins/ciel.ts"] | unique)' "$config_file" > "$tmp_config" && mv "$tmp_config" "$config_file"
      ok "Migrated opencode.json: plugins → plugin"
    elif ! grep -q '"plugin"' "$config_file" 2>/dev/null || ! grep -q "ciel" "$config_file" 2>/dev/null; then
      local tmp_config
      tmp_config=$(mktemp)
      jq '.plugin = ((.plugin // []) + ["./.opencode/plugins/ciel.ts"] | unique)' "$config_file" > "$tmp_config" && mv "$tmp_config" "$config_file"
      ok "Updated opencode.json"
    fi
    # Suggest the recommended permission template for users without one.
    if ! grep -q '"permission"' "$config_file" 2>/dev/null; then
      echo "TIP: opencode.json has no \"permission\" block. The Ciel-recommended"
      echo "     template (allow * + deny/ask on destructive ops) is at:"
      echo "       $ciel_dir/platforms/opencode/opencode.json.template"
      echo "     Copy its \"permission\" block into your opencode.json to reduce"
      echo "     permission prompts while keeping foot-guns guarded."
    fi
  else
    # Fresh install: copy the recommended template so users get sensible
    # defaults (allow * + deny/ask on destructive ops). See ADR/SKILL.md.
    local template
    if [[ "$ciel_dir" == /tmp/* ]]; then
      curl -fsSL "$GITHUB_BASE/platforms/opencode/opencode.json.template" -o "$config_file" 2>/dev/null
    else
      template="$ciel_dir/platforms/opencode/opencode.json.template"
      if [ -f "$template" ]; then
        cp "$template" "$config_file"
      else
        echo '{"plugin": ["./.opencode/plugins/ciel.ts"]}' > "$config_file"
      fi
    fi
    [ -f "$config_file" ] && ok "Created opencode.json (with recommended permission block)" || warn "opencode.json fallback minimal"
  fi
}

uninstall_opencode() {
  local project_root="${1:-$(pwd)}"
  rm -f "$project_root/.opencode/plugins/ciel.ts"
  rm -rf "$project_root/.opencode/agents" "$project_root/.opencode/commands" "$project_root/.opencode/skills"
  ok "Uninstalled OpenCode"
}

# ─── Generic Platform Installer ──────────────────────────────────────────────

install_generic() {
  local platform="$1"
  local ciel_dir="$2"
  local project_root="${3:-$(pwd)}"
  
  local platform_name rules_file platform_dir
  case "$platform" in
    cursor) platform_name="Cursor"; rules_file="ciel.mdc"; platform_dir="$project_root/.cursor" ;;
    windsurf) platform_name="Windsurf"; rules_file="ciel.md"; platform_dir="$project_root/.windsurf" ;;
    codex) platform_name="Codex"; rules_file="AGENTS.md"; platform_dir="$project_root/.codex" ;;
    kilocode) platform_name="KiloCode"; rules_file="ciel.md"; platform_dir="$project_root/.kilocode" ;;
    *) platform_name="$platform"; rules_file="ciel.md"; platform_dir="$project_root/.${platform}" ;;
  esac
  
  info "Installing Ciel for $platform_name..."
  
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  mkdir -p "$platform_dir/rules" "$platform_dir/agents" "$platform_dir/commands"
  
  # Sync local skills to central store (mode local uniquement)
  if [[ "$ciel_dir" != /tmp/* ]]; then
    sync_local_skills_to_central "$ciel_dir"
  fi
  
  [ ! -d "$CIEL_CENTRAL/skills" ] && install_central_resources || ok "Central resources exist"
  
  if [[ "$ciel_dir" == /tmp/* ]]; then
    curl -fsSL "$GITHUB_BASE/platforms/$platform/$rules_file" -o "$platform_dir/rules/$rules_file" 2>/dev/null && ok "Rules: $rules_file" || \
    curl -fsSL "$GITHUB_BASE/platforms/$platform/ciel.md" -o "$platform_dir/rules/ciel.md" 2>/dev/null && ok "Rules: ciel.md" || warn "Rules failed"
    
    # Primary agent (ciel = merged plan+build)
    for agent in ciel ciel-researcher ciel-explorer ciel-critic ciel-improver; do
      curl -fsSL "$GITHUB_BASE/agents/${agent}.md" -o "$platform_dir/agents/${agent}.md" 2>/dev/null || true
    done
    
    for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-audit; do
      curl -fsSL "$GITHUB_BASE/commands/${cmd}.md" -o "$platform_dir/commands/${cmd}.md" 2>/dev/null || true
    done
    
    create_skills_symlink "$platform_dir" "$CIEL_CENTRAL/skills"
  else
    cp "$ciel_dir/platforms/$platform/$rules_file" "$platform_dir/rules/" 2>/dev/null && ok "Installed: $rules_file" || \
    cp "$ciel_dir/platforms/$platform/ciel.md" "$platform_dir/rules/ciel.md" 2>/dev/null && ok "Installed: ciel.md" || warn "Copy failed"
    cp -r "$ciel_dir/agents/" "$platform_dir/agents/" 2>/dev/null || true
    cp -r "$ciel_dir/commands/" "$platform_dir/commands/" 2>/dev/null || true
    create_skills_symlink "$platform_dir" "$CIEL_CENTRAL/skills"
  fi
}
