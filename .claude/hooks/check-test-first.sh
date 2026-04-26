#!/bin/bash
# CIEL FAIRE GATE: test-first (RED)
# Checks if a test file exists before allowing source code edits
# exit 2 = block, exit 0 = allow

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Extract filename and dir
BASENAME=$(basename "$FILE_PATH")
DIRNAME=$(dirname "$FILE_PATH")
EXT="${BASENAME##*.}"
NAME="${BASENAME%.*}"

# Skip test files, config files, and the plugin itself
if echo "$FILE_PATH" | grep -qiE '\.(test|spec)\.' || echo "$FILE_PATH" | grep -qiE '(ciel\.ts|CLAUDE\.md|AGENTS\.md|settings\.json)' || echo "$BASENAME" | grep -qiE '(^\.)'; then
  exit 0
fi

# Check if test file exists
TEST_EXISTS=false
for candidate in "$DIRNAME/${NAME}.test.${EXT}" "$DIRNAME/${NAME}.spec.${EXT}" "$DIRNAME/__tests__/${NAME}.${EXT}" "$DIRNAME/tests/${NAME}.${EXT}"; do
  if [ -f "$candidate" ]; then
    TEST_EXISTS=true
    break
  fi
done

if [ "$TEST_EXISTS" = false ] && [ -f "$CLAUD_PROJECT_DIR/.ciel/exploration.active" ]; then
  # SPIKE mode: allow but warn
  echo "[CIEL SPIKE] No test found for $FILE_PATH but spike mode active -- gates assouplies" >&2
  exit 0
fi

if [ "$TEST_EXISTS" = false ]; then
  echo "[CIEL FAIRE GATE] No test file found for $FILE_PATH. Write the test FIRST before editing source code." >&2
  echo "Candidates checked: ${NAME}.test.${EXT}, ${NAME}.spec.${EXT}, __tests__/${NAME}.${EXT}" >&2
  exit 2
fi

exit 0
