#!/usr/bin/env bash
# Ciel Universal Installer v2.1.0
# Supports: Claude Code, Cursor, Windsurf, Codex CLI, OpenCode, Kilo Code, Ollama, LM Studio
# Usage: bash scripts/install.sh [project-root] [flags]
#        bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
#
# Flags:
#   --uninstall         Remove all files tracked in ~/.ciel/manifest.json
#   --check-update      Query GitHub for newer VERSION and report
#   --update            Uninstall + re-install latest from main
#   --with-mcp=LIST     Register MCP servers from .mcp.json (CSV: playwright,context7)
#   -y, --yes           Skip interactive confirmations
#
# v2.1.0 changes:
#   - 10 new skills (debug-reasoning-rca, doc-validator-official, modern-patterns-checker,
#     ai-failure-modes-detector, self-consistency-verifier, test-strategy-vitest-playwright,
#     playwright-visual-critic, cicd-security-hardener, accessibility-wcag-auditor,
#     skills-first-design-auditor) — 46 total
#   - ~/.ciel/manifest.json tracks installed files → enables clean --uninstall
#   - --update / --check-update against github main VERSION
#   - --with-mcp=playwright,context7 registers opt-in MCP servers into project .mcp.json

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

# ─── Flag parsing ────────────────────────────────────────────────────────────
FLAG_UNINSTALL=false
FLAG_CHECK_UPDATE=false
FLAG_UPDATE=false
FLAG_YES=false
MCP_LIST=""
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --uninstall)    FLAG_UNINSTALL=true ;;
    --check-update) FLAG_CHECK_UPDATE=true ;;
    --update)       FLAG_UPDATE=true ;;
    --with-mcp=*)   MCP_LIST="${arg#*=}" ;;
    -y|--yes)       FLAG_YES=true ;;
    -h|--help)
      sed -n '1,20p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    -*) warn "Unknown flag: $arg (see --help)" ;;
    *)  POSITIONAL+=("$arg") ;;
  esac
done

PROJECT_ROOT="${POSITIONAL[0]:-$(pwd)}"
PLATFORMS_DIR="$CIEL_DIR/platforms"
PLUGIN_DIR="${CIEL_PLUGIN_DIR:-$HOME/.claude/plugins/ciel}"

# ─── Manifest helpers (track installed files for clean uninstall) ────────────
INSTALLED_FILES=()
_manifest_path() { echo "$HOME/.ciel/manifest.json"; }
_manifest_append_file() { INSTALLED_FILES+=("$1"); }

_manifest_read_version() {
  local manifest; manifest="$(_manifest_path)"
  [ -f "$manifest" ] || return 1
  grep -oE '"version":[[:space:]]*"[^"]+"' "$manifest" | head -1 | sed 's/.*"\([^"]*\)".*/\1/'
}

_manifest_write() {
  local manifest; manifest="$(_manifest_path)"
  mkdir -p "$(dirname "$manifest")"
  local version; version="$(cat "$CIEL_DIR/VERSION" 2>/dev/null | tr -d '[:space:]')"
  [ -z "$version" ] && version="2.1.0"
  local now; now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    printf '{\n'
    printf '  "version": "%s",\n' "$version"
    printf '  "installed_at": "%s",\n' "$now"
    printf '  "last_update_check": "%s",\n' "$now"
    printf '  "platforms": ['
    local first=1
    for p in "${INSTALLED[@]:-}"; do
      [ -z "$p" ] && continue
      if [ $first -eq 1 ]; then first=0; else printf ', '; fi
      printf '"%s"' "$p"
    done
    printf '],\n'
    printf '  "mcp": ['
    first=1
    if [ -n "$MCP_LIST" ]; then
      IFS=',' read -ra _mcp_arr <<< "$MCP_LIST"
      for m in "${_mcp_arr[@]}"; do
        m="${m// /}"
        [ -z "$m" ] && continue
        if [ $first -eq 1 ]; then first=0; else printf ', '; fi
        printf '"%s"' "$m"
      done
    fi
    printf '],\n'
    printf '  "files": ['
    first=1
    for f in "${INSTALLED_FILES[@]:-}"; do
      [ -z "$f" ] && continue
      if [ $first -eq 1 ]; then first=0; else printf ','; fi
      printf '\n    "%s"' "$f"
    done
    printf '\n  ]\n}\n'
  } > "$manifest"
  ok "Wrote manifest: $manifest"
}

