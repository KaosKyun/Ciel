#!/bin/bash
# Ciel — Post-install setup
# Run after: claude plugin install github:KaosKyun/Ciel

set -e

PROJECT_ROOT="${1:-$(pwd)}"
OVERLAY_PATH="$PROJECT_ROOT/ciel-overlay.md"
PLUGIN_DIR="$PROJECT_ROOT/.claude/plugins/ciel"

echo "Ciel v1.0.0 — Setup"
echo "Project root: $PROJECT_ROOT"

# Create overlay if not exists
if [ ! -f "$OVERLAY_PATH" ]; then
  echo "Creating ciel-overlay.md from template..."
  cp "$PLUGIN_DIR/overlay-template.md" "$OVERLAY_PATH"
  echo "→ Edit $OVERLAY_PATH with your project stack and versions."
else
  echo "→ ciel-overlay.md already exists — skipping."
fi

# Make hooks executable
chmod +x "$PLUGIN_DIR/hooks/pre-write-gate.sh"
chmod +x "$PLUGIN_DIR/hooks/post-write-relire.sh"
echo "→ Hooks set as executable."

echo ""
echo "Setup complete."
echo "Usage: /ciel <task description>"
echo "Docs:  https://github.com/KaosKyun/Ciel"
