#!/usr/bin/env bash
# Ciel Universal Installer — Modular Refactored Version
# Supports: Claude Code, Cursor, Windsurf, Codex CLI, OpenCode, Kilo Code, Ollama, LM Studio
# Usage: bash scripts/install.sh [project-root] [flags]
#
# Flags:
#   --uninstall         Remove all files tracked in ~/.ciel/manifest.json
#   --check-update      Query GitHub for newer VERSION and report
#   --update            Uninstall + re-install latest from main
#   --with-mcp=LIST     Register MCP servers (CSV: playwright,context7)
#   --platform=NAME     Force specific platform (skip auto-detection)
#   --user              Install to user scope instead of project scope
#   -y, --yes           Skip interactive confirmations
#   -h, --help          Show this help message

set -euo pipefail

# ─── Bootstrap ───────────────────────────────────────────────────────────────

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

# Source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CIEL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$SCRIPT_DIR/lib/platform.sh" ]; then
  source "$SCRIPT_DIR/lib/platform.sh"
else
  err "Library not found: lib/platform.sh"
  exit 1
fi

if [ -f "$SCRIPT_DIR/lib/installers.sh" ]; then
  source "$SCRIPT_DIR/lib/installers.sh"
else
  err "Library not found: lib/installers.sh"
  exit 1
fi

# ─── Flag Parsing ────────────────────────────────────────────────────────────

FLAG_UNINSTALL=false
FLAG_CHECK_UPDATE=false
FLAG_UPDATE=false
FLAG_YES=false
FLAG_USER=false
MCP_LIST=""
FORCED_PLATFORM=""
POSITIONAL=()

for arg in "$@"; do
  case "$arg" in
    --uninstall)     FLAG_UNINSTALL=true ;;
    --check-update)  FLAG_CHECK_UPDATE=true ;;
    --update)        FLAG_UPDATE=true ;;
    --with-mcp=*)    MCP_LIST="${arg#*=}" ;;
    --platform=*)    FORCED_PLATFORM="${arg#*=}" ;;
    --user)          FLAG_USER=true ;;
    -y|--yes)        FLAG_YES=true ;;
    -h|--help)
      head -20 "$0" | sed 's/^# \?//'
      exit 0
      ;;
    -*)
      warn "Unknown flag: $arg (use --help for usage)"
      ;;
    *)
      POSITIONAL+=("$arg")
      ;;
  esac
done

PROJECT_ROOT="${POSITIONAL[0]:-$(pwd)}"
export CIEL_FORCE_PLATFORM="$FORCED_PLATFORM"

# ─── Version Management ──────────────────────────────────────────────────────

get_local_version() {
  cat "$CIEL_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown"
}

get_remote_version() {
  curl -fsSL "https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION" 2>/dev/null | tr -d '[:space:]' || echo ""
}

compare_versions() {
  local v1="$1" v2="$2"
  
  # Handle "unknown" versions
  [ "$v1" = "unknown" ] && { echo "-1"; return; }
  [ -z "$v2" ] && { echo "-1"; return; }
  
  # Split versions
  local IFS='.'
  read -ra V1 <<< "$v1"
  read -ra V2 <<< "$v2"
  
  # Compare each component
  for i in 0 1 2; do
    local n1="${V1[$i]:-0}"
    local n2="${V2[$i]:-0}"
    [ "$n1" -lt "$n2" ] && { echo "-1"; return; }
    [ "$n1" -gt "$n2" ] && { echo "1"; return; }
  done
  
  echo "0"
}

check_update() {
  info "Checking for updates..."
  
  local local_ver remote_ver
  local_ver="$(get_local_version)"
  remote_ver="$(get_remote_version)"
  
  if [ -z "$remote_ver" ]; then
    warn "Could not fetch remote version (network issue?)"
    return 1
  fi
  
  echo "  Local:  $local_ver"
  echo "  Remote: $remote_ver"
  
  local cmp
  cmp="$(compare_versions "$local_ver" "$remote_ver")"
  
  case "$cmp" in
    -1)
      echo ""
      info "Update available: $local_ver → $remote_ver"
      echo "  Run with --update to install"
      return 0
      ;;
    0)
      info "Already up to date"
      return 0
      ;;
    1)
      warn "Local version is newer than remote (development version?)"
      return 0
      ;;
  esac
}

# ─── Manifest Management ─────────────────────────────────────────────────────

MANIFEST_FILE="$HOME/.ciel/manifest.json"

init_manifest() {
  mkdir -p "$(dirname "$MANIFEST_FILE")"
}

read_manifest_version() {
  [ -f "$MANIFEST_FILE" ] || return 1
  grep -oE '"version":[[:space:]]*"[^"]+"' "$MANIFEST_FILE" | \
    sed 's/.*"\([^"]*\)".*/\1/' | head -1
}