# ─── MCP installer (opt-in via --with-mcp=playwright,context7) ───────────────
_install_mcp() {
  local mcp_list="$1"
  [ -z "$mcp_list" ] && return 0

  local src_mcp="$CIEL_DIR/.mcp.json"
  local dest_mcp="$PROJECT_ROOT/.mcp.json"

  if [ ! -f "$src_mcp" ]; then
    warn "No .mcp.json template in $CIEL_DIR — skipping MCP install"
    return 0
  fi
  if ! command -v python3 &>/dev/null; then
    warn "python3 not found — cannot merge .mcp.json. Copy $src_mcp manually."
    return 0
  fi

  if [ -f "$dest_mcp" ]; then
    local backup="$dest_mcp.backup-$(date +%Y%m%dT%H%M%S)"
    cp "$dest_mcp" "$backup"
    ok "Backed up existing .mcp.json → $backup"
  fi

  info "Merging MCP servers: $mcp_list"
  python3 - "$src_mcp" "$dest_mcp" "$mcp_list" <<'PY'
import json, sys, os
src, dst, requested = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src) as f:
    template = json.load(f)
servers = template.get("mcpServers", {})

current = {"mcpServers": {}}
if os.path.exists(dst):
    try:
        with open(dst) as f:
            current = json.load(f)
    except Exception:
        pass
current.setdefault("mcpServers", {})

added = []
skipped = []
for name in [n.strip() for n in requested.split(",") if n.strip()]:
    if name in servers:
        current["mcpServers"][name] = servers[name]
        added.append(name)
    else:
        skipped.append(name)

current.pop("_comment", None)

with open(dst, "w") as f:
    json.dump(current, f, indent=2)
    f.write("\n")

if added:
    print("  added: " + ", ".join(added))
if skipped:
    print("  not in template (skipped): " + ", ".join(skipped))
PY

  _manifest_append_file "$dest_mcp"
}

# ─── Update-check (queries GitHub for latest VERSION) ────────────────────────
_check_update() {
  local manifest; manifest="$(_manifest_path)"
  if [ ! -f "$manifest" ]; then
    warn "No manifest at $manifest — run a fresh install first"
    return 1
  fi
  local local_version; local_version="$(_manifest_read_version)"
  [ -z "$local_version" ] && { warn "Cannot read version from manifest"; return 1; }

  info "Local version:  $local_version"
  info "Checking GitHub..."
  local remote_version
  remote_version="$(curl -fsSL --max-time 5 \
    https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION 2>/dev/null \
    | tr -d '[:space:]')"
  if [ -z "$remote_version" ]; then
    warn "Could not fetch remote VERSION (network / GitHub unreachable)"
    return 1
  fi
  info "Remote version: $remote_version"

  # Record last check (enables SessionStart throttling)
  mkdir -p "$HOME/.ciel"
  touch "$HOME/.ciel/.last-update-check"

  if [ "$local_version" = "$remote_version" ]; then
    ok "Up to date."
    return 0
  fi
  echo ""
  echo -e "  ${YELLOW}Update available:${RESET} v$local_version → v$remote_version"
  echo "  Run: bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh) --update"
  return 0
}

