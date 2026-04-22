#!/usr/bin/env bash
# Ciel — Platform Installers Library
# Skills are UNIVERSAL - installed for ALL platforms

set -euo pipefail

# ─── Universal Skills Installer (shared by all platforms) ────────────────────

install_universal_skills() {
  local target_dir="$1"
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  
  mkdir -p "$target_dir/skills/ciel-critic" "$target_dir/skills/workflow" "$target_dir/skills/research" "$target_dir/skills/security" "$target_dir/skills/domain" "$target_dir/skills/meta" "$target_dir/skills/utility"
  
  # ciel-critic skills
  for skill in relire-critic critiquer-auditor stride-analyzer security-regression-check debug-reasoning-rca self-consistency-verifier; do
    curl -fsSL "$GITHUB_BASE/skills/ciel-critic/${skill}.md" -o "$target_dir/skills/ciel-critic/${skill}.md" 2>/dev/null || true
  done
  
  # workflow skills
  for skill in depth-classifier quoi-framer avec-quoi-versioner flux-narrator evaluer-sizer faire-gatekeeper prouver-verifier synthesize-findings; do
    curl -fsSL "$GITHUB_BASE/skills/workflow/${skill}.md" -o "$target_dir/skills/workflow/${skill}.md" 2>/dev/null || true
  done
  
  # research skills
  for skill in doc-validator-official validate-source-credibility research-web-sources research-github-issues research-forums; do
    curl -fsSL "$GITHUB_BASE/skills/research/${skill}.md" -o "$target_dir/skills/research/${skill}.md" 2>/dev/null || true
  done
  
  # security skills
  for skill in security-hardening ai-failure-modes-detector modern-patterns-checker pattern-fitness-check; do
    curl -fsSL "$GITHUB_BASE/skills/security/${skill}.md" -o "$target_dir/skills/security/${skill}.md" 2>/dev/null || true
  done
  
  # domain skills
  for skill in frontend-mastery backend-mastery database-mastery api-architecture observability performance-engineering; do
    curl -fsSL "$GITHUB_BASE/skills/domain/${skill}.md" -o "$target_dir/skills/domain/${skill}.md" 2>/dev/null || true
  done
  
  # meta skills
  for skill in learnings-capture meta-critiquer skill-creator skill-freshness-auditor skill-variant-evaluator skills-first-design-auditor; do
    curl -fsSL "$GITHUB_BASE/skills/meta/${skill}.md" -o "$target_dir/skills/meta/${skill}.md" 2>/dev/null || true
  done
  
  # utility skills
  for skill in fact-check-claims refactoring-patterns test-strategy-vitest-playwright branch-setup branch-cleaner commit-writer pr-body-generator pr-opener pr-merger pr-review-responder issue-creator issue-closer release-publisher changelog-updater ci-watcher cicd-pipeline-designer cicd-security-hardener staging-verifier playwright-visual-critic accessibility-wcag-auditor avec-quoi-versioner; do
    curl -fsSL "$GITHUB_BASE/skills/utility/${skill}.md" -o "$target_dir/skills/utility/${skill}.md" 2>/dev/null || true
  done
}

# ─── Claude Code Installer ───────────────────────────────────────────────────

