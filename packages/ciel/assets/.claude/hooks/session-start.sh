#!/bin/bash
# Ciel — SessionStart hook
# Trigger: session begins or resumes
# Purpose: print Ciel banner, load overlay context, set TRACE_ID for eval logging
# Never blocks (exit 0 always). Stdout is added to Claude's context.

INPUT=$(cat 2>/dev/null || echo "{}")
CWD=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('cwd', ''))" 2>/dev/null || pwd)
# python3 succeeds with an empty string when stdin JSON lacks a 'cwd' key — fall through to pwd.
[ -z "$CWD" ] && CWD="$(pwd)"

# Detect overlay presence
OVERLAY=""
for candidate in "$CWD/ciel-overlay.md" "$CWD/.claude/ciel-overlay.md"; do
  if [[ -f "$candidate" ]]; then
    OVERLAY="$candidate"
    break
  fi
done

# Reset session-scoped edit tracker so META/RELIRE gates don't bleed across sessions
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "$CLAUDE_PROJECT_DIR/.ciel/tracked-files.json" ]; then
  echo "[]" > "$CLAUDE_PROJECT_DIR/.ciel/tracked-files.json" 2>/dev/null || true
fi

# Generate TRACE_ID for this session (used by eval logging)
TRACE_ID=$(date -u +%Y%m%dT%H%M%SZ)-$$
export CIEL_TRACE_ID="$TRACE_ID"

# Resolve Ciel version at runtime (single source of truth, no hardcoded drift).
# Fallback chain: project sentinel → user sentinel → npm package → marketplace plugin → repo VERSION → unknown.
# Note: $HOME/.ciel/version is "last writer wins" across npm installs from different projects —
# project sentinel ($CWD/.ciel/version) is authoritative when present.
_resolve_ciel_version() {
  local v=""
  for f in \
    "$CWD/.ciel/version" \
    "$HOME/.ciel/version" \
    "$HOME/.claude/plugins/ciel/package.json" \
    "$HOME/.claude/plugins/ciel/.claude-plugin/plugin.json" \
    "$(dirname "$0")/../../VERSION" \
    "$(dirname "$0")/../VERSION"; do
    # Skip entries that resolved against an empty $CWD/$HOME (e.g., "/.ciel/version").
    case "$f" in /.ciel/*|/.claude/*) continue ;; esac
    [ -r "$f" ] || continue
    case "$f" in
      *.json)
        # Anchor to line-start whitespace so we only match top-level "version",
        # not nested keys like "schema_version" or `"version"` deeper in the doc.
        v=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$f" 2>/dev/null | head -1)
        ;;
      *)
        v=$(tr -d '[:space:]' <"$f" 2>/dev/null)
        ;;
    esac
    [ -n "$v" ] && { echo "$v"; return; }
  done
  echo "unknown"
}
CIEL_VERSION="$(_resolve_ciel_version)"
MSG="CIEL v${CIEL_VERSION} — Skills-first deep-reasoning active. "
if [[ -n "$OVERLAY" ]]; then
  MSG+="Overlay loaded: $OVERLAY. "
else
  MSG+="No overlay found at $CWD/ciel-overlay.md — create one for project-specific rules. "
fi
MSG+="Trace ID: $TRACE_ID. Principle: Understand before generating. Verify before claiming done."

# ─── Cued-recall: surface relevant memories ──────────────────────────────────
# If a memory corpus exists, list active (non-stale) memories so the model
# knows what cues are available. Full content read on-demand. See ADR-0001.
MEMORY_INDEX="$CWD/.ciel/memory/index.json"
if [[ -f "$MEMORY_INDEX" ]]; then
  MEMORY_SUMMARY=$(MEMORY_INDEX="$MEMORY_INDEX" python3 -c "
import json, os
try:
    with open(os.environ['MEMORY_INDEX']) as f:
        idx = json.load(f)
    mems = idx.get('memories', {})
    active = [(mid, m) for mid, m in mems.items() if not m.get('stale')]
    if not active:
        print('')
    else:
        # Sort by trigger_count desc, then by last_triggered desc
        active.sort(key=lambda x: (-(x[1].get('trigger_count') or 0), x[1].get('last_triggered') or ''), reverse=False)
        active.sort(key=lambda x: -(x[1].get('trigger_count') or 0))
        top = active[:10]
        lines = [f\"  [{mid}, {m.get('trigger_count', 0)}x] {m.get('title', '?')}\" for mid, m in top]
        total = len(active)
        more = f' (+{total - len(top)} more)' if total > len(top) else ''
        print(f'Cued-recall memory active ({total} memories{more}):\\n' + '\\n'.join(lines))
except Exception:
    print('')
" 2>/dev/null || echo "")
  if [[ -n "$MEMORY_SUMMARY" ]]; then
    MSG+=$'\n'"$MEMORY_SUMMARY"
    MSG+=$'\n'"Memories auto-inject when path/symbol/intent cues match. Read full content from .ciel/memory/{episodes,concepts,guards}/ when relevant."
  fi
elif [[ -d "$CWD/.ciel" ]] || [[ -f "$CWD/.claude/settings.json" ]] || [[ -f "$CWD/opencode.json" ]] || [[ -f "$CWD/ciel-overlay.md" ]]; then
  # Only suggest bootstrap if Ciel is actually installed in this project (not
  # any random repo with a CLAUDE.md). Markers checked: .ciel/ dir, .claude
  # settings, opencode config, or an explicit Ciel overlay.
  MSG+=$'\n'"No cued-recall memory yet. Run /ciel-memory-bootstrap to scan project for ingestable tribal docs (lessons.md, ciel-overlay.md, .claude/rules/, etc.)."
fi

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
