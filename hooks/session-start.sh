#!/bin/bash
# Ciel — SessionStart hook
# Trigger: session begins or resumes
# Purpose: print Ciel banner, load overlay context, set TRACE_ID for eval logging
# Never blocks (exit 0 always). Stdout is added to Claude's context.

INPUT=$(cat 2>/dev/null || echo "{}")
CWD=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('cwd', ''))" 2>/dev/null || pwd)

# Detect overlay presence
OVERLAY=""
for candidate in "$CWD/ciel-overlay.md" "$CWD/.claude/ciel-overlay.md"; do
  if [[ -f "$candidate" ]]; then
    OVERLAY="$candidate"
    break
  fi
done

# Generate TRACE_ID for this session (used by eval logging)
TRACE_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
export CIEL_TRACE_ID="$TRACE_ID"

MSG="CIEL v2.1.5 — Skills-first deep-reasoning active. "
if [[ -n "$OVERLAY" ]]; then
  MSG+="Overlay loaded: $OVERLAY. "
else
  MSG+="No overlay found at $CWD/ciel-overlay.md — create one for project-specific rules. "
fi
MSG+="Trace ID: $TRACE_ID. Principle: Understand before generating. Verify before claiming done."

# ─── Update check (throttled to once per 24h, never blocks) ──────────────────
# Fetches GitHub VERSION non-blocking (max 2s). Any failure → silent skip.
MANIFEST="$HOME/.ciel/manifest.json"
LAST_CHECK="$HOME/.ciel/.last-update-check"
if [[ -f "$MANIFEST" ]]; then
  STALE=false
  if [[ ! -f "$LAST_CHECK" ]]; then
    STALE=true
  elif find "$LAST_CHECK" -mmin +1440 2>/dev/null | grep -q .; then
    STALE=true
  fi
  if $STALE; then
    LOCAL_VER=$(grep -oE '"version":[[:space:]]*"[^"]+"' "$MANIFEST" 2>/dev/null \
      | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
    REMOTE_VER=$(curl -fsSL --max-time 2 \
      https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION 2>/dev/null \
      | tr -d '[:space:]')
    if [[ -n "$LOCAL_VER" && -n "$REMOTE_VER" && "$LOCAL_VER" != "$REMOTE_VER" ]]; then
      MSG+=" [UPDATE] Ciel v$LOCAL_VER → v$REMOTE_VER available. Run /ciel-update."
    fi
    mkdir -p "$HOME/.ciel" 2>/dev/null || true
    touch "$LAST_CHECK" 2>/dev/null || true
  fi
fi

echo "$MSG"
exit 0