write_manifest() {
  local version installed_platforms mcp_servers
  version="$(get_local_version)"
  
  # Build platforms list
  installed_platforms=()
  for dir in "$HOME/.claude/plugins/ciel" "$PROJECT_ROOT/.opencode"; do
    [ -d "$dir" ] && installed_platforms+=("$(basename "$dir")")
  done
  
  # Write manifest
  cat > "$MANIFEST_FILE" <<EOF
{
  "version": "$version",
  "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "platforms": [$(printf '"%s",' "${installed_platforms[@]}" | sed 's/,$//')],
  "mcp": [${MCP_LIST:+\"${MCP_LIST//,/\", \"}\"}],
  "ciel_dir": "$CIEL_DIR"
}
EOF
  
  ok "Manifest written: $MANIFEST_FILE"
}

# ─── Main Installation Logic ─────────────────────────────────────────────────

do_install() {
  init_manifest
  
  # Detect platform
  local platform
  platform="$(detect_platform)"
  
  if [ "$platform" = "unknown" ]; then
    err "Cannot detect AI coding platform."
    echo ""
    echo "Supported platforms:"
    echo "  - Claude Code (claude)"
    echo "  - OpenCode (opencode)"
    echo "  - Cursor (cursor)"
    echo "  - Windsurf (windsurf)"
    echo "  - Codex CLI (codex)"
    echo "  - Kilo Code (kilocode)"
    echo "  - Ollama (ollama)"
    echo "  - LM Studio (lmstudio)"
    echo ""
    echo "Specify with --platform=name"
    return 1
  fi
  
  info "Detected platform: $(get_platform_name "$platform")"
  
  # Validate platform
  if ! validate_platform "$platform"; then
    warn "$(get_platform_name "$platform") not fully configured"
    print_install_instructions "$platform"
    
    if [ "$FLAG_YES" != "true" ]; then
      echo ""
      read -p "Continue anyway? [y/N] " -n 1 -r
      echo
      [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
    fi
  fi
  
  # Install based on platform
  case "$platform" in
    claude)
      install_claude_code "$CIEL_DIR" "$PROJECT_ROOT" "$FLAG_USER"
      ;;
    opencode)
      install_opencode "$CIEL_DIR" "$PROJECT_ROOT"
      ;;
    cursor|windsurf|codex|kilocode|ollama|lmstudio)
      install_generic "$platform" "$CIEL_DIR" "$PROJECT_ROOT"
      ;;
  esac
  
  # Install MCP servers if requested
  if [ -n "$MCP_LIST" ]; then
    info "Installing MCP servers: $MCP_LIST"
    # TODO: Implement MCP installation
  fi
  
  # Write manifest
  write_manifest
  
  echo ""
  info "Installation complete!"
  echo ""
  echo "Next steps:"
  case "$platform" in
    claude)
      echo "  1. Restart Claude Code"
      echo "  2. Run /ciel-init to verify hooks"
      ;;
    opencode)
      echo "  1. Restart OpenCode"
      echo "  2. Ciel should auto-load (check for depth hints)"
      ;;
    *)
      echo "  1. Restart $(get_platform_name "$platform")"
      echo "  2. Check that Ciel rules/skills are active"
      ;;
  esac
  
  return 0
}

do_uninstall() {
  info "Uninstalling Ciel..."
  
  # Uninstall from all platforms
  if [ -d "$HOME/.claude/plugins/ciel" ]; then
    uninstall_claude_code
  fi
  
  if [ -d "./.opencode" ]; then
    uninstall_opencode "$(pwd)"
  fi
  
  for platform in cursor windsurf codex kilocode ollama lmstudio; do
    uninstall_generic "$platform" "$(pwd)"
  done
  
  # Remove manifest
  if [ -f "$MANIFEST_FILE" ]; then
    rm "$MANIFEST_FILE"
    ok "Removed manifest"
  fi
  
  echo ""
  info "Uninstall complete"
  return 0
}

do_update() {
  info "Updating Ciel..."
  
  # Check if update is available
  local local_ver remote_ver
  local_ver="$(get_local_version)"
  remote_ver="$(get_remote_version)"
  
  if [ -z "$remote_ver" ]; then
    err "Could not fetch remote version"
    return 1
  fi
  
  local cmp
  cmp="$(compare_versions "$local_ver" "$remote_ver")"
  
  if [ "$cmp" != "-1" ]; then
    info "Already up to date ($local_ver)"
    return 0
  fi
  
  info "Updating from $local_ver to $remote_ver"
  
  # Uninstall current version
  do_uninstall
  
  # Clone latest version
  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT
  
  info "Cloning latest version..."
  if ! git clone --depth=1 --quiet https://github.com/KaosKyun/Ciel.git "$temp_dir"; then
    err "Failed to clone repository"
    return 1
  fi
  
  # Install from temp directory
  CIEL_DIR="$temp_dir"
  do_install
  
  echo ""
  ok "Update complete: $local_ver → $remote_ver"
  return 0
}

# ─── Main Entry Point ────────────────────────────────────────────────────────

main() {
  echo ""
  echo "╔═══════════════════════════════════════╗"
  echo "║   Ciel Installer v$(get_local_version)              ║"
  echo "╚═══════════════════════════════════════╝"
  echo ""
  
  if [ "$FLAG_CHECK_UPDATE" = "true" ]; then
    check_update
    exit $?
  fi
  
  if [ "$FLAG_UPDATE" = "true" ]; then
    do_update
    exit $?
  fi
  
  if [ "$FLAG_UNINSTALL" = "true" ]; then
    do_uninstall
    exit $?
  fi
  
  # Default: install
  do_install
  exit $?
}

main "$@"
