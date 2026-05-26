#!/usr/bin/env bash
#
# sync-mirrors.sh — Verify (or fix) the project's distribution mirror
# invariants. Catches the foot-gun captured as memory guard
# mem_1778821498_f7001b ("Patching ciel/SKILL.md requires updating 3
# variants — no auto-sync") and the related drifts where new commands
# or hooks are added in one place and forgotten in others.
#
# Two enforcement levels reflect what the build/install pipeline can do:
#
#   1. EXISTENCE invariants (commands).
#      Slash commands are copied across 4 mirrors, but each platform
#      injects its own YAML frontmatter (`.opencode` adds `description:`
#      and `subtask:` lines; the assets template gets {{VERSION}}
#      substituted to a real version by copy-assets.cjs). A naive
#      byte-equality check yields false positives. We only enforce that
#      every command file is PRESENT in every required mirror.
#
#   2. CONTENT invariants (hooks + orchestrator skill).
#      Hooks and `skills/ciel/*.md` ship raw, no transformation, so we
#      enforce strict byte equality. Drift here means a real
#      patch-the-source-but-forget-the-mirror bug.
#
# Agent mirrors are NOT checked here — `agents/<role>.md` undergoes a
# name transformation to `<mirror>/ciel-<role>.md` plus per-platform
# frontmatter tweaks. The existing CI step "Validate Agent Parity
# (OpenCode <-> Claude Code)" already covers that surface.
#
# Usage:
#   bash scripts/sync-mirrors.sh           # check (default), exit 1 on drift
#   bash scripts/sync-mirrors.sh --check   # explicit check mode
#   bash scripts/sync-mirrors.sh --fix     # apply: create missing command
#                                          # files (cp from source) and
#                                          # rsync content invariants
#
# Exit code: 0 on clean, 1 on drift (--check) or copy failure (--fix).

set -uo pipefail

MODE="check"
case "${1:-}" in
  --fix)   MODE="fix" ;;
  --check) MODE="check" ;;
  "")      MODE="check" ;;
  *)
    echo "Usage: $0 [--check|--fix]" >&2
    exit 2
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRIFT=0

# require_existence <source-file> <mirror-file>
require_existence() {
  local src="$1" mirror="$2"
  if [ ! -f "$src" ]; then
    return  # nothing to mirror
  fi
  if [ ! -f "$mirror" ]; then
    if [ "$MODE" = "fix" ]; then
      mkdir -p "$(dirname "$mirror")"
      cp "$src" "$mirror"
      echo "  created: $mirror"
    else
      echo "  MISSING: $mirror (source: $src)" >&2
      DRIFT=$((DRIFT + 1))
    fi
  fi
}

# require_byte_equal <source-file> <mirror-file>
require_byte_equal() {
  local src="$1" mirror="$2"
  if [ ! -f "$src" ]; then
    echo "  SKIP: source missing ($src)"
    return
  fi
  if [ ! -f "$mirror" ]; then
    if [ "$MODE" = "fix" ]; then
      mkdir -p "$(dirname "$mirror")"
      cp "$src" "$mirror"
      echo "  created: $mirror"
    else
      echo "  MISSING: $mirror (source: $src)" >&2
      DRIFT=$((DRIFT + 1))
    fi
    return
  fi
  if ! cmp -s "$src" "$mirror"; then
    if [ "$MODE" = "fix" ]; then
      cp "$src" "$mirror"
      echo "  fixed: $mirror"
    else
      echo "  DRIFT: $src <> $mirror" >&2
      DRIFT=$((DRIFT + 1))
    fi
  fi
}

# ─── Slash commands — EXISTENCE only ────────────────────────────────────────

CLAUDE_AND_OPENCODE_COMMANDS=(
  ciel-init ciel-update ciel-refresh ciel-eval ciel-create-skill
  ciel-audit ciel-memory-bootstrap ciel-migrate ciel-status
)
CLAUDE_ONLY_COMMANDS=(ciel-improve)

