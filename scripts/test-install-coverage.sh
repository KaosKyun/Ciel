#!/usr/bin/env bash
# Ciel — install.sh coverage regression test
#
# Verifies that every command file in commands/ AND every hook in hooks/
# is referenced in scripts/install.sh and scripts/lib/installers.sh
# distribution + uninstall lists.
#
# This catches the bug class observed in v6.5.1: a new command/hook is
# added to the source tree but install.sh has multiple copy-list loops
# and one of them is forgotten — file is downloaded but never copied to
# the target, feature silently unavailable.
#
# Exit 0 if all source files are properly distributed.
# Exit 1 with a list of orphans otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INSTALL_SH="$REPO_ROOT/scripts/install.sh"
INSTALLERS_SH="$REPO_ROOT/scripts/lib/installers.sh"

if [[ ! -f "$INSTALL_SH" ]]; then
  echo "ERROR: $INSTALL_SH not found"
  exit 1
fi

orphans=()
warnings=()

# ─── Commands coverage ───────────────────────────────────────────────────────
# Each commands/*.md must appear in install.sh distribution lists.
# Skipped: ciel-improve.md (OpenCode-only, not in .claude/commands).

echo "Checking commands/ coverage in install.sh..."
for cmd_file in "$REPO_ROOT/commands"/*.md; do
  [[ ! -f "$cmd_file" ]] && continue
  cmd_name="$(basename "$cmd_file" .md)"

  # Documented exceptions (OpenCode-only commands)
  case "$cmd_name" in
    ciel-improve)
      # OpenCode-only, expected to be absent from .claude/commands lists
      continue
      ;;
  esac

  # Count how many `cmd in ... ${cmd_name}` references exist in install.sh
  matches=$(grep -cE "for cmd in .*\\b${cmd_name}\\b" "$INSTALL_SH" || true)

  # Expected: at least 3 references
  #   1× curl-mode download
  #   1× curl-mode copy-to-target
  #   1× local-mode copy-to-target
  # (uninstall is +1 but counted as bonus)
  if [[ "$matches" -lt 3 ]]; then
    orphans+=("commands/${cmd_name}.md → only ${matches} install.sh reference(s) (expected ≥3)")
  fi
done

# ─── Hooks coverage ──────────────────────────────────────────────────────────
# Each hooks/*.sh and hooks/*.py must appear in installers.sh download list
# (curl mode) so it lands in $plugin_dir.

echo "Checking hooks/ coverage in install scripts..."
# A hook is considered "covered" if it appears in EITHER:
#   - scripts/lib/installers.sh (curl-mode root hooks list), OR
#   - scripts/install.sh (.claude/hooks list, for hooks duplicated under .claude/)
# This handles the legacy duplication where some hooks (e.g. check-test-first.sh)
# exist in both hooks/ and .claude/hooks/ for backward compat.
for hook_file in "$REPO_ROOT/hooks"/*.{sh,py}; do
  [[ ! -f "$hook_file" ]] && continue
  hook_name="$(basename "$hook_file")"
  hook_escaped="${hook_name//./\\.}"

  found=0
  if [[ -f "$INSTALLERS_SH" ]] && grep -qE "for hook in .*\\b${hook_escaped}\\b" "$INSTALLERS_SH"; then
    found=1
  fi
  if [[ "$found" -eq 0 ]] && grep -qE "for hook in .*\\b${hook_escaped}\\b" "$INSTALL_SH"; then
    # Hook is distributed via .claude/hooks/ path in install.sh — counts as covered
    found=1
  fi

  if [[ "$found" -eq 0 ]]; then
    orphans+=("hooks/${hook_name} → not referenced in install.sh or installers.sh")
  fi
done

# ─── Report ──────────────────────────────────────────────────────────────────

if [[ "${#orphans[@]}" -eq 0 ]]; then
  echo "✓ All commands/ and hooks/ files are referenced in install.sh distribution lists"
  exit 0
fi

echo ""
echo "✗ Found ${#orphans[@]} install.sh distribution orphan(s):"
echo ""
for o in "${orphans[@]}"; do
  echo "  - $o"
done
echo ""
echo "Fix: add missing entries to ALL relevant cmd-in or hook-in loops in"
echo "scripts/install.sh and scripts/lib/installers.sh. See PR #35 for the"
echo "pattern (one bug, four loops to update)."
exit 1