# ─── Uninstall (reads manifest, removes tracked files, preserves whitelist) ──
_do_uninstall() {
  local manifest; manifest="$(_manifest_path)"
  if [ ! -f "$manifest" ]; then
    warn "No manifest at $manifest — nothing to uninstall"
    return 1
  fi

  local files
  if command -v python3 &>/dev/null; then
    files="$(python3 -c "import json,sys; print('\n'.join(json.load(open('$manifest')).get('files', [])))")"
  else
    files="$(grep -oE '"/[^"]+"' "$manifest" | sed 's/"//g')"
  fi
  [ -z "$files" ] && { warn "Manifest has no file entries"; return 1; }

  local count; count="$(echo "$files" | grep -c . || true)"
  info "Manifest lists $count files."

  if ! $FLAG_YES; then
    read -rp "  Delete these files? [y/N]: " ans
    case "$ans" in
      [Yy]*) ;;
      *) echo "  Aborted."; return 0 ;;
    esac
  fi

  # Whitelist: never auto-delete these (user data / user-scope configs)
  local preserve_re='(\.mcp\.json(\.backup-|$)|ciel-overlay\.md$)'

  local removed=0 preserved=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [[ "$f" =~ $preserve_re ]]; then
      info "Preserved (whitelist): $f"
      preserved=$((preserved + 1))
      continue
    fi
    if [ -e "$f" ]; then
      rm -rf "$f"
      removed=$((removed + 1))
    fi
  done <<< "$files"

  # Clean empty dirs (ignore failure — non-empty dirs stay)
  for d in \
    "$HOME/.claude/skills/ciel" \
    "$HOME/.claude/plugins/ciel" \
    "$HOME/.ciel/ollama" \
    "$HOME/.ciel/lmstudio"; do
    [ -d "$d" ] && rmdir "$d" 2>/dev/null || true
  done

  rm -f "$manifest" "$HOME/.ciel/.last-update-check"
  rmdir "$HOME/.ciel" 2>/dev/null || true

  ok "Removed $removed files (preserved $preserved)."
}

# ─── Update (uninstall + re-install from latest) ─────────────────────────────
_do_update() {
  local manifest; manifest="$(_manifest_path)"
  if [ ! -f "$manifest" ]; then
    warn "No manifest — cannot --update (not installed via v2.1.0+)"
    echo "  Run: bash scripts/install.sh  (fresh install)"
    return 1
  fi
  _check_update || return 1
  info "Proceeding with update..."
  FLAG_YES=true _do_uninstall
  info "Fetching latest installer..."
  curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh | bash -s -- -y
}

# ─── Flag short-circuits (uninstall/check-update/update exit immediately) ────
if $FLAG_UNINSTALL; then
  echo -e "\n${BOLD}Ciel Uninstall${RESET}"
  _do_uninstall
  exit $?
fi
if $FLAG_CHECK_UPDATE; then
  echo -e "\n${BOLD}Ciel Update Check${RESET}"
  _check_update
  exit $?
fi
if $FLAG_UPDATE; then
  echo -e "\n${BOLD}Ciel Update${RESET}"
  _do_update
  exit $?
fi

# ─── Detect existing install ─────────────────────────────────────────────────
IS_UPDATE=false
[ -f "$PROJECT_ROOT/ciel-overlay.md" ] && IS_UPDATE=true

if $IS_UPDATE; then
  echo -e "\n${BOLD}Ciel Universal Installer v2.1.0${RESET} (${YELLOW}update detected${RESET})"
else
  echo -e "\n${BOLD}Ciel Universal Installer v2.1.0${RESET}"
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
  printf '%s\n' "${skills[@]:-}" | sort -u
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

