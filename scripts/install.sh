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

CIEL_VERSION="6.13.0" # x-release-please-version
GITHUB_RAW="https://raw.githubusercontent.com/KaosKyun/Ciel/main"

# ----- Config -----
DO_UNINSTALL=false
DO_UPDATE=false
DO_QUIET=false
DO_YES=false
CIEL_LOG=""

# Copy flag: `-n` by default (no-clobber, preserves user edits on fresh install);
# flipped to `-f` when --update is set so upgrades actually overwrite managed files.
# Convention follows oh-my-zsh / gh extension upgrade / Homebrew (managed files
# get force-overwritten on upgrade; user state stays untouched elsewhere).
CP_FLAG="-n"

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
#  PROMPT — read from /dev/tty even in curl-pipe mode
# ============================================================
prompt_confirm() {
  local msg="$1"
  local default="${2:-y}"
  local answer

  printf "  %s%s [%s]: " "$(_ansi '\033[0;33m?\033[0m ')" "$msg" "$( [ "$default" = "y" ] && echo "Y/n" || echo "y/N" )" >&2

  # Try /dev/tty first (works when piped: curl ... | bash)
  read -r answer < /dev/tty 2>/dev/null || read -r answer || answer="$default"

  if [ "$default" = "n" ]; then
    [ "$answer" = "y" ] || [ "$answer" = "Y" ]
  else
    [ "$answer" != "n" ] && [ "$answer" != "N" ]
  fi
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
  # On --update, force-overwrite managed files (hooks, agents, commands, skills,
  # settings, CLAUDE.md). Without this, `cp -n` silently skips and "update" is a no-op.
  if $DO_UPDATE; then CP_FLAG="-f"; fi
}

