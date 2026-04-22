#!/usr/bin/env bash
# Ciel Universal Installer — Multi-Platform Support
# Supports: Claude Code, Cursor, Windsurf, Codex CLI, OpenCode, Kilo Code, Ollama, LM Studio

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

# ─── Library Bootstrap ───────────────────────────────────────────────────────

CURL_MODE=false
if [[ "${BASH_SOURCE[0]}" == /dev/fd/* ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]; then
  CURL_MODE=true
  TEMP_LIB_DIR=$(mktemp -d)
  SCRIPT_DIR="$TEMP_LIB_DIR"
  CIEL_DIR="$TEMP_LIB_DIR"
  LIB_URL_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/lib"
  
  info "Downloading Ciel libraries..."
  
  curl -fsSL "$LIB_URL_BASE/platform.sh" -o "$TEMP_LIB_DIR/platform.sh" || { err "Failed to download platform.sh"; rm -rf "$TEMP_LIB_DIR"; exit 1; }
  curl -fsSL "$LIB_URL_BASE/installers.sh" -o "$TEMP_LIB_DIR/installers.sh" || { err "Failed to download installers.sh"; rm -rf "$TEMP_LIB_DIR"; exit 1; }
  
  trap 'rm -rf "$TEMP_LIB_DIR"' EXIT
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CIEL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

source "$SCRIPT_DIR/lib/platform.sh"
source "$SCRIPT_DIR/lib/installers.sh"

# ─── Version Management ──────────────────────────────────────────────────────

get_local_version() {
  if [ "$CURL_MODE" = "true" ]; then
    curl -fsSL "https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "3.4.1"
  else
    cat "$CIEL_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "3.4.1"
  fi
}

# ─── Multi-Platform Detection ────────────────────────────────────────────────

detect_all_platforms() {
  local platforms=()
  local project_platforms_found=false
  
  # Check project-level configs ONLY (primary detection)
  # For Claude Code: require settings.json or settings.local.json (not just .claude/ dir)
  [ -f "./.claude/settings.json" ] || [ -f "./.claude/settings.local.json" ] && { platforms+=("claude"); project_platforms_found=true; }
  [ -f "./opencode.json" ] || [ -d "./.opencode" ] && { platforms+=("opencode"); project_platforms_found=true; }
  [ -d "./.cursor" ] && { platforms+=("cursor"); project_platforms_found=true; }
  [ -d "./.windsurf" ] && { platforms+=("windsurf"); project_platforms_found=true; }
  [ -d "./.codex" ] && { platforms+=("codex"); project_platforms_found=true; }
  [ -d "./.kilocode" ] || [ -d "./.kilo" ] && { platforms+=("kilocode"); project_platforms_found=true; }
  
  # Check user-level configs ONLY if no project-level configs found
  # This prevents installing Claude Code hooks in a global config for an OpenCode-only project
  if [ "$project_platforms_found" = "false" ]; then
    [ -d "$HOME/.claude" ] && platforms+=("claude")
    [ -d "$HOME/.opencode" ] && platforms+=("opencode")
  fi
  
  # Check CLI availability (if no project/user configs found)
  if [ ${#platforms[@]} -eq 0 ]; then
    command -v claude &>/dev/null && platforms+=("claude")
    command -v opencode &>/dev/null && platforms+=("opencode")
    command -v cursor &>/dev/null && platforms+=("cursor")
  fi
  
  # Output unique platforms
  printf '%s\n' "${platforms[@]}" | sort -u
}

# ─── Installation Functions ──────────────────────────────────────────────────

install_for_platform() {
  local platform="$1"
  local ciel_dir="$2"
  local project_root="$3"
  
  case "$platform" in
    claude)
      install_claude_code "$ciel_dir" "$project_root" "false"
      ;;
    opencode)
      install_opencode "$ciel_dir" "$project_root"
      ;;
    cursor)
      install_generic "cursor" "$ciel_dir" "$project_root"
      ;;
    windsurf)
      install_generic "windsurf" "$ciel_dir" "$project_root"
      ;;
    codex)
      install_generic "codex" "$ciel_dir" "$project_root"
      ;;
    kilocode)
      install_generic "kilocode" "$ciel_dir" "$project_root"
      ;;
    *)
      warn "Unknown platform: $platform"
      ;;
  esac
}

# ─── Main ────────────────────────────────────────────────────────────────────

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║   Ciel Installer v$(get_local_version)              ║"
echo "╚═══════════════════════════════════════╝"
echo ""

info "Detecting installed platforms..."

PLATFORMS=()
while IFS= read -r platform; do
  [ -n "$platform" ] && PLATFORMS+=("$platform")
done < <(detect_all_platforms)

if [ ${#PLATFORMS[@]} -eq 0 ]; then
  err "No supported platforms detected"
  echo ""
  echo "Supported platforms:"
  echo "  - Claude Code (~/.claude/ or 'claude' CLI)"
  echo "  - OpenCode (opencode.json or 'opencode' CLI)"
  echo "  - Cursor (.cursor/)"
  echo "  - Windsurf (.windsurf/)"
  echo "  - Codex (.codex/)"
  echo "  - KiloCode (.kilocode/)"
  echo ""
  echo "To force a specific platform:"
  echo "  bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh) --platform=claude"
  exit 1
fi

info "Detected ${#PLATFORMS[@]} platform(s): ${PLATFORMS[*]}"
echo ""

for platform in "${PLATFORMS[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  install_for_platform "$platform" "$CIEL_DIR" "$(pwd)"
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ok "Installation complete for all platforms!"
echo ""
echo "Next steps:"
echo "  - Claude Code: Restart Claude, hooks auto-load"
echo "  - OpenCode: Restart OpenCode, plugin auto-loads"
echo "  - Others: Check platform docs for plugin loading"
