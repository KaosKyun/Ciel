#!/usr/bin/env bash
# Ciel — Session-start version check
# Outputs to stderr so the user sees the notification.
# Non-blocking: silent on fetch failure (offline/proxy).
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
LOCAL_VERSION=$(cat "$PROJECT_DIR/VERSION" 2>/dev/null || echo "0.0.0")

REMOTE_VERSION=$(curl -fsSL --connect-timeout 3 "https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION" 2>/dev/null || true)

if [ -n "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
  echo "[CIEL] Update available: v${LOCAL_VERSION} → v${REMOTE_VERSION}. Run /ciel-update to upgrade." >&2
fi
