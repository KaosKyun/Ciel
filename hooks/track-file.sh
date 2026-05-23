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
