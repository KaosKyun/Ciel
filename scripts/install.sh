#!/usr/bin/env bash
# Ciel Universal Installer v2
# Supports: Claude Code, Cursor, Windsurf, Codex CLI, OpenCode, Kilo Code, Ollama, LM Studio
# Usage: bash scripts/install.sh [project-root]
#        bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)

set -euo pipefail

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
ok()   { echo -e "  ${GREEN}v${RESET} $1"; }
info() { echo -e "  ${CYAN}>${RESET} $1"; }
warn() { echo -e "  ${YELLOW}!${RESET} $1"; }

# ─── Pipe/process-substitution detection ─────────────────────────────────────
# bash <(curl ...) sets BASH_SOURCE[0] to /dev/fd/N.
# Detect this BEFORE computing CIEL_DIR to avoid the broken path.
CIEL_DIR=""
if [[ "${BASH_SOURCE[0]}" != /dev/fd/* ]] && [[ "${BASH_SOURCE[0]}" != /proc/self/* ]]; then
  _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CIEL_DIR="$(cd "$_SCRIPT_DIR/.." && pwd)"
fi

if [ -z "$CIEL_DIR" ] || [ ! -f "$CIEL_DIR/settings.json" ]; then
  TEMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TEMP_DIR"' EXIT
  info "Pipe execution detected — cloning KaosKyun/Ciel to $TEMP_DIR ..."
  if ! git clone --depth=1 --quiet https://github.com/KaosKyun/Ciel.git "$TEMP_DIR" 2>/dev/null; then
    echo "ERROR: git clone failed."
    echo "Run manually: git clone https://github.com/KaosKyun/Ciel.git ~/.ciel && bash ~/.ciel/scripts/install.sh"
    exit 1
  fi
  CIEL_DIR="$TEMP_DIR"
fi

PROJECT_ROOT="${1:-$(pwd)}"
PLATFORMS_DIR="$CIEL_DIR/platforms"
PLUGIN_DIR="${CIEL_PLUGIN_DIR:-$HOME/.claude/plugins/ciel}"

# ─── Detect existing install ─────────────────────────────────────────────────
IS_UPDATE=false
[ -f "$PROJECT_ROOT/ciel-overlay.md" ] && IS_UPDATE=true

if $IS_UPDATE; then
  echo -e "\n${BOLD}Ciel Universal Installer v2${RESET} (${YELLOW}update detected${RESET})"
else
  echo -e "\n${BOLD}Ciel Universal Installer v2${RESET}"
fi
echo -e "Plugin : $CIEL_DIR"
echo -e "Project: $PROJECT_ROOT\n"

# ─── Stack detection (for overlay) ───────────────────────────────────────────
detect_skills() {
  local root="$1"; local skills=()
  [ -f "$root/package.json" ] && grep -qE '"react"|"vue"|"svelte"' "$root/package.json" 2>/dev/null && skills+=("frontend-mastery")
  { [ -f "$root/build.gradle.kts" ] || [ -f "$root/build.gradle" ] || find "$root" -name "build.gradle.kts" -maxdepth 3 2>/dev/null | grep -q .; } && skills+=("backend-mastery")
  { [ -f "$root/requirements.txt" ] || [ -f "$root/pyproject.toml" ] || [ -f "$root/go.mod" ] || [ -f "$root/Cargo.toml" ]; } && skills+=("backend-mastery")
  { [ -d "$root/supabase/migrations" ] || [ -d "$root/prisma" ] || find "$root" -name "*.sql" -maxdepth 4 2>/dev/null | grep -q .; } && skills+=("database-mastery")
  find "$root" -type d \( -name "auth" -o -name "security" \) -maxdepth 5 2>/dev/null | grep -q . && skills+=("security-hardening")
  printf '%s\n' "${skills[@]}" | sort -u
}

# Remove old Ciel files from a directory (only ciel-* prefixed files, safe for user's own files)
_purge_ciel_files() {
  local dir="$1" pattern="${2:-ciel*}"
  if [ -d "$dir" ]; then
    find "$dir" -maxdepth 1 -name "$pattern" -type f -delete 2>/dev/null
  fi
}

_install_overlay() {
  if [ ! -f "$PROJECT_ROOT/ciel-overlay.md" ]; then
    cp "$CIEL_DIR/overlay-template.md" "$PROJECT_ROOT/ciel-overlay.md"
    warn "Created ciel-overlay.md — fill in your stack versions and CI config"
  fi
}

# ─── Purge any existing manual install ───────────────────────────────────────
# Prevents duplicate /ciel entries when reinstalling or upgrading.
# Does NOT touch settings.json (hooks stay in place).
_purge_manual_install() {
  info "Purging existing Ciel install..."

  # Skill
  if [ -d "$HOME/.claude/skills/ciel" ]; then
    rm -rf "$HOME/.claude/skills/ciel"
    ok "Removed ~/.claude/skills/ciel/"
  fi

  # Commands (ciel.md, ciel-update.md, ciel-recommend.md, ...)
  if [ -d "$HOME/.claude/commands" ]; then
    find "$HOME/.claude/commands" -name "ciel*.md" -delete 2>/dev/null
    ok "Removed ciel commands"
  fi

  # Agents (researcher, explorer, critic — Ciel-specific)
  for agent in researcher explorer critic; do
    rm -f "$HOME/.claude/agents/$agent.md" 2>/dev/null || true
  done
  ok "Removed ciel agents"

  # Plugin hooks dir — will be re-created
  if [ -d "$HOME/.claude/plugins/ciel" ]; then
    rm -rf "$HOME/.claude/plugins/ciel"
    ok "Removed ~/.claude/plugins/ciel/"
  fi
}

# ─── Platform installers ──────────────────────────────────────────────────────
install_claude() {
  info "Claude Code..."

  # Always purge first to avoid duplicate skill/command entries
  _purge_manual_install

  if command -v claude &>/dev/null && claude plugin install "$CIEL_DIR" 2>/dev/null; then
    ok "Installed via claude plugin install (full plugin)"
    _claude_hooks
    _install_overlay
    return
  fi

  info "Falling back to manual install..."

  mkdir -p "$HOME/.claude/skills"
  cp -r "$CIEL_DIR/skills/ciel" "$HOME/.claude/skills/"
  ok "skills/ciel -> ~/.claude/skills/ciel/"

  mkdir -p "$HOME/.claude/agents"
  cp "$CIEL_DIR/agents/"*.md "$HOME/.claude/agents/" 2>/dev/null && ok "agents/ -> ~/.claude/agents/"

  mkdir -p "$HOME/.claude/commands"
  cp "$CIEL_DIR/commands/"*.md "$HOME/.claude/commands/" 2>/dev/null && ok "commands/ -> ~/.claude/commands/"

  local MANUAL_PLUGIN_DIR="$HOME/.claude/plugins/ciel"
  mkdir -p "$MANUAL_PLUGIN_DIR/hooks"
  cp -r "$CIEL_DIR/hooks" "$MANUAL_PLUGIN_DIR/"
  cp "$CIEL_DIR/overlay-template.md" "$MANUAL_PLUGIN_DIR/"
  ok "hooks/ -> ~/.claude/plugins/ciel/hooks/"
  _claude_hooks
  _install_overlay
}

_claude_hooks() {
  local hooks_dir="$HOME/.claude/plugins/ciel/hooks"
  [ -d "$hooks_dir" ] && chmod +x "$hooks_dir/"*.sh 2>/dev/null && ok "Hooks set executable"

  local settings="$HOME/.claude/settings.json"
  if [ ! -f "$settings" ]; then
    cp "$CIEL_DIR/settings.json" "$settings"
    ok "settings.json created with Ciel hooks"
  else
    if grep -q "pre-write-gate" "$settings" 2>/dev/null; then
      ok "Hooks already in settings.json"
    else
      warn "settings.json exists — merge hooks manually from $CIEL_DIR/settings.json"
    fi
  fi
}

install_cursor() {
  info "Cursor..."
  mkdir -p "$PROJECT_ROOT/.cursor/rules"
  cp "$PLATFORMS_DIR/cursor/.cursor/rules/ciel.mdc" "$PROJECT_ROOT/.cursor/rules/ciel.mdc"
  ok "Copied .cursor/rules/ciel.mdc (4KB — under 6KB limit)"
  _install_overlay
}

install_windsurf() {
  info "Windsurf..."
  mkdir -p "$PROJECT_ROOT/.windsurf/rules"
  cp "$PLATFORMS_DIR/windsurf/.windsurf/rules/ciel.md" "$PROJECT_ROOT/.windsurf/rules/ciel.md"
  ok "Copied .windsurf/rules/ciel.md (under 6KB limit)"
  _install_overlay
}

install_codex() {
  info "Codex CLI..."
  cp "$PLATFORMS_DIR/codex/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
  ok "Copied AGENTS.md (full workflow, ~27KB, under 32KB limit)"
  _install_overlay
}

install_opencode() {
  info "OpenCode..."
  _purge_ciel_files "$PROJECT_ROOT/.opencode/agents" "ciel-*.md"
  cp "$PLATFORMS_DIR/opencode/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
  ok "Copied AGENTS.md"
  if [ ! -f "$PROJECT_ROOT/opencode.json" ]; then
    cp "$PLATFORMS_DIR/opencode/opencode.json" "$PROJECT_ROOT/opencode.json"
    ok "Copied opencode.json"
  else
    warn "opencode.json exists — merge /ciel command manually if needed"
  fi
  # Install Ciel agents (auto-discovered by OpenCode from .opencode/agents/)
  mkdir -p "$PROJECT_ROOT/.opencode/agents"
  cp "$PLATFORMS_DIR/opencode/.opencode/agents/"*.md "$PROJECT_ROOT/.opencode/agents/"
  ok "Copied .opencode/agents/ciel-{researcher,explorer,critic}.md"
  _install_overlay
}

install_kilocode() {
  info "Kilo Code..."
  _purge_ciel_files "$PROJECT_ROOT/.kilocode/rules" "ciel*.md"
  _purge_ciel_files "$PROJECT_ROOT/.kilo/agents" "ciel-*.md"
  # Workflow rules (legacy path — auto-loaded without kilo.jsonc)
  mkdir -p "$PROJECT_ROOT/.kilocode/rules"
  cp "$PLATFORMS_DIR/kilocode/.kilocode/rules/ciel.md" "$PROJECT_ROOT/.kilocode/rules/ciel.md"
  ok "Copied .kilocode/rules/ciel.md"
  # Install Ciel agents (auto-discovered by Kilo Code from .kilo/agents/)
  mkdir -p "$PROJECT_ROOT/.kilo/agents"
  cp "$PLATFORMS_DIR/kilocode/.kilo/agents/"*.md "$PROJECT_ROOT/.kilo/agents/"
  ok "Copied .kilo/agents/ciel-{researcher,explorer,critic}.md"
  _install_overlay
}

install_ollama() {
  info "Ollama..."
  local TARGET="$HOME/.ciel/ollama"
  mkdir -p "$TARGET"
  cp "$PLATFORMS_DIR/ollama/Modelfile" "$TARGET/Modelfile"
  ok "Copied Modelfile to $TARGET/"
  echo ""
  echo "    Next steps:"
  echo "    1. Edit $TARGET/Modelfile — change FROM line to your preferred model"
  echo "    2. ollama create ciel -f $TARGET/Modelfile"
  echo "    3. ollama run ciel"
}

install_lmstudio() {
  info "LM Studio..."
  local TARGET="$HOME/.ciel/lmstudio"
  mkdir -p "$TARGET"
  cp "$PLATFORMS_DIR/lmstudio/system-prompt.md" "$TARGET/system-prompt.md"
  ok "Copied system-prompt.md to $TARGET/"
  echo ""
  echo "    Next step: copy the prompt from $TARGET/system-prompt.md"
  echo "    into LM Studio -> Settings -> System Prompt -> Save preset 'Ciel'"
}

# ─── Platform detection ───────────────────────────────────────────────────────
declare -A DETECTED=()
command -v claude &>/dev/null && DETECTED[claude]="Claude Code CLI"
{ [ -d "$PROJECT_ROOT/.cursor" ] || command -v cursor &>/dev/null; } && DETECTED[cursor]="Cursor IDE"
{ [ -d "$PROJECT_ROOT/.windsurf" ] || command -v windsurf &>/dev/null; } && DETECTED[windsurf]="Windsurf IDE"
command -v codex &>/dev/null && DETECTED[codex]="Codex CLI"
command -v opencode &>/dev/null && DETECTED[opencode]="OpenCode CLI"
{ [ -d "$PROJECT_ROOT/.kilocode" ] || \
  (command -v code &>/dev/null && code --list-extensions 2>/dev/null | grep -qi "kilocode"); } \
  && DETECTED[kilocode]="Kilo Code"
command -v ollama &>/dev/null && DETECTED[ollama]="Ollama"
{ command -v lms &>/dev/null || [ -d "$HOME/.lmstudio" ]; } && DETECTED[lmstudio]="LM Studio"

# ─── User selection ───────────────────────────────────────────────────────────
if [ ${#DETECTED[@]} -eq 0 ]; then
  warn "No supported AI tool detected automatically."
  echo "  Available platforms: claude cursor windsurf codex opencode kilocode ollama lmstudio"
  read -rp "  Platforms to install (space-separated or 'all'): " RAW
  [ "$RAW" = "all" ] && RAW="claude cursor windsurf codex opencode kilocode ollama lmstudio"
  IFS=' ' read -ra PLATFORMS <<< "$RAW"
else
  # Build indexed array for selection
  DETECTED_KEYS=("${!DETECTED[@]}")
  DETECTED_COUNT=${#DETECTED_KEYS[@]}

  echo -e "${BOLD}Detected:${RESET}"
  for i in "${!DETECTED_KEYS[@]}"; do
    local_key="${DETECTED_KEYS[$i]}"
    echo -e "  ${CYAN}[$((i+1))]${RESET} ${DETECTED[$local_key]} ${YELLOW}[$local_key]${RESET}"
  done
  echo ""
  read -rp "  Install? [A]ll / numbers (e.g. 1,3) / [L]ist keys / [Q]uit: " ANS
  ANS="${ANS:-A}"

  if [[ "$ANS" =~ ^[AaYy]$ ]]; then
    PLATFORMS=("${DETECTED_KEYS[@]}")
  elif [[ "$ANS" =~ ^[Qq]$ ]]; then
    echo -e "\n${BOLD}Aborted.${RESET}"
    exit 0
  elif [[ "$ANS" =~ ^[Ll] ]]; then
    echo "  Keys: ${DETECTED_KEYS[*]}"
    read -rp "  Platforms to install (space/comma-separated): " RAW
    IFS=' ,' read -ra PLATFORMS <<< "$RAW"
  elif [[ "$ANS" =~ ^[0-9,\ ]+$ ]]; then
    # Number selection: "1,3" or "1 3" or "2"
    IFS=', ' read -ra NUMS <<< "$ANS"
    PLATFORMS=()
    for n in "${NUMS[@]}"; do
      idx=$((n - 1))
      if [ "$idx" -ge 0 ] && [ "$idx" -lt "$DETECTED_COUNT" ]; then
        PLATFORMS+=("${DETECTED_KEYS[$idx]}")
      else
        warn "Invalid number: $n (expected 1-$DETECTED_COUNT)"
      fi
    done
  else
    # Treat as space/comma-separated platform keys
    IFS=' ,' read -ra PLATFORMS <<< "$ANS"
  fi
fi

echo ""

# ─── Run ──────────────────────────────────────────────────────────────────────
INSTALLED=()
for p in "${PLATFORMS[@]}"; do
  case "$p" in
    claude)   install_claude   && INSTALLED+=(claude)   ;;
    cursor)   install_cursor   && INSTALLED+=(cursor)   ;;
    windsurf) install_windsurf && INSTALLED+=(windsurf) ;;
    codex)    install_codex    && INSTALLED+=(codex)    ;;
    opencode) install_opencode && INSTALLED+=(opencode) ;;
    kilocode) install_kilocode && INSTALLED+=(kilocode) ;;
    ollama)   install_ollama   && INSTALLED+=(ollama)   ;;
    lmstudio) install_lmstudio && INSTALLED+=(lmstudio) ;;
    *)        warn "Unknown platform '$p' — skipping" ;;
  esac
  echo ""
done

# ─── Stack detection summary ──────────────────────────────────────────────────
if [ -d "$PLUGIN_DIR" ] && [ -f "$PLUGIN_DIR/overlay-template.md" ]; then
  DETECTED_SKILLS=$(detect_skills "$PROJECT_ROOT")
  if [ -n "$DETECTED_SKILLS" ]; then
    echo -e "  Stack detected: $(echo "$DETECTED_SKILLS" | tr '\n' ' ')"
  fi
fi

echo -e "${BOLD}Done.${RESET} Installed: ${INSTALLED[*]:-none}"
echo ""
echo "Edit ciel-overlay.md to set stack versions, CI config, and project rules."
echo "Full docs: https://github.com/KaosKyun/Ciel"