# Guard against cp src==dst (same realpath) which errors. Returns 0 if safe to copy.
_cp_safe() {
  local src="$1" dst="$2"
  # If destination is a directory, resolve final path
  local final_dst="$dst"
  if [ -d "$dst" ]; then final_dst="$dst/$(basename "$src")"; fi
  # Resolve realpaths if possible; if either fails, fall through to cp (it will error out cleanly)
  local sr dr
  sr=$(cd "$(dirname "$src")" 2>/dev/null && pwd)/$(basename "$src")
  dr=$(cd "$(dirname "$final_dst")" 2>/dev/null && pwd)/$(basename "$final_dst") 2>/dev/null
  [ "$sr" = "$dr" ] && return 1
  return 0
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

  # Never install from home directory — CLAUDE.md at ~ gets loaded globally by
  # Claude Code for every project, creating duplicate instructions.
  if [ "$(pwd)" = "$HOME" ]; then
    err "Do not run Ciel install from your home directory (\$HOME)."
    err "A CLAUDE.md placed at ~ is loaded by Claude Code in ALL projects, causing duplicates."
    err "cd into your project directory first, then re-run install.sh."
    exit 1
  fi

  # Must run from a project root (contains at least a README or similar)
  if [ ! -f "./opencode.json" ] && [ ! -d "./.opencode" ] && [ ! -f "./.claude/settings.json" ] && [ ! -d "./.claude" ]; then
    warn "No recognized project files found in $(pwd)"
    say "Ciel installs files into your project. Run this from your project root."
    say "If this is your project root, you can continue anyway."
    say "Project files Ciel looks for: opencode.json, .opencode/, .claude/"
    if [ "$DO_YES" = false ] && ! prompt_confirm "Continue anyway?" "n"; then
      say "Aborted."
      exit 0
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
detect_platforms() {
  local result=""
  # Detect by project files
  if [ -f "./opencode.json" ] || [ -d "./.opencode" ]; then
    result="opencode"
  elif command -v opencode &>/dev/null; then
    result="opencode"
  fi
  if [ -f "./.claude/settings.json" ] || [ -d "./.claude/agents" ] || [ -d "./.claude" ]; then
    result="${result} claude"
  elif command -v claude &>/dev/null; then
    result="${result} claude"
  fi
  if [ -z "$result" ]; then
    echo "unknown"
  else
    # Remove leading space and remove duplicates
    echo "$result" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/^ *//;s/ *$//'
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
  # Gracefully skip 404 — some files exist only on one platform
  curl -fsSL "$GITHUB_RAW/$rel_path" -o "$dest" 2>/dev/null || {
    log "skip (404): $rel_path"
    return 0
  }
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
        download_if_needed "platforms/opencode/.opencode/plugins/ciel.ts"
        download_if_needed "platforms/opencode/.opencode/agents/ciel.md"
        download_if_needed "platforms/opencode/.opencode/agents/ciel-researcher.md"
        download_if_needed "platforms/opencode/.opencode/agents/ciel-explorer.md"
        download_if_needed "platforms/opencode/.opencode/agents/ciel-critic.md"
        download_if_needed "platforms/opencode/.opencode/agents/ciel-improver.md"
        for cmd in ciel-init ciel-update ciel-improve ciel-eval ciel-create-skill ciel-audit ciel-memory ciel-memory-init ciel-compile ciel-status; do
          download_if_needed "platforms/opencode/.opencode/commands/${cmd}.md"
        done
        ensure cp "$TMP_DIR/platforms/opencode/.opencode/plugins/ciel.ts" "$target_dir/.opencode/plugins/"
        ensure cp "$TMP_DIR/platforms/opencode/.opencode/agents/"*.md "$target_dir/.opencode/agents/"
        ensure cp "$TMP_DIR/platforms/opencode/.opencode/commands/"*.md "$target_dir/.opencode/commands/"
      elif [ "$SRC_DIR" = "$target_dir" ]; then
        # Self-install (running installer from inside the Ciel source repo).
        # All targets are the source — `cp -f src src` errors with `same file`
        # under `set -e`. Skip the copy step; the files are already in place.
        log "opencode: self-install detected, skipping cp"
        skipped+=("plugin" "agents" "commands")
      else
        local OPENCODE_SRC="$SRC_DIR/platforms/opencode/.opencode"
        cp $CP_FLAG "$OPENCODE_SRC/plugins/ciel.ts" "$target_dir/.opencode/plugins/" 2>/dev/null && \
          installed+=("plugin") || skipped+=("plugin")
        cp $CP_FLAG "$OPENCODE_SRC/agents/"*.md "$target_dir/.opencode/agents/" 2>/dev/null && \
          installed+=("agents") || skipped+=("agents")
        cp $CP_FLAG "$OPENCODE_SRC/commands/"*.md "$target_dir/.opencode/commands/" 2>/dev/null && \
          installed+=("commands") || skipped+=("commands")
      fi
      log "opencode: installed=${installed[*]}, skipped=${skipped[*]}"

      # AGENTS.md (from platform template)
      if [ ! -f "$target_dir/AGENTS.md" ]; then
        if $CURL_MODE; then
          download_if_needed "platforms/opencode/AGENTS.md"
          ensure cp "$TMP_DIR/platforms/opencode/AGENTS.md" "$target_dir/AGENTS.md"
        elif [ "$SRC_DIR" != "$target_dir" ]; then
          ensure cp "$SRC_DIR/platforms/opencode/AGENTS.md" "$target_dir/AGENTS.md"
        fi
        installed+=("AGENTS.md")
      else
        skipped+=("AGENTS.md")
      fi

      # opencode.json config with agent definitions
      local cfg="$target_dir/opencode.json"
      if [ ! -f "$cfg" ]; then
        python3 - "$cfg" <<'PY'
import json, os, sys
target = sys.argv[1]
data = {
    "$schema": "https://opencode.ai/config.json",
    "instructions": ["AGENTS.md"],
    "plugin": ["./.opencode/plugins/ciel.ts"],
    "permission": {
        "edit": "allow",
        "bash": "allow",
        "webfetch": "allow",
        "websearch": "allow",
        "question": "allow",
        "skill": "allow"
    },
    "agent": {
        "ciel": {
            "description": "Ciel v5 — Primary orchestrator. Full pipeline. Dispatch subagents. Depth: Trivial/Standard/Critical.",
            "mode": "primary",
            "prompt": "{file:./.opencode/agents/ciel.md}",
            "temperature": 0.2,
            "permission": {
                "edit": "allow",
                "bash": "allow",
                "question": "allow",
                "skill": "allow",
                "task": {
                    "*": "deny",
                    "ciel-researcher": "allow",
                    "ciel-explorer": "allow",
                    "ciel-critic": "allow",
                    "ciel-improver": "allow"
                }
            }
        },
        "ciel-researcher": {
            "description": "RECHERCHE — docs officielles, anti-patterns. WebFetch + WebSearch.",
            "mode": "subagent",
            "prompt": "{file:./.opencode/agents/ciel-researcher.md}",
            "temperature": 0.1,
            "permission": {
                "read": "allow", "glob": "allow", "grep": "allow",
                "bash": "allow", "webfetch": "allow", "websearch": "allow",
                "write": "deny", "edit": "deny"
            }
        },
        "ciel-explorer": {
            "description": "CODEBASE + FLUX — pattern-fitness, data flow narration.",
            "mode": "subagent",
            "prompt": "{file:./.opencode/agents/ciel-explorer.md}",
            "temperature": 0.1,
            "permission": {
                "read": "allow", "glob": "allow", "grep": "allow",
                "bash": "allow",
                "write": "deny", "edit": "deny"
            }
        },
        "ciel-critic": {
            "description": "RELIRE/CRITIQUER/RCA — hostile review, root-cause analysis.",
            "mode": "subagent",
            "prompt": "{file:./.opencode/agents/ciel-critic.md}",
            "temperature": 0.1,
            "permission": {
                "read": "allow", "glob": "allow", "grep": "allow",
                "bash": "allow",
                "write": "deny", "edit": "deny"
            }
        },
        "ciel-improver": {
            "description": "Méta-amélioration Ciel — analyse sessions, skill patches.",
            "mode": "subagent",
            "prompt": "{file:./.opencode/agents/ciel-improver.md}",
            "temperature": 0.1,
            "permission": {
                "read": "allow", "glob": "allow", "grep": "allow",
                "bash": "allow", "webfetch": "allow", "websearch": "allow",
                "write": "ask", "edit": "ask"
            }
        }
    }
}
os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
with open(target, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
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
      # Safely create dirs — any parent that is a file blocks mkdir -p
      # Check each target AND its parent paths
      for d in "$target_dir/.claude" "$target_dir/.claude/agents" "$target_dir/.claude/hooks" "$target_dir/.claude/commands" "$target_dir/.claude/skills" "$target_dir/.claude/skills/ciel"; do
        if [ -f "$d" ]; then
          warn "Removing file $d (blocking directory creation)"
          rm -f "$d" 2>/dev/null || true
        fi
      done
      ensure mkdir -p "$target_dir/.claude/agents" "$target_dir/.claude/hooks" "$target_dir/.claude/commands" "$target_dir/.claude/skills/ciel"

      if $CURL_MODE; then
        for agent in ciel-researcher ciel-explorer ciel-critic ciel-improver; do
          download_if_needed ".claude/agents/${agent}.md"
        done
        # All hooks are downloaded from hooks/ (repo root, tracked by git).
        # .claude/hooks/ is gitignored and NOT available on GitHub — using it causes 404s.
        # Shared hooks (memory-engine, user-prompt-submit, session-start, memory-bootstrap)
        # live alongside platform hooks in the same hooks/ directory.
        for hook in block-destructive.sh track-file.sh track-verification.sh check-dispatch-gate.sh pre-agent-gate.sh pre-tool-write.sh stop.sh subagent-stop.sh user-prompt-submit.sh memory-bootstrap.sh memory-engine.py session-start.sh ciel_stats.py; do
          curl -fsSL "$GITHUB_RAW/hooks/${hook}" -o "$TMP_DIR/.claude/hooks/${hook}" 2>/dev/null || warn "Missing: hooks/${hook}"
        done
        # NOTE: ciel.md is NOT copied — /ciel is handled by the skill (skills/ciel/SKILL.md)
        # ciel-improve is OpenCode-only (.opencode/commands/), not available as generic command
        for cmd in ciel-init ciel-update ciel-eval ciel-create-skill ciel-audit ciel-memory ciel-memory-init ciel-compile ciel-status; do
          download_if_needed "commands/${cmd}.md"
        done
        download_if_needed ".claude/settings.json"
        download_if_needed "CLAUDE.md"
        # Ciel skill (/ciel command on Claude Code) — skip if file not on CDN
        download_if_needed "skills/ciel/SKILL.md"
        download_if_needed "skills/ciel/reference.md"
        [ -f "$TMP_DIR/skills/ciel/SKILL.md" ] && cp "$TMP_DIR/skills/ciel/SKILL.md" "$target_dir/.claude/skills/ciel/SKILL.md" || true
        [ -f "$TMP_DIR/skills/ciel/reference.md" ] && cp "$TMP_DIR/skills/ciel/reference.md" "$target_dir/.claude/skills/ciel/reference.md" || true
        # ── Skills (curl mode) ───────────────────────────────────────────
        # Mirrored to .claude/skills/<group>/<name>/SKILL.md for auto-discovery.
        # WARNING: these lists MUST stay in sync with tracked files in skills/.
        # Run `git ls-files skills/ | grep SKILL.md` and `.claude/rules/` to verify.
        # Local-mode installs use `find` and are always in sync dynamically.

        # Domain skills (14 — skills/domain/<name>/SKILL.md)
        for skill in accessibility-wcag-auditor api-architecture backend-mastery cicd-pipeline-designer cicd-security-hardener database-mastery frontend-mastery mcp-configurator observability performance-engineering refactoring-patterns security-hardening test-writing ts-js-patterns; do
          download_if_needed "skills/domain/${skill}/SKILL.md"
          if [ -f "$TMP_DIR/skills/domain/${skill}/SKILL.md" ]; then
            mkdir -p "$target_dir/.claude/skills/domain/${skill}"
            cp "$TMP_DIR/skills/domain/${skill}/SKILL.md" "$target_dir/.claude/skills/domain/${skill}/SKILL.md"
          fi
        done

        # Workflow skills (29 — skills/workflow/<name>/SKILL.md)
        for skill in adr-auto ai-failure-modes-detector ask-window avec-quoi-versioner ci-watcher ciel-dev-process critiquer-auditor debug-reasoning-rca depth-classifier diverge doc-validator-official evaluer-sizer faire-gatekeeper flux-narrator memoire memoire-consolidator meta-critiquer modern-patterns-checker pattern-fitness-check playwright-visual-critic pr-review-responder prouver-verifier quoi-framer relire-critic security-regression-check self-consistency-verifier spike-mode stride-analyzer test-strategy-vitest-playwright; do
          download_if_needed "skills/workflow/${skill}/SKILL.md"
          if [ -f "$TMP_DIR/skills/workflow/${skill}/SKILL.md" ]; then
            mkdir -p "$target_dir/.claude/skills/workflow/${skill}"
            cp "$TMP_DIR/skills/workflow/${skill}/SKILL.md" "$target_dir/.claude/skills/workflow/${skill}/SKILL.md"
          fi
        done

        # Meta skills (6 — skills/meta/<name>/SKILL.md)
        for skill in ciel-improve learnings-capture skill-creator skill-freshness-auditor skill-variant-evaluator skills-first-design-auditor; do
          download_if_needed "skills/meta/${skill}/SKILL.md"
          if [ -f "$TMP_DIR/skills/meta/${skill}/SKILL.md" ]; then
            mkdir -p "$target_dir/.claude/skills/meta/${skill}"
            cp "$TMP_DIR/skills/meta/${skill}/SKILL.md" "$target_dir/.claude/skills/meta/${skill}/SKILL.md"
          fi
        done

        # Utility skills (9 — skills/utility/<name>/SKILL.md)
        for skill in branch-cleaner branch-setup changelog-updater commit-writer issue-closer issue-creator pr-merger pr-opener release-publisher; do
          download_if_needed "skills/utility/${skill}/SKILL.md"
          if [ -f "$TMP_DIR/skills/utility/${skill}/SKILL.md" ]; then
            mkdir -p "$target_dir/.claude/skills/utility/${skill}"
            cp "$TMP_DIR/skills/utility/${skill}/SKILL.md" "$target_dir/.claude/skills/utility/${skill}/SKILL.md"
          fi
        done

        # Research skills (6 — skills/research/<name>/SKILL.md)
        for skill in fact-check-claims research-forums research-github-issues research-web-sources synthesize-findings validate-source-credibility; do
          download_if_needed "skills/research/${skill}/SKILL.md"
          if [ -f "$TMP_DIR/skills/research/${skill}/SKILL.md" ]; then
            mkdir -p "$target_dir/.claude/skills/research/${skill}"
            cp "$TMP_DIR/skills/research/${skill}/SKILL.md" "$target_dir/.claude/skills/research/${skill}/SKILL.md"
          fi
        done

        # Rules — auto-inject on matching file paths via .claude/rules/
        # Only 2 rules exist (security, testing). Kept as explicit list so missing
        # rules are noticed rather than silently skipped.
        mkdir -p "$target_dir/.claude/rules"
        for rule in security testing; do
          download_if_needed ".claude/rules/${rule}.md"
          [ -f "$TMP_DIR/.claude/rules/${rule}.md" ] && cp "$TMP_DIR/.claude/rules/${rule}.md" "$target_dir/.claude/rules/${rule}.md" || true
        done
        ensure cp "$TMP_DIR/.claude/agents/"*.md "$target_dir/.claude/agents/"
        ensure cp "$TMP_DIR/.claude/hooks/"*.sh "$target_dir/.claude/hooks/"
        [ -f "$TMP_DIR/.claude/hooks/memory-engine.py" ] && cp "$TMP_DIR/.claude/hooks/memory-engine.py" "$target_dir/.claude/hooks/" 2>/dev/null || true
        # Copy sub-commands only (/ciel is handled by skills/ciel/SKILL.md)
        # ciel-improve is OpenCode-only (.opencode/commands/), not available as generic command
        for cmd in ciel-init ciel-update ciel-eval ciel-create-skill ciel-audit ciel-memory ciel-memory-init ciel-compile ciel-status; do
          if [ -f "$TMP_DIR/commands/${cmd}.md" ]; then
            ensure cp "$TMP_DIR/commands/${cmd}.md" "$target_dir/.claude/commands/"
          fi
        done
        ensure cp "$TMP_DIR/.claude/settings.json" "$target_dir/.claude/settings.json"
        ensure cp "$TMP_DIR/CLAUDE.md" "$target_dir/CLAUDE.md"
      elif [ "$SRC_DIR" = "$target_dir" ]; then
        # Self-install (running installer from inside the Ciel source repo).
        # `cp -f src src` errors with `same file` under `set -e`; the files are
        # already in place so the copy step is a no-op anyway.
        log "claude: self-install detected, skipping cp"
        skipped+=("agents" "hooks" "commands" "skills" "settings.json" "CLAUDE.md")
      else
        cp $CP_FLAG "$SRC_DIR/.claude/agents/"*.md "$target_dir/.claude/agents/" 2>/dev/null && \
          installed+=("agents") || skipped+=("agents")
        # Copy all hooks from hooks/ (repo root, tracked by git).
        # .claude/hooks/ is gitignored and may not exist in a fresh clone —
        # hooks/ is the single source of truth.
        if [ -d "$SRC_DIR/hooks" ]; then
          cp $CP_FLAG "$SRC_DIR/hooks/"*.sh "$target_dir/.claude/hooks/" 2>/dev/null || true
          cp $CP_FLAG "$SRC_DIR/hooks/"*.py "$target_dir/.claude/hooks/" 2>/dev/null || true
          installed+=("hooks") || true
        else
          skipped+=("hooks")
        fi
        # Copy sub-commands only (/ciel is handled by skills/ciel/SKILL.md)
        # ciel-improve is OpenCode-only (.opencode/commands/), not available as generic command
        for cmd in ciel-init ciel-update ciel-eval ciel-create-skill ciel-audit ciel-memory ciel-memory-init ciel-compile ciel-status; do
          if [ -f "$SRC_DIR/commands/${cmd}.md" ]; then
            cp $CP_FLAG "$SRC_DIR/commands/${cmd}.md" "$target_dir/.claude/commands/" 2>/dev/null && \
              installed+=("${cmd}") || skipped+=("${cmd}")
          fi
        done
        # Install all skills (domain + workflow + research + meta + utility).
        # Flat skills live at skills/<name>/SKILL.md. Grouped skills (workflow,
        # research, meta, utility) live at skills/<group>/<name>/SKILL.md. Ciel
        # skill also copies reference.md.
        if [ -d "$SRC_DIR/skills" ]; then
          if [ -f "$target_dir/.claude/skills" ]; then rm -f "$target_dir/.claude/skills" 2>/dev/null || true; fi
          mkdir -p "$target_dir/.claude/skills"

          # Ciel skill — special case (copies reference.md too)
          if [ -f "$SRC_DIR/skills/ciel/SKILL.md" ]; then
            mkdir -p "$target_dir/.claude/skills/ciel"
            cp $CP_FLAG "$SRC_DIR/skills/ciel/SKILL.md" "$target_dir/.claude/skills/ciel/SKILL.md" 2>/dev/null || true
            cp $CP_FLAG "$SRC_DIR/skills/ciel/reference.md" "$target_dir/.claude/skills/ciel/reference.md" 2>/dev/null || true
          fi

          # All other skills — iterate source to discover both flat and grouped.
          # skills/<name>/SKILL.md          -> .claude/skills/<name>/SKILL.md
          # skills/<group>/<name>/SKILL.md  -> .claude/skills/<group>/<name>/SKILL.md
          for skill_src in $(find "$SRC_DIR/skills" -name "SKILL.md" -not -path "*/.legacy*" -not -path "*/ciel/*"); do
            [ -f "$skill_src" ] || continue
            rel="${skill_src#$SRC_DIR/skills/}"
            skill_dir="$(dirname "$rel")"
            mkdir -p "$target_dir/.claude/skills/${skill_dir}"
            cp $CP_FLAG "$skill_src" "$target_dir/.claude/skills/${skill_dir}/SKILL.md" 2>/dev/null || true
          done
          installed+=("skills")
        fi

        # Copy rules — auto-inject on matching file paths
        if [ -d "$SRC_DIR/.claude/rules" ]; then
          mkdir -p "$target_dir/.claude/rules"
          cp $CP_FLAG "$SRC_DIR/.claude/rules/"*.md "$target_dir/.claude/rules/" 2>/dev/null && \
            installed+=("rules") || skipped+=("rules")
        fi
        cp $CP_FLAG "$SRC_DIR/.claude/settings.json" "$target_dir/.claude/settings.json" 2>/dev/null && \
          installed+=("settings.json") || skipped+=("settings.json")
        cp $CP_FLAG "$SRC_DIR/CLAUDE.md" "$target_dir/CLAUDE.md" 2>/dev/null && \
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

    *)
      warn "Unknown platform: $name"
      ;;

    generic)
      warn "No recognized platform config found. Files installed at:"
      say "  $target_dir/.ciel/"
      installed+=(".ciel/")
      ;;
  esac

  # Always create .ciel/ directory
  ensure mkdir -p "$target_dir/.ciel"
  ensure mkdir -p "$target_dir/.ciel/memory/episodes"
  ensure mkdir -p "$target_dir/.ciel/memory/concepts"
  ensure mkdir -p "$target_dir/.ciel/memory/guards"
  touch "$target_dir/.ciel/parking.md"
  if [ ! -f "$target_dir/.ciel/map.json" ]; then
    printf '{"modules":[],"lastUpdated":""}\n' > "$target_dir/.ciel/map.json"
  fi
  if [ ! -f "$target_dir/.ciel/memory.json" ]; then
    printf '{}\n' > "$target_dir/.ciel/memory.json"
  fi
  # Version sentinel — read by hooks/session-start.sh at runtime so the banner
  # always reflects the installed version (no hardcoded MSG to drift).
  printf '%s\n' "$CIEL_VERSION" > "$target_dir/.ciel/version"
  # User-level sentinel too, so global plugin installs and CLI tools share the same source of truth.
  mkdir -p "$HOME/.ciel" 2>/dev/null || true
  printf '%s\n' "$CIEL_VERSION" > "$HOME/.ciel/version" 2>/dev/null || true
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
						say "5. npm update: npm update -g @neikyun/ciel (if CLI is globally installed)"
      ;;
  esac
}

