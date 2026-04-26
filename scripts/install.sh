#!/usr/bin/env bash
# Ciel v5 — Universal Installer
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
#        bash install.sh              # local clone
#        bash install.sh --update     # force reinstall
#        bash install.sh --uninstall  # remove everything
#
# Principle: one command, zero config. Auto-detects OpenCode or Claude Code.
# The install is idempotent -- safe to re-run.

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'
CHECK="\xE2\x9C\x93"
CROSS="\xE2\x9C\x97"

ok()   { echo -e "  ${GREEN}${CHECK}${RESET} $1"; }
info() { echo -e "  ${CYAN}->${RESET} $1"; }
warn() { echo -e "  ${YELLOW}~${RESET} $1"; }
err()  { echo -e "  ${RED}${CROSS}${RESET} $1" >&2; }

GITHUB_RAW="https://raw.githubusercontent.com/KaosKyun/Ciel/main"

# --- Parse flags ---
DO_UNINSTALL=false
DO_UPDATE=false
CIEL_VERSION="5.0.0"

for arg in "$@"; do
  case "$arg" in
    --uninstall) DO_UNINSTALL=true ;;
    --update)    DO_UPDATE=true ;;
  esac
done

# --- Detect install mode ---
if [[ "${BASH_SOURCE[0]}" == /dev/fd/* ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]; then
  CURL_MODE=true
  TMP_DIR=$(mktemp -d)
  SRC_DIR="$TMP_DIR"
  trap 'rm -rf "$TMP_DIR"' EXIT
  info "Downloading Ciel v${CIEL_VERSION}..."
  curl -fsSL "$GITHUB_RAW/VERSION" -o /dev/null 2>/dev/null || true
else
  CURL_MODE=false
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# --- Uninstall ---
if $DO_UNINSTALL; then
  echo ""
  echo "${BOLD}Ciel v${CIEL_VERSION} -- Uninstall${RESET}"
  echo ""
  rm -rf "$HOME/.ciel" 2>/dev/null || true
  rm -f "$HOME/.claude/commands/ciel-"*.md 2>/dev/null || true
  rm -f "$HOME/.claude/plugins/ciel-"* 2>/dev/null || true
  for f in .claude/settings.json .opencode/plugins/ciel.ts .opencode/agents .opencode/commands AGENTS.md CLAUDE.md; do
    rm -f "$f" 2>/dev/null || true
    rm -rf "$f" 2>/dev/null || true
  done
  ok "Ciel uninstalled"
  exit 0
fi

# --- Detect platform ---
detect_platform() {
  if [ -f "./.claude/settings.json" ] || [ -d "./.claude/agents" ] || command -v claude &>/dev/null; then
    echo "claude"
  elif [ -f "./opencode.json" ] || [ -d "./.opencode" ] || command -v opencode &>/dev/null; then
    echo "opencode"
  else
    echo "unknown"
  fi
}

PLATFORM=$(detect_platform)

# --- Download files if curl mode ---
download_if_needed() {
  $CURL_MODE || return 0
  local rel_path="$1"
  local dest="$TMP_DIR/$rel_path"
  mkdir -p "$(dirname "$dest")"
  curl -fsSL "$GITHUB_RAW/$rel_path" -o "$dest" 2>/dev/null
}

install_ciel_files() {
  local target_dir="$1"
  local name="$2"

  case "$name" in
    opencode)
      mkdir -p "$target_dir/.opencode/plugins" "$target_dir/.opencode/agents" "$target_dir/.opencode/commands"
      if $CURL_MODE; then
        download_if_needed ".opencode/plugins/ciel.ts"
        download_if_needed ".opencode/agents/ciel.md"
        download_if_needed ".opencode/agents/ciel-researcher.md"
        download_if_needed ".opencode/agents/ciel-explorer.md"
        download_if_needed ".opencode/agents/ciel-critic.md"
        download_if_needed ".opencode/agents/ciel-improver.md"
        for cmd in ciel-init ciel-update ciel-refresh ciel-improve ciel-eval ciel-create-skill ciel-recommend ciel-audit; do
          download_if_needed ".opencode/commands/${cmd}.md"
        done
        cp "$TMP_DIR/.opencode/plugins/ciel.ts" "$target_dir/.opencode/plugins/"
        cp "$TMP_DIR/.opencode/agents/"*.md "$target_dir/.opencode/agents/"
        cp "$TMP_DIR/.opencode/commands/"*.md "$target_dir/.opencode/commands/"
      else
        cp "$SRC_DIR/.opencode/plugins/ciel.ts" "$target_dir/.opencode/plugins/"
        cp "$SRC_DIR/.opencode/agents/"*.md "$target_dir/.opencode/agents/"
        cp "$SRC_DIR/.opencode/commands/"*.md "$target_dir/.opencode/commands/"
      fi
      ok "OpenCode plugin installed"
      ok "OpenCode agents (5) installed"
      ok "OpenCode commands (8) installed"

      # Install AGENTS.md if not exists
      if [ ! -f "$target_dir/AGENTS.md" ]; then
        if $CURL_MODE; then
          download_if_needed "AGENTS.md"
          cp "$TMP_DIR/AGENTS.md" "$target_dir/AGENTS.md"
        else
          cp "$SRC_DIR/AGENTS.md" "$target_dir/AGENTS.md"
        fi
        ok "AGENTS.md created"
      else
        ok "AGENTS.md already exists (kept)"
      fi

      # Update opencode.json
      local cfg="$target_dir/opencode.json"
      if [ ! -f "$cfg" ]; then
        echo '{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["./.opencode/plugins/ciel.ts"],
  "instructions": ["AGENTS.md"]
}' > "$cfg"
        ok "opencode.json created"
      else
        # Add ciel plugin and AGENTS.md instructions if missing
        if command -v jq &>/dev/null; then
          local tmp; tmp=$(mktemp)
          jq '.plugin = ((.plugin // []) | if index("./.opencode/plugins/ciel.ts") then . else . + ["./.opencode/plugins/ciel.ts"] end) | .instructions = ((.instructions // []) | if index("AGENTS.md") then . else . + ["AGENTS.md"] end)' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
          ok "opencode.json updated (plugin + instructions added)"
        else
          warn "jq not found -- opencode.json not modified. Install jq or add plugin manually:"
          echo "  .opencode/plugins/ciel.ts"
        fi
      fi
      ;;

    claude)
      # Install .claude/agents/
      mkdir -p "$target_dir/.claude/agents" "$target_dir/.claude/hooks"
      if $CURL_MODE; then
        for agent in ciel-researcher ciel-explorer ciel-critic ciel-improver; do
          download_if_needed ".claude/agents/${agent}.md"
        done
        for hook in check-test-first.sh block-destructive.sh track-file.sh meta-critiquer.sh; do
          download_if_needed ".claude/hooks/${hook}"
        done
        download_if_needed ".claude/settings.json"
        download_if_needed "CLAUDE.md"
        cp "$TMP_DIR/.claude/agents/"*.md "$target_dir/.claude/agents/"
        cp "$TMP_DIR/.claude/hooks/"*.sh "$target_dir/.claude/hooks/"
        cp "$TMP_DIR/.claude/settings.json" "$target_dir/.claude/settings.json"
        cp "$TMP_DIR/CLAUDE.md" "$target_dir/CLAUDE.md"
      else
        cp "$SRC_DIR/.claude/agents/"*.md "$target_dir/.claude/agents/"
        cp "$SRC_DIR/.claude/hooks/"*.sh "$target_dir/.claude/hooks/"
        cp "$SRC_DIR/.claude/settings.json" "$target_dir/.claude/settings.json"
        cp "$SRC_DIR/CLAUDE.md" "$target_dir/CLAUDE.md"
      fi
      chmod +x "$target_dir/.claude/hooks/"*.sh
      ok "Claude Code agents (4) installed"
      ok "Claude Code hooks (4) installed"
      ok "Claude Code settings.json installed"
      ok "CLAUDE.md installed"

      # Also install AGENTS.md for shared rules
      if [ ! -f "$target_dir/AGENTS.md" ]; then
        if $CURL_MODE; then
          download_if_needed "AGENTS.md"
          cp "$TMP_DIR/AGENTS.md" "$target_dir/AGENTS.md"
        else
          cp "$SRC_DIR/AGENTS.md" "$target_dir/AGENTS.md"
        fi
        ok "AGENTS.md created"
      fi
      ;;

    generic)
      warn "No recognized platform config found. Files installed at:"
      echo "  $target_dir/.ciel/"
      ;;
  esac

  # Always create .ciel/ directory for persistent state
  mkdir -p "$target_dir/.ciel"
  touch "$target_dir/.ciel/parking.md"
  if [ ! -f "$target_dir/.ciel/map.json" ]; then
    echo '{"modules":[],"lastUpdated":""}' > "$target_dir/.ciel/map.json"
  fi
  if [ ! -f "$target_dir/.ciel/memory.json" ]; then
    echo '{}' > "$target_dir/.ciel/memory.json"
  fi
  ok ".ciel/ directory initialized (map, memory, parking)"
}

# --- Main ---
echo ""
echo "${BOLD}Ciel v${CIEL_VERSION} Installer${RESET}"
echo ""
echo "  Platform: $(echo $PLATFORM | tr 'a-z' 'A-Z')"

if [ "$PLATFORM" = "unknown" ]; then
  echo ""
  warn "Could not auto-detect platform."
  echo "  Supported: OpenCode, Claude Code"
  echo "  Run from your project root and try again."
  echo ""
  exit 1
fi

PROJECT_ROOT=$(pwd)
if $DO_UPDATE; then
  info "Update mode -- reinstalling..."
fi

install_ciel_files "$PROJECT_ROOT" "$PLATFORM"

echo ""
echo "${BOLD}Done${RESET}"
echo ""
echo "  ${CYAN}->${RESET} Restart your coding agent to load Ciel v${CIEL_VERSION}"
echo ""

case "$PLATFORM" in
  opencode)
    echo "  ${CYAN}->${RESET} For LSP navigation: OPENCODE_EXPERIMENTAL_LSP_TOOL=true opencode"
    echo "  ${CYAN}->${RESET} Verify: run opencode and type a message containing 'auth'"
    echo "  ${CYAN}->${RESET} The system prompt should include depth classification"
    echo "  ${CYAN}->${RESET} For SPIKE mode: touch .ciel/exploration.active"
    ;;
  claude)
    echo "  ${CYAN}->${RESET} Verify: claude .  -- should load Ciel v5 pipeline"
    echo "  ${CYAN}->${RESET} Auto memory is enabled by default"
    echo "  ${CYAN}->${RESET} Test: edit a file without tests -- hook should warn"
    echo "  ${CYAN}->${RESET} Subagents: @ciel-researcher, @ciel-explorer, @ciel-critic"
    ;;
esac
echo ""