install_claude_code() {
  local ciel_dir="$1"
  local project_root="${2:-$(pwd)}"
  local user_scope="${3:-false}"
  
  info "Installing Ciel for Claude Code..."
  
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  local plugin_dir="$HOME/.claude/plugins/ciel"
  mkdir -p "$plugin_dir" "$plugin_dir/agents" "$plugin_dir/commands"
  
  if [[ "$ciel_dir" == /tmp/* ]]; then
    info "Downloading Ciel components from GitHub..."
    
    # Download hooks
    for hook in session-start.sh stop.sh pre-tool-write.sh post-tool-write.sh pre-compact.sh; do
      curl -fsSL "$GITHUB_BASE/hooks/$hook" -o "$plugin_dir/$hook" 2>/dev/null && ok "Hook: $hook" || warn "Missing: $hook"
    done
    
    # Download agents
    for agent in ciel-plan ciel-build ciel-researcher ciel-explorer ciel-critic ciel-improver; do
      curl -fsSL "$GITHUB_BASE/agents/${agent}.md" -o "$plugin_dir/agents/${agent}.md" 2>/dev/null && ok "Agent: $agent" || true
    done
    
    # Download commands
    for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-recommend ciel-audit; do
      curl -fsSL "$GITHUB_BASE/commands/${cmd}.md" -o "$plugin_dir/commands/${cmd}.md" 2>/dev/null && ok "Command: $cmd" || true
    done
    
    # Download UNIVERSAL skills
    info "Installing universal skills..."
    install_universal_skills "$plugin_dir"
    ok "Skills installed"
    
  else
    cp -r "$ciel_dir/hooks/" "$plugin_dir/" 2>/dev/null || true
    cp -r "$ciel_dir/agents/" "$plugin_dir/" 2>/dev/null || true
    cp -r "$ciel_dir/commands/" "$plugin_dir/" 2>/dev/null || true
    cp -r "$ciel_dir/skills/" "$plugin_dir/" 2>/dev/null || true
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
    "SessionStart": {"command": "bash", "args": ["~/.claude/plugins/ciel/session-start.sh"]},
    "Stop": {"command": "bash", "args": ["~/.claude/plugins/ciel/stop.sh"]},
    "PreToolWrite": {"command": "bash", "args": ["~/.claude/plugins/ciel/pre-tool-write.sh"]},
    "PostToolWrite": {"command": "bash", "args": ["~/.claude/plugins/ciel/post-tool-write.sh"]},
    "PreCompact": {"command": "bash", "args": ["~/.claude/plugins/ciel/pre-compact.sh"]}
  }
}
EOFCONFIG
  
  ok "Configured Claude Code hooks"
}

uninstall_claude_code() {
  rm -rf "$HOME/.claude/plugins/ciel"
  ok "Uninstalled Claude Code components"
}

# ─── OpenCode Installer ──────────────────────────────────────────────────────

install_opencode() {
  local ciel_dir="$1"
  local project_root="${2:-$(pwd)}"
  
  info "Installing Ciel for OpenCode..."
  
  local GITHUB_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main"
  mkdir -p "$project_root/.opencode/plugins" "$project_root/.opencode/agents" "$project_root/.opencode/commands"
  
  if [[ "$ciel_dir" == /tmp/* ]]; then
    info "Downloading OpenCode files from GitHub..."
    
    # Download plugin
    curl -fsSL "$GITHUB_BASE/.opencode/plugins/ciel.ts" -o "$project_root/.opencode/plugins/ciel.ts" && ok "Plugin" || err "Failed to download plugin"
    
    # Download agents
    for agent in ciel-plan ciel-build ciel-researcher ciel-explorer ciel-critic ciel-improver; do
      curl -fsSL "$GITHUB_BASE/.opencode/agents/${agent}.md" -o "$project_root/.opencode/agents/${agent}.md" 2>/dev/null && ok "Agent: $agent" || true
    done
    
    # Download commands
    for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-recommend ciel-audit; do
      curl -fsSL "$GITHUB_BASE/.opencode/commands/${cmd}.md" -o "$project_root/.opencode/commands/${cmd}.md" 2>/dev/null && ok "Command: $cmd" || true
    done
    
    # Download UNIVERSAL skills
    info "Installing universal skills..."
    install_universal_skills "$project_root/.opencode"
    ok "Skills installed"
    
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

# ─── Generic Platform Installer (Cursor, Windsurf, etc.) ─────────────────────

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
  local target_dir rules_file skills_dir
  
  case "$platform" in
    cursor) target_dir="$project_root/.cursor/rules"; rules_file="ciel.mdc"; skills_dir="$project_root/.cursor/skills" ;;
    windsurf) target_dir="$project_root/.windsurf/rules"; rules_file="ciel.md"; skills_dir="$project_root/.windsurf/skills" ;;
    codex) target_dir="$project_root/.codex"; rules_file="AGENTS.md"; skills_dir="$project_root/.codex/skills" ;;
    kilocode) target_dir="$project_root/.kilocode/rules"; rules_file="ciel.md"; skills_dir="$project_root/.kilocode/skills" ;;
    *) target_dir="$project_root/.${platform}/rules"; rules_file="ciel.md"; skills_dir="$project_root/.${platform}/skills" ;;
  esac
  
  mkdir -p "$target_dir"
  
  if [[ "$ciel_dir" == /tmp/* ]]; then
    # Download rules file
    if curl -fsSL "$GITHUB_BASE/platforms/$platform/$rules_file" -o "$target_dir/$rules_file" 2>/dev/null; then
      ok "Installed rules: $rules_file"
    else
      curl -fsSL "$GITHUB_BASE/platforms/$platform/ciel.md" -o "$target_dir/ciel.md" 2>/dev/null && ok "Installed: ciel.md" || warn "Download failed"
    fi
    
    # Download UNIVERSAL skills
    info "Installing universal skills..."
    install_universal_skills "$skills_dir"
    ok "Skills installed"
  else
    cp "$ciel_dir/platforms/$platform/$rules_file" "$target_dir/" 2>/dev/null && ok "Installed: $rules_file" || \
    cp "$ciel_dir/platforms/$platform/ciel.md" "$target_dir/ciel.md" 2>/dev/null && ok "Installed: ciel.md" || warn "Copy failed"
    cp -r "$ciel_dir/skills/" "$skills_dir/" 2>/dev/null || true
  fi
}
