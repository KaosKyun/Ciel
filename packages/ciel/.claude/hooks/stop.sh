#!/bin/bash
# Ciel — Stop hook
# Trigger: Claude finishes responding (end of task)
# Purpose: (1) inject meta-critiquer instruction; (2) if on default branch with
# 3+ unreleased feat/fix commits, prepend a release-gate reminder.
#
# Claude Code Stop-hook schema rejects hookSpecificOutput.additionalContext
# (it is only valid for UserPromptSubmit/PostToolUse). The documented way to
# steer the model at Stop is {"decision":"block","reason":"..."} — the reason
# is surfaced as an instruction the model must address.
#
# Both meta-critiquer and release-gate are combined into a single `reason`
# field so only one block event fires per Stop. The existing stop_hook_active
# loop guard handles re-entry for both.

INPUT=$(cat 2>/dev/null || echo "{}")

ACTIVE=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    print('true' if d.get('stop_hook_active', False) else 'false')
except Exception:
    print('false')
" "$INPUT" 2>/dev/null || echo "false")

if [ "$ACTIVE" = "true" ]; then
  exit 0
fi

# Fail-safe: block at most once per 60s window even if stop_hook_active
# is not set (older Claude Code versions, parsing edge cases, plugin
# auto-discovery re-invoking the same hook from multiple registrations).
# Without this, the same Stop event can fire 9 times → CC overrides the
# hook and emits the "blocked turn 9 times" warning.
PROJECT_KEY=$(echo "${CLAUDE_PROJECT_DIR:-$PWD}" | (shasum 2>/dev/null || sha1sum 2>/dev/null || md5sum 2>/dev/null || md5 -q 2>/dev/null || cksum 2>/dev/null) | cut -c1-12)
LAST_BLOCK_FILE="${TMPDIR:-/tmp}/ciel-stop-last-block-${PROJECT_KEY}"
NOW=$(date +%s)
LAST=$(cat "$LAST_BLOCK_FILE" 2>/dev/null || echo 0)
if [ $((NOW - LAST)) -lt 60 ]; then
  exit 0
fi
echo "$NOW" > "$LAST_BLOCK_FILE" 2>/dev/null || true

CWD=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.argv[1])
    print(d.get('cwd', ''))
except Exception:
    print('')
" "$INPUT" 2>/dev/null || echo "")

# Release-gate check — writes RG_MSG if it should fire
RG_MSG=""
check_release_gate() {
  local cwd="$1"
  [ -z "$cwd" ] && return 1
  command -v git >/dev/null 2>&1 || return 1
  git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1 || return 1

  local current default
  current=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  default=$(git -C "$cwd" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  [ -z "$default" ] && default="main"
  [ "$current" = "$default" ] || return 1

  local snooze="$cwd/.ciel-release-snooze"
  if [ -f "$snooze" ] && find "$snooze" -mmin -60 2>/dev/null | grep -q .; then
    return 1
  fi

  local last_tag range pending
  last_tag=$(git -C "$cwd" describe --tags --abbrev=0 2>/dev/null || echo "")
  if [ -z "$last_tag" ]; then
    range="HEAD"
  else
    range="$last_tag..HEAD"
  fi
  pending=$(git -C "$cwd" log "$range" --oneline 2>/dev/null | grep -cE '^[a-f0-9]+ (feat|fix)(\(|:|!)' || echo 0)

  [ "$pending" -ge 3 ] || return 1

  local tag_label="${last_tag:-<no previous tag>}"
  RG_MSG="CIEL RELEASE-GATE — $pending feat/fix commit(s) on $default since $tag_label without a release. Actions: (1) bump VERSION per conventional-commit scope (feat=minor, fix=patch, feat!/fix!=major), (2) append CHANGELOG.md entry, (3) git tag -a v<N.N.N>, (4) gh release create v<N.N.N> --generate-notes. Invoke changelog-updater + release-publisher skills. Snooze 60min: touch .ciel-release-snooze."
  return 0
}

META_MSG="CIEL STOP — 30s META-CRITIQUER obligatoire avant de declarer fini: (1) depth match? (2) new failure mode → Guard? (3) user correction → memoire (capture to .ciel/memory/episodes/ via memory-engine.py)? (4) stale branches? (5) uncovered issues? (6) context health? (7) session-progress.md written? (8) dead code sweep (ruff/knip/Detekt)? (9) agent-discovered pattern → memoire capture (if you noticed a reusable pattern, bug, or convention not yet in .ciel/memory/ — call memory-engine.py capture with --captured-from=agent-observed)? (10) 5+ triggers without promotion → invoke memoire-consolidator? Invoke meta-critiquer skill then memoire."

if check_release_gate "$CWD"; then
  MSG="$RG_MSG

$META_MSG"
else
  MSG="$META_MSG"
fi

python3 -c "
import json, sys
print(json.dumps({'decision': 'block', 'reason': sys.argv[1]}))
" "$MSG"

exit 0