# ─── Post-install file registry (populates INSTALLED_FILES for manifest) ────
# Runs once after all install_* functions complete. Enumerates paths that
# are known Ciel outputs; [ -e ... ] filters to what actually got created.
_register_installed_files() {
  # Claude Code — skills (orchestrator + categorized)
  [ -d "$HOME/.claude/skills/ciel" ] && _manifest_append_file "$HOME/.claude/skills/ciel"
  for cat in workflow research domain utility meta; do
    [ -d "$CIEL_DIR/skills/$cat" ] || continue
    for s in "$CIEL_DIR/skills/$cat"/*/; do
      [ -d "$s" ] || continue
      local name; name=$(basename "$s")
      [ -d "$HOME/.claude/skills/$name" ] && _manifest_append_file "$HOME/.claude/skills/$name"
    done
  done
  # Agents + commands + plugin dir
  for a in researcher explorer critic improver; do
    [ -f "$HOME/.claude/agents/$a.md" ] && _manifest_append_file "$HOME/.claude/agents/$a.md"
  done
  for c in "$HOME/.claude/commands/"ciel*.md; do
    [ -f "$c" ] && _manifest_append_file "$c"
  done
  [ -d "$HOME/.claude/plugins/ciel" ] && _manifest_append_file "$HOME/.claude/plugins/ciel"

  # Project-scope overlay (whitelist preserves on uninstall)
  [ -f "$PROJECT_ROOT/ciel-overlay.md" ] && _manifest_append_file "$PROJECT_ROOT/ciel-overlay.md"

  # Cursor / Windsurf / Kilo
  [ -f "$PROJECT_ROOT/.cursor/rules/ciel.mdc" ] && _manifest_append_file "$PROJECT_ROOT/.cursor/rules/ciel.mdc"
  [ -f "$PROJECT_ROOT/.windsurf/rules/ciel.md" ] && _manifest_append_file "$PROJECT_ROOT/.windsurf/rules/ciel.md"
  [ -f "$PROJECT_ROOT/.kilocode/rules/ciel.md" ] && _manifest_append_file "$PROJECT_ROOT/.kilocode/rules/ciel.md"
  if [ -d "$PROJECT_ROOT/.kilo/agents" ]; then
    for f in "$PROJECT_ROOT/.kilo/agents/"*.md; do
      [ -f "$f" ] && _manifest_append_file "$f"
    done
  fi

  # Codex / OpenCode (AGENTS.md is whitelisted in uninstall — user-owned risk)
  [ -f "$PROJECT_ROOT/AGENTS.md" ] && _manifest_append_file "$PROJECT_ROOT/AGENTS.md"
  [ -f "$PROJECT_ROOT/opencode.json" ] && _manifest_append_file "$PROJECT_ROOT/opencode.json"
  [ -f "$PROJECT_ROOT/.opencode/plugins/ciel.ts" ] && _manifest_append_file "$PROJECT_ROOT/.opencode/plugins/ciel.ts"
  if [ -d "$PROJECT_ROOT/.opencode/agents" ]; then
    for f in "$PROJECT_ROOT/.opencode/agents/"ciel-*.md; do
      [ -f "$f" ] && _manifest_append_file "$f"
    done
  fi
  if [ -d "$PROJECT_ROOT/.opencode/commands" ]; then
    for f in "$PROJECT_ROOT/.opencode/commands/"ciel*.md; do
      [ -f "$f" ] && _manifest_append_file "$f"
    done
  fi

  # Ollama / LM Studio (home-scope)
  [ -f "$HOME/.ciel/ollama/Modelfile" ] && _manifest_append_file "$HOME/.ciel/ollama/Modelfile"
  [ -f "$HOME/.ciel/lmstudio/system-prompt.md" ] && _manifest_append_file "$HOME/.ciel/lmstudio/system-prompt.md"
  return 0
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
  # v2.0.0: copy all 33 skills across 5 categories + orchestrator
  cp -r "$CIEL_DIR/skills/ciel" "$HOME/.claude/skills/"
  ok "skills/ciel (orchestrator) -> ~/.claude/skills/ciel/"
  for category in workflow research domain utility meta; do
    if [ -d "$CIEL_DIR/skills/$category" ]; then
      for skill_dir in "$CIEL_DIR/skills/$category"/*/; do
        [ -d "$skill_dir" ] || continue
        # Strip trailing slash so BSD cp (macOS) copies the dir itself,
        # not just its contents onto the destination root.
        cp -r "${skill_dir%/}" "$HOME/.claude/skills/"
      done
      count=$(find "$CIEL_DIR/skills/$category" -maxdepth 1 -type d | tail -n +2 | wc -l)
      ok "skills/$category ($count skills) -> ~/.claude/skills/"
    fi
  done

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
    if grep -qE "(pre-write-gate|pre-tool-write|post-write-relire|post-tool-write)" "$settings" 2>/dev/null; then
      if grep -q "pre-write-gate\|post-write-relire" "$settings" 2>/dev/null; then
        warn "settings.json references v1.x hook names (pre-write-gate, post-write-relire) — update to v2.0.0 names (pre-tool-write, post-tool-write) in $CIEL_DIR/settings.json"
      else
        ok "Hooks already in settings.json"
      fi
    else
      warn "settings.json exists — merge hooks manually from $CIEL_DIR/settings.json (7 events in v2.0.0)"
    fi
  fi
}

