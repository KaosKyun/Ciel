#!/usr/bin/env bash
# Ciel v5 — Universal Installer
# Usage:
#   curl -fsSL https://install.ciel.sh | bash
#   bash install.sh                    # local clone
#   bash install.sh -y                 # skip confirmation
#   bash install.sh -q                 # quiet mode
#   bash install.sh --uninstall        # remove everything
#   bash install.sh --update           # force reinstall
#   bash install.sh --help             # show full usage
#
# Principle: one command, zero config. Idempotent — safe to re-run.
# Auto-detects OpenCode or Claude Code from project files.

set -euo pipefail

# ============================================================
#  BLOCK WRAPPER — ensures entire script is downloaded first
# ============================================================
{ # <-- wrapper start

CIEL_VERSION="5.1.0"
GITHUB_RAW="https://raw.githubusercontent.com/KaosKyun/Ciel/main"

# ----- Config -----
DO_UNINSTALL=false
DO_UPDATE=false
DO_QUIET=false
DO_YES=false
CIEL_LOG=""

# ============================================================
#  HELP
# ============================================================
usage() {
  cat <<EOF
Ciel v${CIEL_VERSION} — Universal Installer

Auto-detects OpenCode or Claude Code and installs plugins, agents,
hooks, and commands into your project.

USAGE:
  curl -fsSL https://install.ciel.sh | bash
  bash install.sh [OPTIONS]

OPTIONS:
  -y, --yes          Skip confirmation prompt (non-interactive)
  -q, --quiet        Suppress progress output (errors still shown)
  -u, --update       Force reinstall even if already installed
      --check-update Check GitHub for a newer version (no install)
      --uninstall    Remove all Ciel files from the project
      --help         Show this help message

EXAMPLES:
  Install interactively:
    bash <(curl -fsSL https://install.ciel.sh)

  Install in CI without prompt:
    curl -fsSL https://install.ciel.sh | bash -s -- -y

  Reinstall after update:
    bash install.sh --update -y

  Uninstall:
    bash install.sh --uninstall

EXIT CODES:
  0  Success
  1  Pre-flight check failed (missing dep, wrong platform)
  2  Installation failed (download, copy, or permissions)

EOF
  exit 0
}

# ============================================================
#  SAFE OUTPUT — detect ANSI support, use raw if piped
# ============================================================
_ansi() {
  # Only emit ANSI if stdout is a terminal
  [ -t 1 ] && printf '%s' "$1" || true
}

say()   { [ "$DO_QUIET" = false ] && printf "  %s%s\\n" "$(_ansi '\033[0;36m→\033[0m ')" "$1" || true; }
ok()    { [ "$DO_QUIET" = false ] && printf "  %s%s\\n" "$(_ansi '\033[0;32m✓\033[0m ')" "$1" || true; }
warn()  { printf "  %s%s\\n" "$(_ansi '\033[0;33m~\033[0m ')" "$1" >&2; }
err()   { printf "  %s%s\\n" "$(_ansi '\033[0;31m✗\033[0m ')" "$1" >&2; }
header() { printf "\\n  %s%s%s\\n" "$(_ansi '\033[1m')" "$1" "$(_ansi '\033[0m')"; }

# ============================================================
#  UTILITY HELPERS
# ============================================================
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Missing required command: \`$1\`"
    err "Install $1 and try again."
    exit 1
  fi
}

ensure() {
  if ! "$@"; then
    err "Command failed: $*"
    exit 2
  fi
}

log() {
  [ -n "$CIEL_LOG" ] && printf "[%s] %s\\n" "$(date '+%H:%M:%S')" "$*" >> "$CIEL_LOG" || true
}

# ============================================================
#  FLAG PARSING
# ============================================================
DO_CHECK_UPDATE=false

parse_flags() {
  for arg in "$@"; do
    case "$arg" in
      --help | -h)         usage ;;
      --uninstall)         DO_UNINSTALL=true ;;
      --update | -u)       DO_UPDATE=true ;;
      --check-update)      DO_CHECK_UPDATE=true ;;
      --quiet | -q)        DO_QUIET=true ;;
      --yes | -y)          DO_YES=true ;;
      *)                   warn "Ignoring unknown argument: $arg" ;;
    esac
  done
}

# ============================================================
#  VERSION CHECK
# ============================================================
check_update() {
  local remote_version
  remote_version=$(curl -fsSL --connect-timeout 5 "$GITHUB_RAW/VERSION" 2>/dev/null || true)

  if [ -z "$remote_version" ]; then
    err "Could not fetch remote version from GitHub."
    err "Check your internet connection."
    exit 2
  fi

  # Strip whitespace
  remote_version=$(printf '%s' "$remote_version" | tr -d '[:space:]')
  local current_version="$CIEL_VERSION"

  if [ "$remote_version" = "$current_version" ]; then
    ok "Ciel v${current_version} is up to date."
    exit 0
  fi

  say "Update available: v${current_version} → v${remote_version}"
  say "Run \`bash install.sh --update\` to upgrade."
  exit 0
}

# ============================================================
#  PRE-FLIGHT
# ============================================================
pre_flight() {
  # Bash version check (need 4+ for assoc arrays, though we don't use them)
  if [ -z "${BASH_VERSION:-}" ]; then
    err "This installer requires Bash. Pipe it to \`bash\`, not \`sh\`."
    err "  curl -fsSL https://install.ciel.sh | bash"
    exit 1
  fi

  need_cmd "curl"
  need_cmd "git"

  # Must run from a project root (contains at least a README or similar)
  if [ ! -f "./opencode.json" ] && [ ! -d "./.opencode" ] && [ ! -f "./.claude/settings.json" ] && [ ! -d "./.claude" ]; then
    warn "No recognized project files found in $(pwd)"
    say "Ciel installs files into your project. Run this from your project root."
    say "If this is your project root, you can continue anyway."
    say "Project files Ciel looks for: opencode.json, .opencode/, .claude/"
    if [ "$DO_YES" = false ]; then
      printf "  %sContinue anyway? [y/N]: " "$(_ansi '\033[0;33m?\033[0m ')" >&2
      read -r confirm
      [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { say "Aborted."; exit 0; }
    fi
  fi

  # Create temp log
  CIEL_LOG=$(mktemp)
  log "Ciel v${CIEL_VERSION} install starting"
  log "PWD: $(pwd)"
  log "Args: $*"
}

# ============================================================
#  ARCHITECTURE DETECTION
# ============================================================
detect_platform() {
  if [ -f "./opencode.json" ] || [ -d "./.opencode" ]; then
    echo "opencode"
  elif [ -f "./.claude/settings.json" ] || [ -d "./.claude/agents" ]; then
    echo "claude"
  elif command -v opencode &>/dev/null; then
    echo "opencode"
  elif command -v claude &>/dev/null; then
    echo "claude"
  else
    echo "unknown"
  fi
}

# ============================================================
#  CURL MODE DETECTION
# ============================================================
is_curl_mode() {
  [[ "${BASH_SOURCE[0]}" == /dev/fd/* ]] || [[ ! -f "${BASH_SOURCE[0]}" ]]
}

download_if_needed() {
  $CURL_MODE || return 0
  local rel_path="$1"
  local dest="$TMP_DIR/$rel_path"
  mkdir -p "$(dirname "$dest")"
  ensure curl -fsSL "$GITHUB_RAW/$rel_path" -o "$dest"
  log "downloaded: $rel_path"
}

# ============================================================
#  BACKUP EXISTING FILES
# ============================================================
backup_file() {
  local path="$1"
  if [ -f "$path" ] || [ -d "$path" ]; then
    local backup
    backup="${path}.bak.$(date +%s)"
    ensure cp -r "$path" "$backup"
    log "backed up: $path -> $backup"
  fi
}

# ============================================================
#  INSTALL LOGIC
# ============================================================
install_ciel_files() {
  local target_dir="$1"
  local name="$2"
  local installed=(0)  # init for nounset
  local skipped=(0)

  case "$name" in
    opencode)
      ensure mkdir -p "$target_dir/.opencode/plugins" \
                     "$target_dir/.opencode/agents" \
                     "$target_dir/.opencode/commands"

      # Copy or download plugin
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
        ensure cp "$TMP_DIR/.opencode/plugins/ciel.ts" "$target_dir/.opencode/plugins/"
        ensure cp "$TMP_DIR/.opencode/agents/"*.md "$target_dir/.opencode/agents/"
        ensure cp "$TMP_DIR/.opencode/commands/"*.md "$target_dir/.opencode/commands/"
      else
        cp -n "$SRC_DIR/.opencode/plugins/ciel.ts" "$target_dir/.opencode/plugins/" 2>/dev/null && \
          installed+=("plugin") || skipped+=("plugin")
        cp -n "$SRC_DIR/.opencode/agents/"*.md "$target_dir/.opencode/agents/" 2>/dev/null && \
          installed+=("agents") || skipped+=("agents")
        cp -n "$SRC_DIR/.opencode/commands/"*.md "$target_dir/.opencode/commands/" 2>/dev/null && \
          installed+=("commands") || skipped+=("commands")
      fi
      log "opencode: installed=${installed[*]}, skipped=${skipped[*]}"

      # AGENTS.md (shared rules)
      if [ ! -f "$target_dir/AGENTS.md" ]; then
        if $CURL_MODE; then
          download_if_needed "AGENTS.md"
          ensure cp "$TMP_DIR/AGENTS.md" "$target_dir/AGENTS.md"
        elif [ "$SRC_DIR" != "$target_dir" ]; then
          ensure cp "$SRC_DIR/AGENTS.md" "$target_dir/AGENTS.md"
        fi
        installed+=("AGENTS.md")
      else
        skipped+=("AGENTS.md")
      fi

      # opencode.json config
      local cfg="$target_dir/opencode.json"
      if [ ! -f "$cfg" ]; then
        printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "plugin": ["./.opencode/plugins/ciel.ts"],\n  "instructions": ["AGENTS.md"]\n}\n' > "$cfg"
        installed+=("opencode.json")
      else
        if command -v jq &>/dev/null; then
          local tmp; tmp=$(mktemp)
          if jq '.plugin = ((.plugin // []) | if index("./.opencode/plugins/ciel.ts") then . else . + ["./.opencode/plugins/ciel.ts"] end) | .instructions = ((.instructions // []) | if index("AGENTS.md") then . else . + ["AGENTS.md"] end)' "$cfg" > "$tmp" && mv "$tmp" "$cfg"; then
            installed+=("opencode.json (patched)")
          else
            skipped+=("opencode.json (patch failed)")
          fi
        else
          warn "jq not found -- opencode.json not patched. Add plugin manually:"
          say "  .opencode/plugins/ciel.ts"
          skipped+=("opencode.json (jq missing)")
        fi
      fi
      ;;

    claude)
      ensure mkdir -p "$target_dir/.claude/agents" "$target_dir/.claude/hooks"

      if $CURL_MODE; then
        for agent in ciel-researcher ciel-explorer ciel-critic ciel-improver; do
          download_if_needed ".claude/agents/${agent}.md"
        done
        for hook in check-test-first.sh block-destructive.sh track-file.sh meta-critiquer.sh; do
          download_if_needed ".claude/hooks/${hook}"
        done
        download_if_needed ".claude/settings.json"
        download_if_needed "CLAUDE.md"
        ensure cp "$TMP_DIR/.claude/agents/"*.md "$target_dir/.claude/agents/"
        ensure cp "$TMP_DIR/.claude/hooks/"*.sh "$target_dir/.claude/hooks/"
        ensure cp "$TMP_DIR/.claude/settings.json" "$target_dir/.claude/settings.json"
        ensure cp "$TMP_DIR/CLAUDE.md" "$target_dir/CLAUDE.md"
      else
        cp -n "$SRC_DIR/.claude/agents/"*.md "$target_dir/.claude/agents/" 2>/dev/null && \
          installed+=("agents") || skipped+=("agents")
        cp -n "$SRC_DIR/.claude/hooks/"*.sh "$target_dir/.claude/hooks/" 2>/dev/null && \
          installed+=("hooks") || skipped+=("hooks")
        cp -n "$SRC_DIR/.claude/settings.json" "$target_dir/.claude/settings.json" 2>/dev/null && \
          installed+=("settings.json") || skipped+=("settings.json")
        cp -n "$SRC_DIR/CLAUDE.md" "$target_dir/CLAUDE.md" 2>/dev/null && \
          installed+=("CLAUDE.md") || skipped+=("CLAUDE.md")
      fi
      ensure chmod +x "$target_dir/.claude/hooks/"*.sh
      log "claude: installed=${installed[*]}, skipped=${skipped[*]}"

      # AGENTS.md
      if [ ! -f "$target_dir/AGENTS.md" ]; then
        if $CURL_MODE; then
          download_if_needed "AGENTS.md"
          ensure cp "$TMP_DIR/AGENTS.md" "$target_dir/AGENTS.md"
        elif [ "$SRC_DIR" != "$target_dir" ]; then
          ensure cp "$SRC_DIR/AGENTS.md" "$target_dir/AGENTS.md"
        fi
        installed+=("AGENTS.md")
      else
        skipped+=("AGENTS.md")
      fi
      ;;

    generic)
      warn "No recognized platform config found. Files installed at:"
      say "  $target_dir/.ciel/"
      installed+=(".ciel/")
      ;;
  esac

  # Always create .ciel/ directory
  ensure mkdir -p "$target_dir/.ciel"
  touch "$target_dir/.ciel/parking.md"
  if [ ! -f "$target_dir/.ciel/map.json" ]; then
    printf '{"modules":[],"lastUpdated":""}\n' > "$target_dir/.ciel/map.json"
  fi
  if [ ! -f "$target_dir/.ciel/memory.json" ]; then
    printf '{}\n' > "$target_dir/.ciel/memory.json"
  fi
  installed+=(".ciel/")

  log ".ciel/ initialized"

  # Return summary
  echo "${installed[*]}" > /dev/null
}

# ============================================================
#  VERIFY INSTALLED FILES
# ============================================================
verify_files() {
  local target_dir="$1"
  local name="$2"
  local errors=0

  case "$name" in
    opencode)
      [ -f "$target_dir/.opencode/plugins/ciel.ts" ] || { err "Missing: .opencode/plugins/ciel.ts"; ((errors++)); }
      [ -f "$target_dir/.opencode/agents/ciel.md" ]  || { err "Missing: .opencode/agents/ciel.md";  ((errors++)); }
      ;;
    claude)
      [ -f "$target_dir/.claude/settings.json" ] || { err "Missing: .claude/settings.json"; ((errors++)); }
      [ -f "$target_dir/.claude/agents/ciel-researcher.md" ] || { err "Missing: .claude/agents/ciel-researcher.md"; ((errors++)); }
      ;;
  esac

  # Common files
  [ -f "$target_dir/.ciel/map.json" ]    || { err "Missing: .ciel/map.json"; ((errors++)); }
  [ -f "$target_dir/.ciel/parking.md" ]  || { err "Missing: .ciel/parking.md"; ((errors++)); }

  if [ "$errors" -gt 0 ]; then
    warn "${errors} file(s) missing after install. Try reinstalling."
    exit 2
  fi
  log "verify: ${errors} errors"
  return 0
}

# ============================================================
#  SUMMARY TABLE
# ============================================================
print_summary() {
  local platform="$1"
  local target_dir="$2"

  header "Ciel v${CIEL_VERSION} — Install Summary"
  printf "  %-20s %s\\n" "Platform:" "$(printf '%s' "$platform" | tr '[:lower:]' '[:upper:]')"
  printf "  %-20s %s\\n" "Project:" "$target_dir"
  printf "  %-20s %s\\n" "Log:" "${CIEL_LOG:-none}"
  echo ""

  case "$platform" in
    opencode)
      header "Installed Files"
      for f in .opencode/plugins/ciel.ts .opencode/agents .opencode/commands .ciel/; do
        if [ -e "$target_dir/$f" ]; then
          ok "$f"
        else
          err "$f (missing!)"
        fi
      done
      echo ""
      header "Next Steps"
      say "1. Restart OpenCode to load Ciel v${CIEL_VERSION}"
      say "2. Test: type a message — should see depth classification"
      say "3. For LSP: OPENCODE_EXPERIMENTAL_LSP_TOOL=true opencode"
      say "4. For SPIKE mode: touch .ciel/exploration.active"
      ;;
    claude)
      header "Installed Files"
      for f in .claude/agents .claude/hooks .claude/settings.json CLAUDE.md .ciel/; do
        if [ -e "$target_dir/$f" ]; then
          ok "$f"
        else
          err "$f (missing!)"
        fi
      done
      echo ""
      header "Next Steps"
      say "1. Restart Claude Code: claude ."
      say "2. Auto memory is enabled by default"
      say "3. Test: edit a file without tests — hook should warn"
      say "4. Subagents: @ciel-researcher, @ciel-explorer, @ciel-critic"
      ;;
  esac
}

# ============================================================
#  UNINSTALL
# ============================================================
do_uninstall() {
  header "Ciel v${CIEL_VERSION} — Uninstall"
  echo ""

  if [ "$DO_YES" = false ]; then
    printf "  %sThis will remove Ciel files from the current project.%s\\n" \
      "$(_ansi '\033[0;33m')" "$(_ansi '\033[0m')"
    printf "  %sContinue? [y/N]: " "$(_ansi '\033[0;33m?\033[0m ')" >&2
    read -r confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { say "Aborted."; exit 0; }
  fi

  local count=0
  rm -rf "$HOME/.ciel" 2>/dev/null && { ok "~/.ciel/ removed"; ((count++)); } || true

  for f in .claude/settings.json .opencode/plugins/ciel.ts .opencode/agents .opencode/commands AGENTS.md CLAUDE.md; do
    if [ -e "$f" ]; then
      rm -rf "$f" 2>/dev/null && { ok "$f removed"; ((count++)); } || true
    fi
  done

  echo ""
  ok "${count} file(s) removed"
  say "Ciel has been uninstalled from this project."
  exit 0
}

# ============================================================
#  MAIN
# ============================================================
main() {
  parse_flags "$@"

  # Uninstall mode
  if $DO_UNINSTALL; then
    do_uninstall
  fi

  # Check-update mode (needs only curl, runs early)
  if $DO_CHECK_UPDATE; then
    need_cmd "curl"
    check_update
  fi

  # Pre-flight checks
  pre_flight

  # Platform detection
  local PLATFORM
  PLATFORM=$(detect_platform)
  log "platform: $PLATFORM"

  if [ "$PLATFORM" = "unknown" ]; then
    err "Could not auto-detect OpenCode or Claude Code."
    say "Run this from your project root (where opencode.json or .claude/ lives)."
    exit 1
  fi

  # Detect install mode (curl pipe vs local file)
  local CURL_MODE=false
  local SRC_DIR=""
  local TMP_DIR=""
  if is_curl_mode; then
    CURL_MODE=true
    TMP_DIR=$(mktemp -d)
    SRC_DIR="$TMP_DIR"
    trap 'log "cleanup: $TMP_DIR"; rm -rf "$TMP_DIR"' EXIT
    say "Downloading Ciel v${CIEL_VERSION}..."
    # Quick connectivity check
    curl -fsSL --connect-timeout 5 "$GITHUB_RAW/VERSION" -o /dev/null 2>/dev/null || {
      err "Cannot reach GitHub. Check internet connection."
      exit 2
    }
  else
    CURL_MODE=false
    SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi

  # Confirmation prompt
  local PROJECT_ROOT
  PROJECT_ROOT=$(pwd)
  if [ "$DO_YES" = false ] && [ "$CURL_MODE" = true ]; then
    printf "  %sInstall Ciel v%s in %s? [Y/n]: " \
      "$(_ansi '\033[0;33m?\033[0m ')" "$CIEL_VERSION" "$PROJECT_ROOT" >&2
    read -r confirm
    [ "$confirm" = "n" ] || [ "$confirm" = "N" ] && { say "Aborted."; exit 0; }
  fi

  # Install
  if $DO_UPDATE; then
    say "Update mode — reinstalling all files..."
  fi
  install_ciel_files "$PROJECT_ROOT" "$PLATFORM"

  # Verify
  verify_files "$PROJECT_ROOT" "$PLATFORM"

  # Summary
  echo ""
  print_summary "$PLATFORM" "$PROJECT_ROOT"
  echo ""

  log "install complete (exit 0)"
}

main "$@"

} # <-- wrapper end
