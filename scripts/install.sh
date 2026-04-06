#!/usr/bin/env bash
# Ciel Universal Installer v2
# Supports: Claude Code, Cursor, Windsurf, Codex CLI, OpenCode, Kilo Code, Ollama, LM Studio
# Usage: bash scripts/install.sh [project-root]

set -euo pipefail

CIEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${1:-$(pwd)}"
PLATFORMS_DIR="$CIEL_DIR/platforms"
PLUGIN_DIR="${CIEL_PLUGIN_DIR:-$HOME/.claude/plugins/ciel}"

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
info() { echo -e "  ${CYAN}→${RESET} $1"; }
warn() { echo -e "  ${YELLOW}!${RESET} $1"; }

echo -e "\n${BOLD}Ciel Universal Installer v2${RESET}"
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

_install_overlay() {
  if [ ! -f "$PROJECT_ROOT/ciel-overlay.md" ]; then
    cp "$CIEL_DIR/overlay-template.md" "$PROJECT_ROOT/ciel-overlay.md"
    warn "Created ciel-overlay.md — fill in your stack versions and CI config"
  fi
}

# ─── Platform installers ──────────────────────────────────────────────────────
install_claude() {
  info "Claude Code..."
  if command -v claude &>/dev/null; then
    claude plugin install "$CIEL_DIR" 2>/dev/null \
      && ok "Installed via claude plugin install" \
      || { mkdir -p "$HOME/.claude/skills"; cp -r "$CIEL_DIR/skills/ciel" "$HOME/.claude/skills/" && ok "Copied to ~/.claude/skills/ciel"; }
  else
    mkdir -p "$HOME/.claude/skills"
    cp -r "$CIEL_DIR/skills/ciel" "$HOME/.claude/skills/"
    ok "Copied to ~/.claude/skills/ciel"
  fi
  # Hooks
  if [ -d "$PLUGIN_DIR/hooks" ]; then
    chmod +x "$PLUGIN_DIR/hooks/"*.sh 2>/dev/null || true
    ok "Hooks executable"
  fi
  _install_overlay
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
  cp "$PLATFORMS_DIR/opencode/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
  ok "Copied AGENTS.md"
  if [ ! -f "$PROJECT_ROOT/opencode.json" ]; then
    cp "$PLATFORMS_DIR/opencode/opencode.json" "$PROJECT_ROOT/opencode.json"
    ok "Copied opencode.json"
  else
    warn "opencode.json exists — add AGENTS.md to the instructions array manually"
  fi
  _install_overlay
}

install_kilocode() {
  info "Kilo Code..."
  mkdir -p "$PROJECT_ROOT/.kilocode/rules"
  cp "$PLATFORMS_DIR/kilocode/.kilocode/rules/ciel.md" "$PROJECT_ROOT/.kilocode/rules/ciel.md"
  ok "Copied .kilocode/rules/ciel.md"
  _install_overlay
}

install_ollama() {
  info "Ollama..."
  TARGET="$HOME/.ciel/ollama"
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
  TARGET="$HOME/.ciel/lmstudio"
  mkdir -p "$TARGET"
  cp "$PLATFORMS_DIR/lmstudio/system-prompt.md" "$TARGET/system-prompt.md"
  ok "Copied system-prompt.md to $TARGET/"
  echo ""
  echo "    Next step: copy the prompt from $TARGET/system-prompt.md"
  echo "    into LM Studio → Settings → System Prompt → Save preset 'Ciel'"
}

# ─── Platform detection ───────────────────────────────────────────────────────
declare -A DETECTED=()
command -v claude &>/dev/null                                                                              && DETECTED[claude]="Claude Code CLI"
{ [ -d "$PROJECT_ROOT/.cursor" ] || command -v cursor &>/dev/null; }                                      && DETECTED[cursor]="Cursor IDE"
{ [ -d "$PROJECT_ROOT/.windsurf" ] || command -v windsurf &>/dev/null; }                                  && DETECTED[windsurf]="Windsurf IDE"
command -v codex &>/dev/null                                                                               && DETECTED[codex]="Codex CLI"
command -v opencode &>/dev/null                                                                            && DETECTED[opencode]="OpenCode CLI"
{ [ -d "$PROJECT_ROOT/.kilocode" ] || (command -v code &>/dev/null && code --list-extensions 2>/dev/null | grep -qi "kilocode"); } \
                                                                                                           && DETECTED[kilocode]="Kilo Code"
command -v ollama &>/dev/null                                                                              && DETECTED[ollama]="Ollama"
{ command -v lms &>/dev/null || [ -d "$HOME/.lmstudio" ]; }                                               && DETECTED[lmstudio]="LM Studio"

# ─── User selection ───────────────────────────────────────────────────────────
if [ ${#DETECTED[@]} -eq 0 ]; then
  warn "No supported AI tool detected automatically."
  echo "  Available platforms: claude cursor windsurf codex opencode kilocode ollama lmstudio"
  read -rp "  Platforms to install (space-separated or 'all'): " RAW
  [ "$RAW" = "all" ] && RAW="claude cursor windsurf codex opencode kilocode ollama lmstudio"
  IFS=' ' read -ra PLATFORMS <<< "$RAW"
else
  echo -e "${BOLD}Detected:${RESET}"
  for k in "${!DETECTED[@]}"; do echo "  • ${DETECTED[$k]} [$k]"; done
  echo ""
  read -rp "  Install all detected? [Y/n/list]: " ANS
  ANS="${ANS:-Y}"
  if [[ "$ANS" =~ ^[Yy]$ ]]; then
    PLATFORMS=("${!DETECTED[@]}")
  else
    IFS=' ' read -ra PLATFORMS <<< "$ANS"
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

# ─── Legacy Claude Code: overlay + hooks (always run if PLUGIN_DIR exists) ───
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
