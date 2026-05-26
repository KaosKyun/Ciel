#!/bin/bash
# CIEL FILE TRACKING: log modified files for RELIRE trigger
# exit 0 = allow (always)

INPUT=$(cat 2>/dev/null || echo "{}")
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null || echo "")
TRACK_FILE="$CLAUDE_PROJECT_DIR/.ciel/tracked-files.json"

if [ -z "$FILE_PATH" ] || [ -z "$CLAUDE_PROJECT_DIR" ]; then
  exit 0
fi

# Create .ciel dir if needed
mkdir -p "$CLAUDE_PROJECT_DIR/.ciel"

# Record a code-edit timestamp for the Stop verification gate (logic files only —
# docs/config are not test-verifiable the same way). Compared by mtime in stop.sh.
if echo "$FILE_PATH" | grep -qE '\.(sh|ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|php|java|kt|swift|scala|vue|svelte|c|h|cpp|cs|sql)$'; then
  date -u +%Y-%m-%dT%H:%M:%SZ > "$CLAUDE_PROJECT_DIR/.ciel/last-code-edit" 2>/dev/null || true
fi

# Load existing tracking
TRACKED="[]"
if [ -f "$TRACK_FILE" ]; then
  TRACKED=$(cat "$TRACK_FILE")
fi

# Get current count
COUNT=$(echo "$TRACKED" | jq 'length')

# Add file (deduplicate)
FILE_PATH_ESCAPED=$(echo "$FILE_PATH" | jq -R .)
EXISTS=$(echo "$TRACKED" | jq "contains([$FILE_PATH_ESCAPED])")

if [ "$EXISTS" = "false" ]; then
  TRACKED=$(echo "$TRACKED" | jq ". + [$FILE_PATH_ESCAPED]")
fi

# Check for RELIRE threshold (5+ files or critical path)
CRITICAL_PATHS='auth|security|Token|Password|Secret|Session|Crypto|Account|Credential|Payment'
if echo "$FILE_PATH" | grep -qiE "$CRITICAL_PATHS"; then
  # Create sticky RELIRE flag
  echo "critical" > "$CLAUDE_PROJECT_DIR/.ciel/relire-required"
elif [ "$COUNT" -ge 5 ]; then
  echo "standard" > "$CLAUDE_PROJECT_DIR/.ciel/relire-required"
fi

echo "$TRACKED" > "$TRACK_FILE"
exit 0