echo "Group: slash commands (existence)"
for cmd in "${CLAUDE_AND_OPENCODE_COMMANDS[@]}"; do
  src="commands/${cmd}.md"
  for mirror in \
    ".claude/commands/${cmd}.md" \
    ".opencode/commands/${cmd}.md" \
    "packages/ciel/assets/commands/${cmd}.md" \
    "packages/ciel/assets/platforms/opencode/.opencode/commands/${cmd}.md"
  do
    require_existence "$src" "$mirror"
  done
done
for cmd in "${CLAUDE_ONLY_COMMANDS[@]}"; do
  src="commands/${cmd}.md"
  # Claude-only: no .opencode mirror
  for mirror in \
    ".claude/commands/${cmd}.md" \
    "packages/ciel/assets/commands/${cmd}.md"
  do
    require_existence "$src" "$mirror"
  done
done

# ─── Shared hooks (canonical source = hooks/) — BYTE-EQUAL ──────────────────

# All canonical hooks live in hooks/ and are mirrored to assets/ by copy-assets.cjs.
# .claude/hooks/ is gitignored (local install), so it is NOT a CI-checkable mirror —
# the real invariant is hooks/ (source) == assets/.claude/hooks/ (shipped).
SHARED_HOOKS=(
  block-destructive.sh track-file.sh track-verification.sh check-dispatch-gate.sh
  pre-agent-gate.sh pre-tool-write.sh stop.sh session-start.sh
  user-prompt-submit.sh memory-bootstrap.sh memory-engine.py
)

echo "Group: shared hooks (hooks/ -> assets) — byte-equal"
for hook in "${SHARED_HOOKS[@]}"; do
  require_byte_equal "hooks/${hook}" "packages/ciel/assets/.claude/hooks/${hook}"
done

# ─── Orchestrator skill — BYTE-EQUAL ────────────────────────────────────────

echo "Group: skills/ciel orchestrator — byte-equal"
for f in SKILL.md reference.md; do
  require_byte_equal "skills/ciel/${f}" "packages/ciel/assets/skills/ciel/${f}"
done

# ─── Claude Code settings template — BYTE-EQUAL ─────────────────────────────
# .claude/settings.json is the canonical hook+permissions template that ships
# to user projects. The asset mirror must stay byte-identical so npm installs
# get the same hooks (and the same existence-guards) as bash installs.

echo "Group: .claude/settings.json — byte-equal"
require_byte_equal ".claude/settings.json" "packages/ciel/assets/.claude/settings.json"

# ─── Workflow skills — BYTE-EQUAL ───────────────────────────────────────────
# Every skills/workflow/<name>/SKILL.md must mirror to the assets dir so
# the npm package + install.sh ship the full workflow library.

echo "Group: skills/workflow — byte-equal"
if [ -d "skills/workflow" ]; then
  for skill_dir in skills/workflow/*/; do
    skill_name="$(basename "$skill_dir")"
    require_byte_equal "skills/workflow/${skill_name}/SKILL.md" "packages/ciel/assets/skills/workflow/${skill_name}/SKILL.md"
    if [ -f "skills/workflow/${skill_name}/reference.md" ]; then
      require_byte_equal "skills/workflow/${skill_name}/reference.md" "packages/ciel/assets/skills/workflow/${skill_name}/reference.md"
    fi
  done
fi

# ─── Verdict ────────────────────────────────────────────────────────────────

if [ "$MODE" = "check" ]; then
  if [ "$DRIFT" -eq 0 ]; then
    echo ""
    echo "OK — all enforced mirror invariants hold."
    exit 0
  else
    echo "" >&2
    echo "FAIL — $DRIFT mirror invariant(s) violated." >&2
    echo "Run 'bash scripts/sync-mirrors.sh --fix' to push source-of-truth into mirrors." >&2
    echo "Note: --fix only creates MISSING files for commands and overwrites" >&2
    echo "drifted hooks/skills. It does NOT alter existing command bodies because" >&2
    echo "OpenCode commands carry per-platform frontmatter." >&2
    exit 1
  fi
else
  echo ""
  echo "OK — fix pass complete. Re-run without --fix to confirm."
  exit 0
fi
