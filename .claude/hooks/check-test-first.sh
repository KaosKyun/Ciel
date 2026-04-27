#!/bin/bash
# CIEL FAIRE REMINDER: test-first (RED)
# Reminds you if you're editing source code without a corresponding test file.
# Never blocks — exit 0 always.
# Remove or disable this hook if you find it intrusive:
#   jq 'del(.hooks.PreToolUse[0])' .claude/settings.json > tmp && mv tmp .claude/settings.json

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""')

[ -z "$FILE_PATH" ] && exit 0

BASENAME=$(basename "$FILE_PATH")
DIRNAME=$(dirname "$FILE_PATH")
EXT="${BASENAME##*.}"
NAME="${BASENAME%.*}"

# Skip non-source files
if echo "$FILE_PATH" | grep -qiE '\.(test|spec)\.' || \
   echo "$FILE_PATH" | grep -qiE '(ciel\.ts|CLAUDE\.md|AGENTS\.md|settings\.json)' || \
   echo "$BASENAME" | grep -qiE '(^\.)' || \
   echo "$FILE_PATH" | grep -qiE '\.(sql|md|json|yaml|yml|toml|cfg|ini|env|lock|svg|png|jpg|ico)$' || \
   echo "$FILE_PATH" | grep -qiE '/migrations/|/seeders/'; then
  exit 0
fi

# Check if a test file exists
for candidate in "$DIRNAME/${NAME}.test.${EXT}" "$DIRNAME/${NAME}.spec.${EXT}" "$DIRNAME/__tests__/${NAME}.${EXT}" "$DIRNAME/tests/${NAME}.${EXT}"; do
  [ -f "$candidate" ] && exit 0
done

# No test found — warn but DO NOT BLOCK
echo "[CIEL REMINDER] Editing source without tests: $FILE_PATH" >&2
echo "  Consider writing tests first (TDD). Candidates: ${NAME}.test.${EXT}" >&2
exit 0
