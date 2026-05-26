#!/bin/bash
# Ciel v9 — SessionStart hook
# Prints version banner + loads overlay context.
# Never blocks (exit 0 always). Stdout is added to Claude's context.

INPUT=$(cat 2>/dev/null || echo "{}")
CWD=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('cwd', ''))" 2>/dev/null || pwd)
[ -z "$CWD" ] && CWD="$(pwd)"

# Detect overlay
OVERLAY=""
for candidate in "$CWD/ciel-overlay.md" "$CWD/.claude/ciel-overlay.md"; do
  if [[ -f "$candidate" ]]; then
    OVERLAY="$candidate"
    break
  fi
done

# Generate TRACE_ID
TRACE_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
export CIEL_TRACE_ID="$TRACE_ID"

# Resolve version — project sentinel > user sentinel > npm package > VERSION file
_resolve_ciel_version() {
  local v=""
  for f in \
    "$CWD/.ciel/version" \
    "$HOME/.ciel/version" \
    "$HOME/.claude/plugins/ciel/package.json" \
    "$(dirname "$0")/../../VERSION" \
    "$(dirname "$0")/../VERSION"; do
    case "$f" in /.ciel/*|/.claude/*) continue ;; esac
    [ -r "$f" ] || continue
    case "$f" in
      *.json) v=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$f" 2>/dev/null | head -1) ;;
      *) v=$(tr -d '[:space:]' <"$f" 2>/dev/null) ;;
    esac
    [ -n "$v" ] && { echo "$v"; return; }
  done
  echo "unknown"
}
CIEL_VERSION="$(_resolve_ciel_version)"

# ─── Session reset — scope the dispatch + verification gates to this session ──
# Without this, a prior session's markers leak forward (stale dispatch token,
# false "unverified" Stop blocks). Cleared here so each session starts clean.
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  mkdir -p "$CWD/.ciel" 2>/dev/null || true
  rm -f "$CWD/.ciel/dispatched" \
        "$CWD/.ciel/last-code-edit" \
        "$CWD/.ciel/last-verification" \
        "$CWD/.ciel/relire-required" 2>/dev/null || true
  echo "[]" > "$CWD/.ciel/tracked-files.json" 2>/dev/null || true
fi

MSG="Ciel v${CIEL_VERSION} — Trace: ${TRACE_ID}."
if [[ -n "$OVERLAY" ]]; then
  MSG+=" Overlay: $OVERLAY."
fi

# ─── Update check (throttled to once per 24h, never blocks) ──────────────────
MANIFEST="$HOME/.ciel/manifest.json"
LAST_CHECK="$HOME/.ciel/.last-update-check"
if [[ -f "$MANIFEST" ]]; then
  STALE=false
  if [[ ! -f "$LAST_CHECK" ]]; then STALE=true
  elif find "$LAST_CHECK" -mmin +1440 2>/dev/null | grep -q .; then STALE=true; fi
  if $STALE; then
    LOCAL_VER=$(grep -oE '"version":[[:space:]]*"[^"]+"' "$MANIFEST" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
    REMOTE_VER=$(curl -fsSL --max-time 2 https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION 2>/dev/null | tr -d '[:space:]')
    if [[ -n "$LOCAL_VER" && -n "$REMOTE_VER" && "$LOCAL_VER" != "$REMOTE_VER" ]]; then
      MSG+=" [UPDATE] v${LOCAL_VER}→v${REMOTE_VER}. Run /ciel-update."
    fi
    mkdir -p "$HOME/.ciel" 2>/dev/null || true
    touch "$LAST_CHECK" 2>/dev/null || true
  fi
fi

echo "$MSG"
exit 0
