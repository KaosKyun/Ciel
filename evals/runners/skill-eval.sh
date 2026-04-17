#!/bin/bash
# Ciel — Headless skill evaluation runner
#
# Usage: ./skill-eval.sh <skill-path> <dataset-path> [variant-file]
#
# Runs each entry in the dataset through `claude --print` with the target skill
# installed, captures output + token count, and persists scores.
#
# Requires: claude CLI, jq, Claude Code installed with plugin-dir support.

set -euo pipefail

SKILL_PATH="${1:-}"
DATASET_PATH="${2:-}"
VARIANT_FILE="${3:-}"

if [[ -z "$SKILL_PATH" || -z "$DATASET_PATH" ]]; then
  echo "Usage: $0 <skill-path> <dataset-path> [variant-file]" >&2
  exit 1
fi

if [[ ! -f "$SKILL_PATH" ]]; then
  echo "Error: skill not found at $SKILL_PATH" >&2
  exit 1
fi

if [[ ! -f "$DATASET_PATH" ]]; then
  echo "Error: dataset not found at $DATASET_PATH" >&2
  exit 1
fi

PLUGIN_DIR="$(dirname "$(dirname "$(dirname "$SKILL_PATH")")")/"
TIMESTAMP=$(date -u +%Y-%m-%dT%H-%M-%SZ)
SKILL_NAME=$(basename "$(dirname "$SKILL_PATH")")
RESULTS_DIR="$(cd "$(dirname "$0")/.." && pwd)/results"
OUTPUT="$RESULTS_DIR/${SKILL_NAME}-${TIMESTAMP}.json"

mkdir -p "$RESULTS_DIR"

# If a variant file is provided, temporarily swap SKILL.md
if [[ -n "$VARIANT_FILE" && -f "$VARIANT_FILE" ]]; then
  BACKUP="${SKILL_PATH}.backup"
  cp "$SKILL_PATH" "$BACKUP"
  cp "$VARIANT_FILE" "$SKILL_PATH"
  trap 'mv "$BACKUP" "$SKILL_PATH"' EXIT
fi

ENTRIES=$(wc -l < "$DATASET_PATH")
echo "Running $ENTRIES evals for skill '$SKILL_NAME'..." >&2

results="[]"
total_tokens=0
total_duration=0
passed=0
total_criteria=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  id=$(echo "$line" | jq -r '.id')
  prompt=$(echo "$line" | jq -r '.input | to_entries | map("\(.key): \(.value)") | join("\n")')
  expected=$(echo "$line" | jq -c '.expected_behavior')

  start=$(date +%s%N)

  # Headless claude --print invocation
  # Falls back to echo if claude CLI unavailable
  if command -v claude >/dev/null 2>&1; then
    output=$(claude --print \
      --plugin-dir "$PLUGIN_DIR" \
      --allowed-tools "Read Grep Glob WebSearch WebFetch Bash" \
      --disallowed-tools "Write Edit NotebookEdit" \
      --max-turns 10 \
      "$prompt" 2>/dev/null || echo "CLAUDE_CLI_ERROR")
  else
    output="CLAUDE_CLI_NOT_AVAILABLE"
  fi

  end=$(date +%s%N)
  duration_ms=$(( (end - start) / 1000000 ))
  tokens=$(echo -n "$output" | wc -w)  # rough estimate: 1 word ~= 1.3 tokens
  tokens=$(( tokens * 4 / 3 ))

  # Score the output against expected_behavior
  entry_passed=0
  entry_total=0
  while IFS=$'\t' read -r criterion value; do
    entry_total=$((entry_total + 1))
    passed_this=0
    case "$criterion" in
      has_finding)
        [[ "$output" == *"## FINDINGS"* ]] && passed_this=1
        ;;
      has_anti_pattern)
        [[ "$output" == *"ANTI-PATTERN"* ]] && passed_this=1
        ;;
      has_philosophy)
        [[ "$output" == *"PHILOSOPHY"* ]] && passed_this=1
        ;;
      has_version_stamp)
        echo "$output" | grep -qE '[0-9]+\.[0-9]+' && passed_this=1
        ;;
      has_uncertainties_flagged)
        [[ "$output" == *"INCERTITUDES"* ]] && passed_this=1
        ;;
      has_3_risques)
        count=$(echo "$output" | grep -c "RISQUE:" || true)
        [[ $count -ge 3 ]] && passed_this=1
        ;;
      has_flux_narration)
        echo "$output" | grep -qE 'When .* → .* →' && passed_this=1
        ;;
      has_stride_mention|has_stride_6)
        [[ "$output" == *"STRIDE"* || ( "$output" == *"Spoofing"* && "$output" == *"Elevation"* ) ]] && passed_this=1
        ;;
      depth_match_trivial)
        echo "$output" | grep -qiE '\btrivial\b' && passed_this=1
        ;;
      depth_match_standard)
        echo "$output" | grep -qiE '\bstandard\b' && passed_this=1
        ;;
      depth_match_critical)
        echo "$output" | grep -qiE '\bcritical\b' && passed_this=1
        ;;
      *)
        # Generic pass: criterion name appears in output
        # (This is weak; prefer explicit criterion in scoring above)
        key_words=$(echo "$criterion" | tr '_' ' ')
        [[ "$output" == *"$key_words"* ]] && passed_this=1
        ;;
    esac
    entry_passed=$((entry_passed + passed_this))
  done < <(echo "$expected" | jq -r 'to_entries | map("\(.key)\t\(.value)") | .[]')

  score=$(awk "BEGIN{printf \"%.2f\", $entry_passed/$entry_total}")

  total_tokens=$((total_tokens + tokens))
  total_duration=$((total_duration + duration_ms))
  passed=$((passed + entry_passed))
  total_criteria=$((total_criteria + entry_total))

  entry_result=$(jq -n \
    --arg id "$id" \
    --argjson pp "$entry_passed" \
    --argjson tt "$entry_total" \
    --argjson sc "$score" \
    --argjson tk "$tokens" \
    --argjson dur "$duration_ms" \
    '{id: $id, criteria_passed: $pp, criteria_total: $tt, score: $sc, tokens: $tk, duration_ms: $dur}')
  results=$(echo "$results" | jq --argjson e "$entry_result" '. + [$e]')

  echo "  [$id] $entry_passed/$entry_total (${score}) — ${tokens} tokens, ${duration_ms}ms" >&2
done < "$DATASET_PATH"

aggregate=$(awk "BEGIN{printf \"%.2f\", $passed/$total_criteria}")

jq -n \
  --arg skill "$SKILL_NAME" \
  --arg skill_path "$SKILL_PATH" \
  --arg ts "$TIMESTAMP" \
  --arg dataset "$DATASET_PATH" \
  --argjson agg "$aggregate" \
  --argjson tt "$total_tokens" \
  --argjson td "$total_duration" \
  --argjson results "$results" \
  '{
    skill: $skill,
    skill_path: $skill_path,
    timestamp: $ts,
    dataset: $dataset,
    aggregate_score: $agg,
    total_tokens: $tt,
    total_duration_ms: $td,
    per_entry: $results
  }' > "$OUTPUT"

echo "" >&2
echo "Aggregate: $passed/$total_criteria (${aggregate})" >&2
echo "Total tokens: $total_tokens" >&2
echo "Result: $OUTPUT" >&2

cat "$OUTPUT"
