#!/usr/bin/env bash
# Ciel Universal Installer — Claude Code + OpenCode
# Usage: bash install.sh [flags]
#        bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh) [flags]
#
# Flags:
#   --check-update      Query GitHub for newer VERSION and report
#   --update            Uninstall old + re-install latest from main
#   --uninstall         Remove all Ciel files tracked in ~/.ciel/manifest.json
#   --platform=NAME     Skip auto-detection (claude | opencode)
#   -y, --yes           Skip interactive confirmations

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
info() { echo -e "  ${CYAN}➜${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }
err()  { echo -e "  ${RED}✗${RESET} $1" >&2; }

CIEL_CENTRAL="$HOME/.ciel"
MANIFEST="$CIEL_CENTRAL/manifest.json"
GITHUB_RAW="https://raw.githubusercontent.com/KaosKyun/Ciel/main"

# ─── Library Bootstrap ───────────────────────────────────────────────────────

CURL_MODE=false
if [[ "${BASH_SOURCE[0]}" == /dev/fd/* ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]; then
  CURL_MODE=true
  TEMP_LIB_DIR=$(mktemp -d)
  SCRIPT_DIR="$TEMP_LIB_DIR"
  CIEL_DIR="$TEMP_LIB_DIR"
  LIB_URL_BASE="$GITHUB_RAW/scripts/lib"

  info "Downloading Ciel libraries..."

  mkdir -p "$TEMP_LIB_DIR/lib"
  curl -fsSL "$LIB_URL_BASE/platform.sh" -o "$TEMP_LIB_DIR/lib/platform.sh" || { err "Failed to download platform.sh"; rm -rf "$TEMP_LIB_DIR"; exit 1; }

  trap 'rm -rf "$TEMP_LIB_DIR"' EXIT
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CIEL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

source "$SCRIPT_DIR/lib/platform.sh"

# ─── Source Directory Resolution ─────────────────────────────────────────────
# In local mode, source files may be at CIEL_DIR/ (GitHub layout) or
# CIEL_DIR/Ciel/ (dev layout with subdirectory). Resolve to the correct path.

resolve_source() {
  local relative_path="$1"
  # Try direct path first (GitHub layout: hooks/, agents/, skills/ at root)
  if [ -e "$CIEL_DIR/$relative_path" ]; then
    echo "$CIEL_DIR/$relative_path"
  # Try Ciel/ subdirectory (dev layout: Ciel/hooks/, Ciel/skills/, etc.)
  elif [ -e "$CIEL_DIR/Ciel/$relative_path" ]; then
    echo "$CIEL_DIR/Ciel/$relative_path"
  else
    echo ""
  fi
}

# ─── Version Management ──────────────────────────────────────────────────────

get_local_version() {
  if [ "$CURL_MODE" = "true" ]; then
    curl -fsSL "$GITHUB_RAW/VERSION" 2>/dev/null | tr -d '[:space:]'
  else
    cat "$CIEL_DIR/VERSION" 2>/dev/null | tr -d '[:space:]'
  fi
}

get_remote_version() {
  curl -fsSL "$GITHUB_RAW/VERSION" 2>/dev/null | tr -d '[:space:]'
}

# ─── Semver Comparison ──────────────────────────────────────────────────────

semver_gt() {
  # Returns 0 if $1 > $2
  local IFS='.'
  read -ra V1 <<< "$1"
  read -ra V2 <<< "$2"
  for i in 0 1 2; do
    local a="${V1[$i]:-0}"
    local b="${V2[$i]:-0}"
    if (( a > b )); then return 0; fi
    if (( a < b )); then return 1; fi
  done
  return 1
}

# ─── Manifest Tracking ──────────────────────────────────────────────────────

manifest_init() {
  mkdir -p "$CIEL_CENTRAL"
  echo '{"version":"'"$(get_local_version)"'","installed_at":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","files":[]}' > "$MANIFEST"
}

manifest_add() {
  local file="$1"
  if [ -f "$MANIFEST" ]; then
    local tmp
    tmp=$(mktemp)
    jq --arg f "$file" '.files += [$f]' "$MANIFEST" > "$tmp" && mv "$tmp" "$MANIFEST"
  fi
}

# ─── Platform Detection ─────────────────────────────────────────────────────

detect_all_platforms() {
  local platforms=()
  local project_platforms_found=false

  # Project-level configs (primary detection)
  [ -f "./.claude/settings.json" ] || [ -f "./.claude/settings.local.json" ] && { platforms+=("claude"); project_platforms_found=true; }
  [ -f "./opencode.json" ] || [ -d "./.opencode" ] && { platforms+=("opencode"); project_platforms_found=true; }

  # User-level configs if no project-level found
  if [ "$project_platforms_found" = "false" ]; then
    [ -d "$HOME/.claude" ] && platforms+=("claude")
    [ -d "$HOME/.opencode" ] && platforms+=("opencode")
  fi

  # CLI availability as last resort
  if [ ${#platforms[@]} -eq 0 ]; then
    command -v claude &>/dev/null && platforms+=("claude")
    command -v opencode &>/dev/null && platforms+=("opencode")
  fi

  printf '%s\n' "${platforms[@]}" | sort -u
}

# ─── Central Resources ──────────────────────────────────────────────────────

install_central_resources() {
  info "Installing central Ciel resources to $CIEL_CENTRAL..."
  mkdir -p "$CIEL_CENTRAL/skills" "$CIEL_CENTRAL/commands"

  # Sync skills from source (local mode) or download (curl mode)
  local skills_src
  skills_src=$(resolve_source "skills")
  if [[ "$CIEL_DIR" != /tmp/* ]] && [ -n "$skills_src" ] && [ -d "$skills_src" ]; then
    cp -r "$skills_src/"* "$CIEL_CENTRAL/skills/" 2>/dev/null || true
    ok "Skills synced from local source"
  else
    # Download from GitHub — skill categories
    for category in ciel workflow research domain utility meta; do
      mkdir -p "$CIEL_CENTRAL/skills/$category"
      local items
      items=$(curl -fsSL "https://api.github.com/repos/KaosKyun/Ciel/contents/skills/$category" 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
      for item in $items; do
        # Check if it's a directory (skill folder) or file
        local type
        type=$(curl -fsSL "https://api.github.com/repos/KaosKyun/Ciel/contents/skills/$category/$item" 2>/dev/null | jq -r '.type' 2>/dev/null || echo "file")
        if [ "$type" = "dir" ]; then
          mkdir -p "$CIEL_CENTRAL/skills/$category/$item"
          # Download SKILL.md and reference.md if they exist
          curl -fsSL "$GITHUB_RAW/skills/$category/$item/SKILL.md" -o "$CIEL_CENTRAL/skills/$category/$item/SKILL.md" 2>/dev/null || true
          curl -fsSL "$GITHUB_RAW/skills/$category/$item/reference.md" -o "$CIEL_CENTRAL/skills/$category/$item/reference.md" 2>/dev/null || true
        else
          curl -fsSL "$GITHUB_RAW/skills/$category/$item" -o "$CIEL_CENTRAL/skills/$category/$item" 2>/dev/null || true
        fi
      done
    done
    ok "Skills downloaded from GitHub"
  fi

  # Commands
  local cmds_src
  cmds_src=$(resolve_source "commands")
  for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-recommend ciel-audit; do
    if [[ "$CIEL_DIR" != /tmp/* ]] && [ -n "$cmds_src" ] && [ -f "$cmds_src/${cmd}.md" ]; then
      cp "$cmds_src/${cmd}.md" "$CIEL_CENTRAL/commands/${cmd}.md"
    else
      curl -fsSL "$GITHUB_RAW/commands/${cmd}.md" -o "$CIEL_CENTRAL/commands/${cmd}.md" 2>/dev/null || true
    fi
    [ -f "$CIEL_CENTRAL/commands/${cmd}.md" ] && ok "Command: /$cmd" || true
  done

  ok "Central resources installed"
}

# ─── Claude Code Installer ──────────────────────────────────────────────────

install_claude_code() {
  local project_root="${1:-$(pwd)}"

  info "Installing Ciel for Claude Code..."

  local plugin_dir="$HOME/.claude/plugins/ciel"
  local commands_dir="$HOME/.claude/commands"

  # Clean install
  rm -rf "$plugin_dir"
  mkdir -p "$plugin_dir/hooks" "$plugin_dir/agents" "$commands_dir"

  # Ensure central resources
  [ ! -d "$CIEL_CENTRAL/skills" ] && install_central_resources || ok "Central resources exist"

  # Install hooks into hooks/ subdirectory
  local hooks_src
  hooks_src=$(resolve_source "hooks")
  if [[ "$CIEL_DIR" != /tmp/* ]] && [ -n "$hooks_src" ] && [ -d "$hooks_src" ]; then
    cp "$hooks_src/"*.sh "$plugin_dir/hooks/" 2>/dev/null || true
    cp "$hooks_src/"*.ps1 "$plugin_dir/hooks/" 2>/dev/null || true
  else
    for hook in session-start.sh user-prompt-submit.sh pre-tool-write.sh post-tool-write.sh pre-compact.sh subagent-stop.sh stop.sh pre-agent-gate.sh; do
      curl -fsSL "$GITHUB_RAW/Ciel/hooks/$hook" -o "$plugin_dir/hooks/$hook" 2>/dev/null || true
    done
    for hook in session-start.ps1 user-prompt-submit.ps1 pre-tool-write.ps1 post-tool-write.ps1 pre-compact.ps1 subagent-stop.ps1 stop.ps1; do
      curl -fsSL "$GITHUB_RAW/Ciel/hooks/$hook" -o "$plugin_dir/hooks/$hook" 2>/dev/null || true
    done
  fi
  chmod +x "$plugin_dir/hooks/"*.sh 2>/dev/null || true
  ok "Hooks installed (7 events)"

  # Install agents
  local agents_src
  agents_src=$(resolve_source "agents")
  if [[ "$CIEL_DIR" != /tmp/* ]] && [ -n "$agents_src" ] && [ -d "$agents_src" ]; then
    cp "$agents_src/"*.md "$plugin_dir/agents/" 2>/dev/null || true
  else
    for agent in researcher explorer critic improver; do
      curl -fsSL "$GITHUB_RAW/Ciel/agents/$agent.md" -o "$plugin_dir/agents/$agent.md" 2>/dev/null || true
    done
  fi
  ok "Agents installed"

  # Symlink skills
  ln -sf "$CIEL_CENTRAL/skills" "$plugin_dir/skills"
  ok "Skills symlinked"

  # Install commands as symlinks
  for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-recommend ciel-audit; do
    rm -f "$commands_dir/$cmd.md"
    ln -sf "$CIEL_CENTRAL/commands/$cmd.md" "$commands_dir/$cmd.md" 2>/dev/null || true
  done
  ok "Commands installed"

  # Generate settings.json with correct hook paths
  local settings_file="$project_root/.claude/settings.json"
  mkdir -p "$(dirname "$settings_file")"
  [ -f "$settings_file" ] && cp "$settings_file" "${settings_file}.bak-$(date +%Y%m%dT%H%M%S)"

  cat > "$settings_file" << 'EOFSETTINGS'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash __CIEL_PLUGIN_HOME__/hooks/session-start.sh",
            "statusMessage": "Ciel: session starting..."
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash __CIEL_PLUGIN_HOME__/hooks/user-prompt-submit.sh",
            "statusMessage": "Ciel: classifying depth..."
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash __CIEL_PLUGIN_HOME__/hooks/pre-tool-write.sh",
            "statusMessage": "Ciel: FLUX check..."
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash __CIEL_PLUGIN_HOME__/hooks/post-tool-write.sh",
            "statusMessage": "Ciel: RELIRE dispatch..."
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash __CIEL_PLUGIN_HOME__/hooks/stop.sh",
            "statusMessage": "Ciel: META-CRITIQUER..."
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash __CIEL_PLUGIN_HOME__/hooks/subagent-stop.sh",
            "statusMessage": "Ciel: agent report size log..."
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash __CIEL_PLUGIN_HOME__/hooks/pre-compact.sh",
            "statusMessage": "Ciel: session progress save..."
          }
        ]
      }
    ]
  }
}
EOFSETTINGS

  # Replace placeholder with actual path
  sed -i '' "s|__CIEL_PLUGIN_HOME__|$plugin_dir|g" "$settings_file"
  ok "Settings configured (7 hooks wired)"

  # Track in manifest
  manifest_add "$plugin_dir"
  manifest_add "$settings_file"
}

# ─── OpenCode Installer ─────────────────────────────────────────────────────

install_opencode() {
  local project_root="${1:-$(pwd)}"

  info "Installing Ciel for OpenCode..."

  mkdir -p "$project_root/.opencode/plugins" "$project_root/.opencode/agents" "$project_root/.opencode/commands"

  # Ensure central resources
  [ ! -d "$CIEL_CENTRAL/skills" ] && install_central_resources || ok "Central resources exist"

  # Plugin TS file — try .opencode/plugins/ first, then platforms/opencode/
  local plugin_src
  plugin_src=$(resolve_source ".opencode/plugins/ciel.ts")
  if [[ "$CIEL_DIR" != /tmp/* ]] && [ -n "$plugin_src" ] && [ -f "$plugin_src" ]; then
    cp "$plugin_src" "$project_root/.opencode/plugins/"
  elif [[ "$CIEL_DIR" != /tmp/* ]] && [ -f "$CIEL_DIR/platforms/opencode/.opencode/plugins/ciel.ts" ]; then
    cp "$CIEL_DIR/platforms/opencode/.opencode/plugins/ciel.ts" "$project_root/.opencode/plugins/"
  else
    curl -fsSL "$GITHUB_RAW/.opencode/plugins/ciel.ts" -o "$project_root/.opencode/plugins/ciel.ts" 2>/dev/null
  fi
  ok "Plugin installed"

  # Agents — try .opencode/agents/ first, then platforms/opencode/
  local agents_src
  agents_src=$(resolve_source ".opencode/agents")
  if [[ "$CIEL_DIR" != /tmp/* ]] && [ -n "$agents_src" ] && [ -d "$agents_src" ]; then
    cp "$agents_src/"*.md "$project_root/.opencode/agents/" 2>/dev/null || true
  elif [[ "$CIEL_DIR" != /tmp/* ]] && [ -d "$CIEL_DIR/platforms/opencode/.opencode/agents" ]; then
    cp "$CIEL_DIR/platforms/opencode/.opencode/agents/"*.md "$project_root/.opencode/agents/" 2>/dev/null || true
  else
    for agent in ciel ciel-researcher ciel-explorer ciel-critic ciel-improver; do
      curl -fsSL "$GITHUB_RAW/.opencode/agents/${agent}.md" -o "$project_root/.opencode/agents/${agent}.md" 2>/dev/null || true
    done
  fi
  ok "Agents installed"

  # Commands — try .opencode/commands/ first, then platforms/opencode/
  local cmds_src
  cmds_src=$(resolve_source ".opencode/commands")
  if [[ "$CIEL_DIR" != /tmp/* ]] && [ -n "$cmds_src" ] && [ -d "$cmds_src" ]; then
    cp "$cmds_src/"*.md "$project_root/.opencode/commands/" 2>/dev/null || true
  elif [[ "$CIEL_DIR" != /tmp/* ]] && [ -d "$CIEL_DIR/platforms/opencode/.opencode/commands" ]; then
    cp "$CIEL_DIR/platforms/opencode/.opencode/commands/"*.md "$project_root/.opencode/commands/" 2>/dev/null || true
  else
    for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-recommend ciel-audit; do
      curl -fsSL "$GITHUB_RAW/.opencode/commands/${cmd}.md" -o "$project_root/.opencode/commands/${cmd}.md" 2>/dev/null || true
    done
  fi
  ok "Commands installed"

  # AGENTS.md — required for OpenCode
  if [ ! -f "$project_root/AGENTS.md" ]; then
    if [[ "$CIEL_DIR" != /tmp/* ]] && [ -f "$CIEL_DIR/platforms/opencode/AGENTS.md" ]; then
      cp "$CIEL_DIR/platforms/opencode/AGENTS.md" "$project_root/AGENTS.md"
    elif [[ "$CIEL_DIR" != /tmp/* ]] && [ -f "$CIEL_DIR/Ciel/platforms/opencode/AGENTS.md" ]; then
      cp "$CIEL_DIR/Ciel/platforms/opencode/AGENTS.md" "$project_root/AGENTS.md"
    else
      curl -fsSL "$GITHUB_RAW/platforms/opencode/AGENTS.md" -o "$project_root/AGENTS.md" 2>/dev/null || true
    fi
    [ -f "$project_root/AGENTS.md" ] && ok "AGENTS.md created" || warn "AGENTS.md not found"
  else
    ok "AGENTS.md already exists"
  fi

  # Symlink skills
  ln -sf "$CIEL_CENTRAL/skills" "$project_root/.opencode/skills"
  ok "Skills symlinked"

  # Update opencode.json — merge Ciel config non-destructively
  local config_file="$project_root/opencode.json"
  [ -f "$config_file" ] && cp "$config_file" "${config_file}.bak-$(date +%Y%m%dT%H%M%S)"

  # Use Python for reliable JSON merge (same approach as /ciel-init)
  python3 - "$config_file" <<'PYEOF'
import json, os, sys

target = sys.argv[1]
current = {}
if os.path.exists(target):
    try:
        with open(target) as f:
            current = json.load(f)
    except json.JSONDecodeError:
        print(f"WARNING: {target} has invalid JSON, creating fresh")
        current = {}

# $schema
current.setdefault("$schema", "https://opencode.ai/config.json")

# instructions: ensure array containing "AGENTS.md"
ins = current.get("instructions")
if ins is None:
    current["instructions"] = ["AGENTS.md"]
elif isinstance(ins, str):
    current["instructions"] = [ins] if ins == "AGENTS.md" else [ins, "AGENTS.md"]
elif isinstance(ins, list) and "AGENTS.md" not in ins:
    current["instructions"] = ins + ["AGENTS.md"]

# plugin: ensure array containing ciel.ts
target_plugin = "./.opencode/plugins/ciel.ts"
plg = current.get("plugin")
if plg is None:
    current["plugin"] = [target_plugin]
elif isinstance(plg, str):
    current["plugin"] = [plg] if plg == target_plugin else [plg, target_plugin]
elif isinstance(plg, list) and target_plugin not in plg:
    current["plugin"] = plg + [target_plugin]

# Migrate old "plugins" key if present
if "plugins" in current and "plugin" not in current:
    current["plugin"] = current.pop("plugins")
    if isinstance(current["plugin"], str):
        current["plugin"] = [current["plugin"]]

# agent definitions: add Ciel agents if not present
if "agent" not in current:
    current["agent"] = {}

ciel_agents = {
    "ciel": {
        "description": "Ciel — Primary orchestrator. Full pipeline: QUOI → AVEC QUOI → RECHERCHE → CODEBASE → FAIRE → RELIRE → PROUVER.",
        "mode": "primary",
        "prompt": "{file:./.opencode/agents/ciel.md}",
        "temperature": 0.7
    },
    "ciel-researcher": {
        "description": "RECHERCHE — docs officielles, anti-patterns. WebFetch + WebSearch.",
        "mode": "subagent",
        "prompt": "{file:./.opencode/agents/ciel-researcher.md}",
        "temperature": 0.1
    },
    "ciel-explorer": {
        "description": "CODEBASE + FLUX — pattern-fitness, flux-narrator. Read-only.",
        "mode": "subagent",
        "prompt": "{file:./.opencode/agents/ciel-explorer.md}",
        "temperature": 0.1
    },
    "ciel-critic": {
        "description": "RELIRE/CRITIQUER/RCA — hostile review. Bash allowed.",
        "mode": "subagent",
        "prompt": "{file:./.opencode/agents/ciel-critic.md}",
        "temperature": 0.1
    },
    "ciel-improver": {
        "description": "Meta-amélioration Ciel — analyse sessions, skill patches.",
        "mode": "subagent",
        "prompt": "{file:./.opencode/agents/ciel-improver.md}",
        "temperature": 0.1
    }
}

for name, defn in ciel_agents.items():
    if name not in current["agent"]:
        current["agent"][name] = defn

with open(target, "w") as f:
    json.dump(current, f, indent=2)
    f.write("\n")
PYEOF

  if python3 -m json.tool "$config_file" > /dev/null 2>&1; then
    ok "opencode.json configured (schema + plugin + instructions + agents)"
  else
    err "opencode.json validation failed"
  fi

  manifest_add "$project_root/.opencode"
}

# ─── Uninstall ──────────────────────────────────────────────────────────────

do_uninstall() {
  info "Uninstalling Ciel..."

  # Claude Code
  if [ -d "$HOME/.claude/plugins/ciel" ]; then
    rm -rf "$HOME/.claude/plugins/ciel"
    ok "Removed Claude Code plugin"
  fi
  rm -f "$HOME/.claude/commands/ciel-"*.md 2>/dev/null || true
  ok "Removed Claude Code commands"

  # OpenCode (current project)
  if [ -d "./.opencode/plugins/ciel.ts" ] || [ -f "./.opencode/plugins/ciel.ts" ]; then
    rm -f "./.opencode/plugins/ciel.ts"
    rm -rf "./.opencode/agents" "./.opencode/commands" "./.opencode/skills"
    ok "Removed OpenCode plugin (current project)"
  fi

  # Central store
  if [ -d "$CIEL_CENTRAL" ]; then
    rm -rf "$CIEL_CENTRAL"
    ok "Removed central store ($CIEL_CENTRAL)"
  fi

  ok "Ciel uninstalled"
}

# ─── Check Update ───────────────────────────────────────────────────────────

do_check_update() {
  local local_ver
  local_ver=$(get_local_version 2>/dev/null || echo "unknown")
  local remote_ver
  remote_ver=$(get_remote_version 2>/dev/null || echo "unknown")

  if [ "$remote_ver" = "unknown" ]; then
    err "Could not fetch remote version from GitHub"
    exit 1
  fi

  echo ""
  echo "  Local:  v$local_ver"
  echo "  Remote: v$remote_ver"

  if [ "$local_ver" = "$remote_ver" ]; then
    ok "Up to date!"
  elif semver_gt "$remote_ver" "$local_ver"; then
    warn "Update available: v$local_ver → v$remote_ver"
    echo "  Run: bash install.sh --update"
  else
    ok "Local version is newer or equal"
  fi
  echo ""
}

# ─── Update ─────────────────────────────────────────────────────────────────

do_update() {
  info "Updating Ciel..."
  do_uninstall
  # Re-install with same logic
  main_install
}

# ─── Main Install ───────────────────────────────────────────────────────────

main_install() {
  local platform_override="${1:-}"

  echo ""
  echo "╔═══════════════════════════════════════╗"
  echo "║   Ciel Installer v$(get_local_version 2>/dev/null || echo '?')               ║"
  echo "╚═══════════════════════════════════════╝"
  echo ""

  # Init manifest
  manifest_init

  # Ensure central resources
  install_central_resources
  echo ""

  if [ -n "$platform_override" ]; then
    case "$platform_override" in
      claude) install_claude_code "$(pwd)" ;;
      opencode) install_opencode "$(pwd)" ;;
      *) err "Unknown platform: $platform_override"; exit 1 ;;
    esac
  else
    info "Detecting installed platforms..."
    local platforms=()
    while IFS= read -r platform; do
      [ -n "$platform" ] && platforms+=("$platform")
    done < <(detect_all_platforms)

    if [ ${#platforms[@]} -eq 0 ]; then
      err "No supported platforms detected"
      echo ""
      echo "Supported: Claude Code, OpenCode"
      echo "Force: bash install.sh --platform=claude"
      exit 1
    fi

    info "Detected: ${platforms[*]}"
    echo ""

    for platform in "${platforms[@]}"; do
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      case "$platform" in
        claude) install_claude_code "$(pwd)" ;;
        opencode) install_opencode "$(pwd)" ;;
      esac
      echo ""
    done
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ok "Installation complete!"
  echo ""
  echo "Next steps:"
  echo "  - Claude Code: Restart Claude, hooks auto-load"
  echo "  - OpenCode: Restart OpenCode, plugin auto-loads"
  echo ""
}

# ─── Argument Parsing ───────────────────────────────────────────────────────

ACTION="install"
PLATFORM_OVERRIDE=""
SKIP_CONFIRM=false

for arg in "$@"; do
  case "$arg" in
    --check-update) ACTION="check-update" ;;
    --update) ACTION="update" ;;
    --uninstall) ACTION="uninstall" ;;
    --platform=*) PLATFORM_OVERRIDE="${arg#--platform=}" ;;
    -y|--yes) SKIP_CONFIRM=true ;;
    --help|-h)
      echo "Ciel Installer v$(get_local_version 2>/dev/null || echo '?')"
      echo ""
      echo "Usage: bash install.sh [flags]"
      echo ""
      echo "Flags:"
      echo "  --check-update      Check for newer version on GitHub"
      echo "  --update            Uninstall + re-install latest"
      echo "  --uninstall         Remove all Ciel files"
      echo "  --platform=NAME     Force platform (claude | opencode)"
      echo "  -y, --yes           Skip confirmations"
      exit 0
      ;;
    *)
      # Treat positional arg as project root
      if [ -d "$arg" ]; then
        cd "$arg"
      fi
      ;;
  esac
done

case "$ACTION" in
  check-update) do_check_update ;;
  update) do_update ;;
  uninstall) do_uninstall ;;
  install) main_install "$PLATFORM_OVERRIDE" ;;
esac
