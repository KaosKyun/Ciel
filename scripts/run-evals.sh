#!/bin/bash
# Ciel — Run evals for one or all skills
#
# Usage:
#   ./run-evals.sh                    # Run all skills that have a dataset
#   ./run-evals.sh <skill-name>       # Run eval for a single skill
#   ./run-evals.sh --list             # List skills with datasets available
#   ./run-evals.sh --score <manual-dir>  # Score outputs captured manually (claude CLI unavailable path)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVALS="$ROOT/evals"
DATASETS="$EVALS/datasets"
RUNNER="$EVALS/runners/skill-eval.sh"

if [[ "${1:-}" == "--list" ]]; then
  echo "Datasets available:"
  for ds in "$DATASETS"/*.jsonl; do
    [[ -f "$ds" ]] || continue
    name=$(basename "$ds" .jsonl)
    count=$(wc -l < "$ds")
    echo "  $name ($count entries)"
  done
  exit 0
fi

if [[ "${1:-}" == "--score" ]]; then
  echo "Manual scoring mode: $2" >&2
  echo "TODO: implement manual scoring (parse markdown files in dir, match against dataset expected_behavior)" >&2
  exit 1
fi

if [[ -n "${1:-}" ]]; then
  # Single-skill mode
  SKILL_NAME="$1"
  SKILL_PATH=$(find "$ROOT/src/skills" -name SKILL.md -path "*/$SKILL_NAME/*" | head -1)
  if [[ -z "$SKILL_PATH" ]]; then
    echo "Error: skill '$SKILL_NAME' not found under skills/" >&2
    exit 1
  fi
  # Dataset name: try exact match, then fuzzy
  DATASET=""
  for candidate in "$DATASETS/$SKILL_NAME.jsonl" "$DATASETS/${SKILL_NAME}-"*.jsonl; do
    [[ -f "$candidate" ]] && DATASET="$candidate" && break
  done
  if [[ -z "$DATASET" ]]; then
    echo "Error: no dataset found for skill '$SKILL_NAME' in $DATASETS" >&2
    echo "Create one at: $DATASETS/$SKILL_NAME.jsonl" >&2
    exit 1
  fi
  "$RUNNER" "$SKILL_PATH" "$DATASET"
  exit 0
fi

# All-skills mode
echo "Running evals for all skills with datasets..."
failed=0
for ds in "$DATASETS"/*.jsonl; do
  [[ -f "$ds" ]] || continue
  name=$(basename "$ds" .jsonl)
  # Find matching skill — try a few variations
  SKILL_PATH=""
  for candidate_name in "$name" "$(echo "$name" | sed 's/-gate$//')" "$(echo "$name" | sed 's/-narration$//')" "$(echo "$name" | sed 's/-3-risques$//' | sed 's/$/-critic/')"; do
    found=$(find "$ROOT/src/skills" -name SKILL.md -path "*/$candidate_name/*" 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
      SKILL_PATH="$found"
      break
    fi
  done
  if [[ -z "$SKILL_PATH" ]]; then
    echo "⚠  No skill found matching dataset '$name' — skipping" >&2
    failed=$((failed + 1))
    continue
  fi
  echo ""
  echo "=== Evaluating: $name ==="
  "$RUNNER" "$SKILL_PATH" "$ds" || failed=$((failed + 1))
done

echo ""
echo "Done. $failed errors/skips."
exit $failed
