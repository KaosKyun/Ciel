#!/bin/bash
# Ciel — Memory Bootstrap (cued-recall)
# Trigger: invoked manually by /ciel-memory-bootstrap or programmatically
# Purpose: scan project for ingestable tribal docs and report findings
# Usage:
#   memory-bootstrap.sh scan          → report what would be ingested (dry-run, default)
#   memory-bootstrap.sh ingest        → actually create memories from sources
#   memory-bootstrap.sh status        → report current memory corpus stats
#
# Never blocks (exit 0 on success, exit 1 only on hard errors). Stdout is the
# user-facing report. See ADR-0001 and skill `memoire`.

set -e

CMD="${1:-scan}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${PWD}}"
MEMORY_DIR="$PROJECT_DIR/.ciel/memory"
INDEX_FILE="$MEMORY_DIR/index.json"

# ─── Source candidates (priority order) ──────────────────────────────────────
declare -a SOURCES=(
  "$PROJECT_DIR/.ciel/learnings.md"
  "$PROJECT_DIR/.claude/learnings.md"
  "$PROJECT_DIR/.claude/lessons.md"
  "$PROJECT_DIR/lessons.md"
  "$PROJECT_DIR/LESSONS.md"
  "$PROJECT_DIR/ciel-overlay.md"
  "$PROJECT_DIR/AGENTS.md"
  "$PROJECT_DIR/CLAUDE.md"
)

# .claude/rules/*.md detected separately (variable count)
RULES_DIR="$PROJECT_DIR/.claude/rules"

# ─── Helpers ─────────────────────────────────────────────────────────────────

scan_sources() {
  local found=0
  echo "Scanning $PROJECT_DIR for ingestable tribal docs..."
  echo ""
  for src in "${SOURCES[@]}"; do
    if [[ -f "$src" ]]; then
      local size lines
      size=$(wc -c < "$src" | tr -d ' ')
      lines=$(wc -l < "$src" | tr -d ' ')
      echo "  ✓ $src ($lines lines, $size bytes)"
      found=$((found + 1))
    fi
  done

  if [[ -d "$RULES_DIR" ]]; then
    local rules_count
    rules_count=$(find "$RULES_DIR" -maxdepth 2 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$rules_count" -gt 0 ]]; then
      echo "  ✓ $RULES_DIR/ ($rules_count rule files)"
      found=$((found + rules_count))
    fi
  fi

  echo ""
  if [[ "$found" -eq 0 ]]; then
    echo "No ingestable sources found. The cued-recall memory will populate"
    echo "organically as you intervene with the model. No action needed."
    return 0
  fi

  echo "Found $found source(s). Run with 'ingest' to convert to cued-recall memories:"
  echo "  bash hooks/memory-bootstrap.sh ingest"
  return 0
}

ingest_sources() {
  mkdir -p "$MEMORY_DIR/episodes" "$MEMORY_DIR/concepts" "$MEMORY_DIR/guards"

  # Initialize index if absent
  if [[ ! -f "$INDEX_FILE" ]]; then
    cat > "$INDEX_FILE" <<'EOF'
{
  "version": 2,
  "memories": {},
  "by_path": {},
  "by_symbol": {},
  "by_intent": {},
  "by_language": {}
}
EOF
  fi

  echo "Bootstrap ingestion is intentionally deferred to the model."
  echo ""
  echo "The cued-recall design (ADR-0001) requires that captures be validated"
  echo "by the user. Auto-ingestion would defeat that filter and create"
  echo "cargo-cult memories from docs that may already be stale."
  echo ""
  echo "Workflow:"
  echo "  1. The model reads the sources listed by 'scan' above."
  echo "  2. For each candidate entry (e.g. each [date] line in lessons.md,"
  echo "     each rule in .claude/rules/), the model proposes a memory:"
  echo "       - title (1 line)"
  echo "       - tags: paths, symbols, intents, language"
  echo "       - content (the lesson itself)"
  echo "  3. The user validates or skips per entry."
  echo "  4. Validated entries are written to .ciel/memory/episodes/"
  echo "     with frontmatter, and index.json is updated."
  echo ""
  echo "The model uses the skill 'memoire' to perform this. Initialized"
  echo "structure at $MEMORY_DIR/."
  return 0
}

status_corpus() {
  if [[ ! -f "$INDEX_FILE" ]]; then
    echo "No memory corpus yet at $MEMORY_DIR/."
    echo "Run: bash hooks/memory-bootstrap.sh scan"
    return 0
  fi

  INDEX_FILE="$INDEX_FILE" python3 - <<'PYEOF'
import json, os
from datetime import datetime, timezone
try:
    with open(os.environ['INDEX_FILE']) as f:
        idx = json.load(f)
    mems = idx.get('memories', {})
    total = len(mems)
    stale = sum(1 for m in mems.values() if m.get('stale'))
    active = total - stale
    triggered = sum(m.get('trigger_count', 0) for m in mems.values())
    by_lang = {}
    for m in mems.values():
        for lang in m.get('languages', []) or ['unknown']:
            by_lang[lang] = by_lang.get(lang, 0) + 1
    print(f"Cued-recall memory corpus")
    print(f"  Total memories : {total}")
    print(f"  Active         : {active}")
    print(f"  Stale          : {stale}")
    print(f"  Total triggers : {triggered}")
    if by_lang:
        print(f"  By language    : " + ", ".join(f"{k}={v}" for k, v in sorted(by_lang.items())))
    print(f"  Index version  : {idx.get('version', '?')}")
except Exception as e:
    print(f"Could not read index: {e}")
PYEOF
}

case "$CMD" in
  scan)    scan_sources ;;
  ingest)  ingest_sources ;;
  status)  status_corpus ;;
  *)
    echo "Usage: $0 {scan|ingest|status}"
    echo ""
    echo "  scan    — Report what would be ingested (default, dry-run)"
    echo "  ingest  — Initialize .ciel/memory/ structure and instruct model to ingest"
    echo "  status  — Report current corpus stats"
    exit 1
    ;;
esac

exit 0
