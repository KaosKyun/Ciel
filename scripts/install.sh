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

# ─── Library Bootstrap (download if not present) ─────────────────────────────

# Detect if running from local file or curl pipe
CURL_MODE=false
if [[ "${BASH_SOURCE[0]}" == /dev/fd/* ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]; then
  CURL_MODE=true
  # Running from curl pipe — download libs to temp dir
  TEMP_LIB_DIR=$(mktemp -d)
  SCRIPT_DIR="$TEMP_LIB_DIR"
  CIEL_DIR="$TEMP_LIB_DIR"
  LIB_URL_BASE="https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/lib"
  
  info "Downloading Ciel libraries..."
  
  if ! curl -fsSL "$LIB_URL_BASE/platform.sh" -o "$TEMP_LIB_DIR/platform.sh" 2>/dev/null; then
    err "Failed to download lib/platform.sh"
    rm -rf "$TEMP_LIB_DIR"
    exit 1
  fi
  
  if ! curl -fsSL "$LIB_URL_BASE/installers.sh" -o "$TEMP_LIB_DIR/installers.sh" 2>/dev/null; then
    err "Failed to download lib/installers.sh"
    rm -rf "$TEMP_LIB_DIR"
    exit 1
  fi
  
  trap 'rm -rf "$TEMP_LIB_DIR"' EXIT
else
  # Running from local file
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CIEL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

# Source libraries
if [ -f "$SCRIPT_DIR/lib/platform.sh" ]; then
  source "$SCRIPT_DIR/lib/platform.sh"
elif [ -f "$SCRIPT_DIR/platform.sh" ]; then
  source "$SCRIPT_DIR/platform.sh"
else
  err "Library not found: lib/platform.sh"
  exit 1
fi

if [ -f "$SCRIPT_DIR/lib/installers.sh" ]; then
  source "$SCRIPT_DIR/lib/installers.sh"
elif [ -f "$SCRIPT_DIR/installers.sh" ]; then
  source "$SCRIPT_DIR/installers.sh"
else
  err "Library not found: lib/installers.sh"
  exit 1
fi

# ─── Version Management (GitHub-aware for curl mode) ─────────────────────────

get_local_version() {
  if [ "$CURL_MODE" = "true" ]; then
    # In curl mode, fetch from GitHub
    curl -fsSL "https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown"
  else
    # Local mode - read from repo
    cat "$CIEL_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "unknown"
  fi
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
  local max=${#V1[@]}
  [ ${#V2[@]} -gt $max ] && max=${#V2[@]}
  
  for ((i=0; i<max; i++)); do
    local n1=${V1[i]:-0}
    local n2=${V2[i]:-0}
    if [ "$n1" -lt "$n2" ]; then
      echo "-1"
      return
    elif [ "$n1" -gt "$n2" ]; then
      echo "1"
      return
    fi
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
      echo ""
      ok "Already up to date ($local_ver)"
      return 0
      ;;
    1)
      echo ""
      info "Local version is newer ($local_ver > $remote_ver)"
      return 0
      ;;
  esac
}

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

# ─── Platform Detection Override ─────────────────────────────────────────────

# If platform.sh has detect_platform, use it; otherwise define fallback
if ! type detect_platform &>/dev/null; then
  detect_platform() {
    local forced="${CIEL_FORCE_PLATFORM:-}"
    [ -n "$forced" ] && { echo "$forced"; return 0; }
    
    # Check project files (order matters - most specific first)
    [ -f "./.claude/settings.json" ] || [ -d "./.claude" ] && { echo "claude"; return 0; }
    [ -f "./opencode.json" ] || [ -d "./.opencode" ] && { echo "opencode"; return 0; }
    [ -d "./.cursor" ] && { echo "cursor"; return 0; }
    [ -d "./.windsurf" ] && { echo "windsurf"; return 0; }
    [ -d "./.codex" ] && { echo "codex"; return 0; }
    [ -d "./.kilocode" ] || [ -d "./.kilo" ] && { echo "kilocode"; return 0; }
    
    # Check CLI
    command -v claude &>/dev/null && { echo "claude"; return 0; }
    command -v opencode &>/dev/null && { echo "opencode"; return 0; }
    
    echo "unknown"
  }
fi

# ─── Installation Logic ──────────────────────────────────────────────────────

MANIFEST_FILE="$HOME/.ciel/manifest.json"

write_manifest() {
  mkdir -p "$(dirname "$MANIFEST_FILE")"
  
  local version installed_platforms=()
  version="$(get_local_version)"
  
  # Build platforms list
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

do_install() {
  local platform
  platform="$(detect_platform)"
  
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
  info "Detected platform: $(get_platform_name "$platform" 2>/dev/null || echo "$platform")"
  
  case "$platform" in
    claude)
      install_claude_code "$CIEL_DIR" "$PROJECT_ROOT" "$FLAG_USER"
      ;;
    opencode)
      install_opencode "$CIEL_DIR" "$PROJECT_ROOT"
      ;;
    cursor)
      install_generic "cursor" "$CIEL_DIR" "$PROJECT_ROOT"
      ;;
    windsurf)
      install_generic "windsurf" "$CIEL_DIR" "$PROJECT_ROOT"
      ;;
    codex)
      install_generic "codex" "$CIEL_DIR" "$PROJECT_ROOT"
      ;;
    kilocode)
      install_generic "kilocode" "$CIEL_DIR" "$PROJECT_ROOT"
      ;;
    *)
      err "Unsupported platform: $platform"
      echo "Supported: claude, opencode, cursor, windsurf, codex, kilocode"
      exit 1
      ;;
  esac
  
  # Register MCP servers if requested
  if [ -n "$MCP_LIST" ]; then
    info "Registering MCP servers: $MCP_LIST"
    # TODO: Implement MCP registration
  fi
  
  write_manifest
  
  echo ""
  ok "Installation complete!"
  echo ""
  echo "Next steps:"
  case "$platform" in
    claude)
      echo "  1. Restart Claude Code"
      echo "  2. Ciel hooks should auto-load"
      ;;
    opencode)
      echo "  1. Restart OpenCode"
      echo "  2. Ciel should auto-load (check for depth hints)"
      ;;
    *)
      echo "  1. Restart your AI assistant"
      echo "  2. Check platform-specific docs for plugin loading"
      ;;
  esac
}

do_uninstall() {
  info "Uninstalling Ciel..."
  
  local platform
  platform="$(detect_platform)"
  
  case "$platform" in
    claude)
      uninstall_claude_code "$PROJECT_ROOT"
      ;;
    opencode)
      uninstall_opencode "$PROJECT_ROOT"
      ;;
    *)
      rm -rf "$PROJECT_ROOT/.opencode" "$PROJECT_ROOT/.claude/plugins/ciel"
      ;;
  esac
  
  rm -f "$MANIFEST_FILE"
  ok "Uninstall complete"
}

do_update() {
  info "Updating Ciel..."
  
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
  
  # Re-install (this script is already the new version if run via curl)
  do_install
}

# ─── Main Entry Point ────────────────────────────────────────────────────────

do_install
