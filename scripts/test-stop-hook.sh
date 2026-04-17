#!/bin/bash
# Ciel — Smoke test for hooks/stop.sh
# Covers meta-critiquer + release-gate combined-reason Stop hook.
# Usage: bash scripts/test-stop-hook.sh
# Exits 0 on all-pass, 1 on any failure.

set -uo pipefail

HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/stop.sh"
if [ ! -f "$HOOK" ]; then
  echo "FAIL: cannot locate hooks/stop.sh at $HOOK" >&2
  exit 1
fi

PASS=0
FAIL=0

_run_hook() {
  local cwd="$1"
  local active="${2:-false}"
  echo "{\"stop_hook_active\":$active,\"cwd\":\"$cwd\"}" | bash "$HOOK"
}

_assert() {
  local name="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name — expected=$expected actual=$actual" >&2
    FAIL=$((FAIL + 1))
  fi
}

_has() {
  python3 -c "import json,sys; d=json.loads(sys.stdin.read() or '{}'); print('yes' if sys.argv[1] in d.get('reason','') else 'no')" "$1"
}

_setup_repo() {
  local dir="$1"
  shift
  mkdir -p "$dir"
  cd "$dir"
  git init -q --initial-branch=main
  git config user.email test@ciel.local
  git config user.name ciel-test
  git commit --allow-empty -q -m "chore: init"
  git tag v0.1.0
  for msg in "$@"; do
    git commit --allow-empty -q -m "$msg"
  done
  git update-ref refs/remotes/origin/HEAD refs/heads/main
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Case 1 — 3 pending feat/fix on main, no snooze → release-gate fires
R1="$TMP/r1"
_setup_repo "$R1" "feat: one" "fix(scope): two" "feat!: three"
OUT1=$(_run_hook "$R1")
_assert "case1/has-release-gate" "$(echo "$OUT1" | _has 'CIEL RELEASE-GATE')" "yes"
_assert "case1/has-meta" "$(echo "$OUT1" | _has 'META-CRITIQUER')" "yes"

# Case 2 — fresh snooze → release-gate skipped, meta kept
touch "$R1/.ciel-release-snooze"
OUT2=$(_run_hook "$R1")
_assert "case2/no-release-gate" "$(echo "$OUT2" | _has 'CIEL RELEASE-GATE')" "no"
_assert "case2/has-meta" "$(echo "$OUT2" | _has 'META-CRITIQUER')" "yes"

# Case 3 — old snooze (>60min) → release-gate fires again
touch -t 202001010000 "$R1/.ciel-release-snooze"
OUT3=$(_run_hook "$R1")
_assert "case3/has-release-gate" "$(echo "$OUT3" | _has 'CIEL RELEASE-GATE')" "yes"

# Case 4 — feature branch, not default → release-gate skipped
rm -f "$R1/.ciel-release-snooze"
cd "$R1" && git checkout -q -b feat/test
OUT4=$(_run_hook "$R1")
_assert "case4/no-release-gate" "$(echo "$OUT4" | _has 'CIEL RELEASE-GATE')" "no"
cd "$R1" && git checkout -q main

# Case 5 — stop_hook_active=true → silent exit
OUT5=$(_run_hook "$R1" "true")
if [ -z "$OUT5" ]; then
  _assert "case5/silent-on-active" "silent" "silent"
else
  _assert "case5/silent-on-active" "not-silent:$OUT5" "silent"
fi

# Case 6 — only 2 pending (below threshold) → release-gate skipped
R2="$TMP/r2"
_setup_repo "$R2" "feat: one" "fix: two"
OUT6=$(_run_hook "$R2")
_assert "case6/no-release-gate-below-threshold" "$(echo "$OUT6" | _has 'CIEL RELEASE-GATE')" "no"

# Case 7 — non-git CWD → both skipped silently? No, meta still fires (it's unconditional)
R3="$TMP/r3-non-git"
mkdir -p "$R3"
OUT7=$(_run_hook "$R3")
_assert "case7/non-git-no-release-gate" "$(echo "$OUT7" | _has 'CIEL RELEASE-GATE')" "no"
_assert "case7/non-git-has-meta" "$(echo "$OUT7" | _has 'META-CRITIQUER')" "yes"

# Case 8 — zero tags, 3+ feat/fix → release-gate fires (range falls back to HEAD)
R4="$TMP/r4-no-tag"
mkdir -p "$R4"
cd "$R4"
git init -q --initial-branch=main
git config user.email t@t.local && git config user.name t
git commit --allow-empty -q -m "feat: one"
git commit --allow-empty -q -m "fix: two"
git commit --allow-empty -q -m "feat: three"
git update-ref refs/remotes/origin/HEAD refs/heads/main
OUT8=$(_run_hook "$R4")
_assert "case8/zero-tag-release-gate" "$(echo "$OUT8" | _has 'CIEL RELEASE-GATE')" "yes"

echo
echo "Results: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