install_cursor() {
  info "Cursor..."
  mkdir -p "$PROJECT_ROOT/.cursor/rules"
  cp "$PLATFORMS_DIR/cursor/.cursor/rules/ciel.mdc" "$PROJECT_ROOT/.cursor/rules/ciel.mdc"
  local size; size=$(wc -c < "$PROJECT_ROOT/.cursor/rules/ciel.mdc")
  ok "Copied .cursor/rules/ciel.mdc ($size bytes — under 6KB limit)"
  _install_overlay
}

install_windsurf() {
  info "Windsurf..."
  mkdir -p "$PROJECT_ROOT/.windsurf/rules"
  cp "$PLATFORMS_DIR/windsurf/.windsurf/rules/ciel.md" "$PROJECT_ROOT/.windsurf/rules/ciel.md"
  ok "Copied .windsurf/rules/ciel.md (always_on rule)"
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
  _purge_ciel_files "$PROJECT_ROOT/.opencode/commands" "ciel*.md"
  _purge_ciel_files "$PROJECT_ROOT/.opencode/plugins" "ciel.*"

  cp "$PLATFORMS_DIR/opencode/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"
  ok "Copied AGENTS.md"

  if [ -f "$PLATFORMS_DIR/opencode/opencode.json" ] && [ ! -f "$PROJECT_ROOT/opencode.json" ]; then
    cp "$PLATFORMS_DIR/opencode/opencode.json" "$PROJECT_ROOT/opencode.json"
    ok "Copied opencode.json"
  elif [ -f "$PROJECT_ROOT/opencode.json" ]; then
    warn "opencode.json exists — merge manually if needed (add plugin entry: ./.opencode/plugins/ciel.ts)"
  fi

  # Native primitives: plugin + 4 subagents + 6 slash commands
  if [ -f "$PLATFORMS_DIR/opencode/.opencode/plugins/ciel.ts" ]; then
    mkdir -p "$PROJECT_ROOT/.opencode/plugins"
    cp "$PLATFORMS_DIR/opencode/.opencode/plugins/ciel.ts" "$PROJECT_ROOT/.opencode/plugins/ciel.ts"
    ok "Copied .opencode/plugins/ciel.ts"
  fi

  if [ -d "$PLATFORMS_DIR/opencode/.opencode/agents" ]; then
    mkdir -p "$PROJECT_ROOT/.opencode/agents"
    cp "$PLATFORMS_DIR/opencode/.opencode/agents/"*.md "$PROJECT_ROOT/.opencode/agents/" 2>/dev/null
    ok "Copied .opencode/agents/ (ciel-researcher, ciel-explorer, ciel-critic, ciel-improver)"
  fi

  if [ -d "$PLATFORMS_DIR/opencode/.opencode/commands" ]; then
    mkdir -p "$PROJECT_ROOT/.opencode/commands"
    cp "$PLATFORMS_DIR/opencode/.opencode/commands/"*.md "$PROJECT_ROOT/.opencode/commands/" 2>/dev/null
    ok "Copied .opencode/commands/ (ciel, ciel-improve, ciel-eval, ciel-create-skill, ciel-recommend, ciel-update)"
  fi

  _install_overlay
}