# ============================================================
#  UNINSTALL
# ============================================================
do_uninstall() {
  header "Ciel v${CIEL_VERSION} — Uninstall"
  echo ""
  local count=0

  # SAFETY: never remove entire directories or platform config files.
  # Only remove Ciel-specific files. Removing .opencode/agents or
  # .opencode/commands would break OpenCode entirely.
  # Removing .claude/settings.json would break Claude Code.

  # Ciel state directory
  rm -rf "$HOME/.ciel" 2>/dev/null && { ok "~/.ciel/ removed"; ((count++)); } || true

  # OpenCode: Ciel plugin file only
  if [ -f ".opencode/plugins/ciel.ts" ]; then
    rm -f ".opencode/plugins/ciel.ts" 2>/dev/null && { ok ".opencode/plugins/ciel.ts removed"; ((count++)); } || true
  fi

  # OpenCode: Ciel agents only (not the whole directory)
  for agent in ciel.md ciel-researcher.md ciel-explorer.md ciel-critic.md ciel-improver.md; do
    if [ -f ".opencode/agents/$agent" ]; then
      rm -f ".opencode/agents/$agent" 2>/dev/null && { ok ".opencode/agents/$agent removed"; ((count++)); } || true
    fi
  done

  # OpenCode: Ciel commands only (not the whole directory)
  for cmd in ciel-*.md; do
    if [ -f ".opencode/commands/$cmd" ]; then
      rm -f ".opencode/commands/$cmd" 2>/dev/null && { ok ".opencode/commands/$cmd removed"; ((count++)); } || true
    fi
  done

  # Shared files
  for f in AGENTS.md CLAUDE.md; do
    if [ -f "$f" ]; then
      rm -f "$f" 2>/dev/null && { ok "$f removed"; ((count++)); } || true
    fi
  done

  # Claude Code: Ciel agents only
  for agent in ciel-researcher.md ciel-explorer.md ciel-critic.md ciel-improver.md; do
    if [ -f ".claude/agents/$agent" ]; then
      rm -f ".claude/agents/$agent" 2>/dev/null && { ok ".claude/agents/$agent removed"; ((count++)); } || true
    fi
  done

  # Claude Code: hooks (these are Ciel-specific files)
  for hook in check-test-first.sh block-destructive.sh track-file.sh meta-critiquer.sh; do
    if [ -f ".claude/hooks/$hook" ]; then
      rm -f ".claude/hooks/$hook" 2>/dev/null && { ok ".claude/hooks/$hook removed"; ((count++)); } || true
    fi
  done
  # Shared cued-recall hooks (deployed from hooks/ to .claude/hooks/ by install)
  for shared_hook in memory-bootstrap.sh session-start.sh user-prompt-submit.sh memory-engine.py; do
    if [ -f ".claude/hooks/$shared_hook" ]; then
      rm -f ".claude/hooks/$shared_hook" 2>/dev/null && { ok ".claude/hooks/$shared_hook removed"; ((count++)); } || true
    fi
  done

  # Claude Code: sub-commands only (/ciel is from skills/ciel/SKILL.md)
  # ciel-improve is OpenCode-only, not in .claude/commands/
  for cmd in ciel-init ciel-update ciel-eval ciel-create-skill ciel-audit ciel-memory ciel-memory-init ciel-compile ciel-status; do
    if [ -f ".claude/commands/${cmd}.md" ]; then
      rm -f ".claude/commands/${cmd}.md" 2>/dev/null && { ok ".claude/commands/${cmd}.md removed"; ((count++)); } || true
    fi
  done

  # Claude Code settings: remove Ciel hook entries from JSON instead of deleting the file
  if [ -f ".claude/settings.json" ] && command -v python3 &>/dev/null; then
    local tmp; tmp=$(mktemp)
    python3 -c "
import json, sys
with open('.claude/settings.json') as f:
    cfg = json.load(f)
hooks = cfg.get('hooks', {})
# Remove Ciel-specific hooks
for key in list(hooks.keys()):
    if isinstance(hooks[key], list):
        hooks[key] = [h for h in hooks[key] if 'ciel' not in json.dumps(h).lower()]
# If empty, remove the hooks key
if not hooks:
    cfg.pop('hooks', None)
with open('$tmp', 'w') as f:
    json.dump(cfg, f, indent=2)
" 2>/dev/null && mv "$tmp" ".claude/settings.json" && { ok ".claude/settings.json (Ciel hooks removed)"; ((count++)); } || true
  elif [ -f ".claude/settings.json" ]; then
    warn ".claude/settings.json preserved. Remove Ciel hooks manually."
  fi

  # opencode.json: remove Ciel plugin + instructions, keep rest
  if [ -f "opencode.json" ] && command -v jq &>/dev/null; then
    local tmp; tmp=$(mktemp)
    jq '.plugin = ((.plugin // []) | map(select(. != "./.opencode/plugins/ciel.ts"))) | .instructions = ((.instructions // []) | map(select(. != "AGENTS.md")))' opencode.json > "$tmp" && mv "$tmp" opencode.json && { ok "opencode.json (Ciel references removed)"; ((count++)); } || true
  elif [ -f "opencode.json" ]; then
    warn "opencode.json preserved. Remove Ciel plugin reference manually:"
    say "  jq '.plugin -= [\"./.opencode/plugins/ciel.ts\"] | .instructions -= [\"AGENTS.md\"]' opencode.json > tmp && mv tmp opencode.json"
  fi

  echo ""
  ok "${count} file(s) affected"
  say "Ciel has been uninstalled from this project."
  say "Restart your editor for changes to take effect."
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

  # Detect all platforms
  local PLATFORMS
  PLATFORMS=$(detect_platforms)
  log "platforms: $PLATFORMS"

  if [ "$PLATFORMS" = "unknown" ]; then
    # Even without project files, install at least generic files
    warn "No recognized platform config found."
    say "Installing shared files (.ciel/, AGENTS.md) — run from opencode project root for full install."
    PLATFORMS="generic"
  fi

  # Detect install mode (curl pipe vs local file)
  local CURL_MODE=false
  local SRC_DIR=""
  local TMP_DIR=""
  if is_curl_mode; then
    CURL_MODE=true
    TMP_DIR=$(mktemp -d)
    SRC_DIR="$TMP_DIR"
    trap "log 'cleanup: $TMP_DIR'; rm -rf '$TMP_DIR'" EXIT
    say "Downloading Ciel v${CIEL_VERSION}..."
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
    if ! prompt_confirm "Install Ciel v${CIEL_VERSION} in ${PROJECT_ROOT}?" "y"; then
      say "Aborted."
      exit 0
    fi
  fi

  # Install for ALL detected platforms
  if $DO_UPDATE; then
    say "Update mode — reinstalling all files..."
    # Clean up ~/CLAUDE.md if it was mistakenly installed at home directory.
    # Claude Code walks up to ~ and loads every CLAUDE.md it finds, so a file
    # there duplicates the project-level instructions in every session.
    if [ -f "$HOME/CLAUDE.md" ] && [ "$HOME" != "$(pwd)" ]; then
      warn "Found $HOME/CLAUDE.md — this causes duplicate Ciel instructions in all projects."
      rm -f "$HOME/CLAUDE.md" && ok "Removed $HOME/CLAUDE.md (stale global duplicate)"
    fi
  fi
  local p
  for p in $PLATFORMS; do
    log "installing for platform: $p"
    install_ciel_files "$PROJECT_ROOT" "$p"
    # Verify each platform
    verify_files "$PROJECT_ROOT" "$p"
  done

  # Summary — show all installed platforms
  echo ""
  for p in $PLATFORMS; do
    print_summary "$p" "$PROJECT_ROOT"
  done
  echo ""

  log "install complete (exit 0)"
}

main "$@"

} # <-- wrapper end