install_kilocode() {
  info "Kilo Code..."
  _purge_ciel_files "$PROJECT_ROOT/.kilocode/rules" "ciel*.md"
  _purge_ciel_files "$PROJECT_ROOT/.kilo/agents" "*.md"
  mkdir -p "$PROJECT_ROOT/.kilocode/rules"
  cp "$PLATFORMS_DIR/kilocode/.kilocode/rules/ciel.md" "$PROJECT_ROOT/.kilocode/rules/ciel.md"
  ok "Copied .kilocode/rules/ciel.md"
  if [ -d "$PLATFORMS_DIR/kilocode/.kilo/agents" ]; then
    mkdir -p "$PROJECT_ROOT/.kilo/agents"
    cp "$PLATFORMS_DIR/kilocode/.kilo/agents/"*.md "$PROJECT_ROOT/.kilo/agents/" 2>/dev/null
    ok "Copied .kilo/agents/ (researcher/explorer/critic/improver)"
  fi
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
# Parallel indexed arrays (portable across bash 3.2 — no associative arrays)
DETECTED_KEYS=()
DETECTED_LABELS=()
_add_detected() { DETECTED_KEYS+=("$1"); DETECTED_LABELS+=("$2"); }

command -v claude &>/dev/null && _add_detected claude "Claude Code CLI"
{ [ -d "$PROJECT_ROOT/.cursor" ] || command -v cursor &>/dev/null; } && _add_detected cursor "Cursor IDE"
{ [ -d "$PROJECT_ROOT/.windsurf" ] || command -v windsurf &>/dev/null; } && _add_detected windsurf "Windsurf IDE"
command -v codex &>/dev/null && _add_detected codex "Codex CLI"
command -v opencode &>/dev/null && _add_detected opencode "OpenCode CLI"
{ [ -d "$PROJECT_ROOT/.kilocode" ] || \
  (command -v code &>/dev/null && code --list-extensions 2>/dev/null | grep -qi "kilocode"); } \
  && _add_detected kilocode "Kilo Code"
command -v ollama &>/dev/null && _add_detected ollama "Ollama"
{ command -v lms &>/dev/null || [ -d "$HOME/.lmstudio" ]; } && _add_detected lmstudio "LM Studio"

DETECTED_COUNT=${#DETECTED_KEYS[@]}

# ─── User selection ───────────────────────────────────────────────────────────
if [ "$DETECTED_COUNT" -eq 0 ]; then
  warn "No supported AI tool detected automatically."
  echo "  Available platforms: claude cursor windsurf codex opencode kilocode ollama lmstudio"
  read -rp "  Platforms to install (space-separated or 'all'): " RAW
  [ "$RAW" = "all" ] && RAW="claude cursor windsurf codex opencode kilocode ollama lmstudio"
  IFS=' ' read -ra PLATFORMS <<< "$RAW"
else
  echo -e "${BOLD}Detected:${RESET}"
  for i in $(seq 0 $((DETECTED_COUNT - 1))); do
    echo -e "  ${CYAN}[$((i+1))]${RESET} ${DETECTED_LABELS[$i]} ${YELLOW}[${DETECTED_KEYS[$i]}]${RESET}"
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

# ─── MCP opt-in + manifest write ──────────────────────────────────────────────
if [ -n "$MCP_LIST" ]; then
  echo ""
  info "Installing MCP servers..."
  _install_mcp "$MCP_LIST"
fi

echo ""
_register_installed_files
_manifest_write

echo ""
echo -e "${BOLD}Done.${RESET} Installed: ${INSTALLED[*]:-none}"
echo ""
echo "Edit ciel-overlay.md to set stack versions, CI config, and project rules."
echo "Uninstall:     bash scripts/install.sh --uninstall"
echo "Check update:  bash scripts/install.sh --check-update"
echo "Full docs:     https://github.com/KaosKyun/Ciel"
