#!/bin/bash
# Ciel — Memory Bootstrap (cued-recall)
# Trigger: invoked manually by /ciel-memory-bootstrap or programmatically
# Purpose: scan project for ingestable tribal docs and report findings
# Usage:
#   memory-bootstrap.sh scan          → report what would be ingested (dry-run, default)
#   memory-bootstrap.sh ingest        → actually create memories from sources
#   memory-bootstrap.sh status        → report current memory corpus stats
#   memory-bootstrap.sh github-scan   → scan GitHub issues/PRs for tribal knowledge
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

# Claude Code's per-project auto-memory dir. Lives OUTSIDE the repo, derived
# from cwd with `/` replaced by `-`. Tests override via CIEL_AUTO_MEMORY_DIR.
# Pattern: ~/.claude/projects/-Users-foo-Projects-Bar/memory/
AUTO_MEMORY_DIR="${CIEL_AUTO_MEMORY_DIR:-$HOME/.claude/projects/$(echo "$PROJECT_DIR" | sed 's|/|-|g')/memory}"

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

  # Claude Code auto-memory — excludes the MEMORY.md index file (just a TOC,
  # not memory content). Each *.md sibling is a discrete entry to migrate.
  if [[ -d "$AUTO_MEMORY_DIR" ]]; then
    local auto_count
    auto_count=$(find "$AUTO_MEMORY_DIR" -maxdepth 1 -name "*.md" -type f -not -name "MEMORY.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$auto_count" -gt 0 ]]; then
      echo "  ✓ $AUTO_MEMORY_DIR/ ($auto_count Claude Code auto-memory entries — to migrate to .ciel/memory/)"
      found=$((found + auto_count))
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

github_scan() {
  local repo
  repo=$(gh repo view --json name,owner --jq '"\(.owner.login)/\(.name)"' 2>/dev/null) || {
    echo "GitHub CLI (gh) not authenticated or no remote found."
    echo "Run 'gh auth login' first or configure a remote."
    return 0
  }

  echo "Scanning GitHub repository $repo for tribal knowledge..."
  echo ""

  # ─── Issues ────────────────────────────────────────────────────────────────
  echo "=== Issues ==="
  echo ""

  # Fetch last 50 closed+open issues with comments
  gh issue list --repo "$repo" --limit 50 --state all --json number,title,body,labels,state,comments,url 2>/dev/null | \
    python3 -c "
import json, sys

try:
    issues = json.load(sys.stdin)
except Exception as e:
    print(f'  Error parsing issues: {e}')
    sys.exit(0)

found = 0
for issue in issues:
    body = issue.get('body') or ''
    title = issue.get('title', '')
    url = issue.get('url', '')
    labels = ', '.join(l.get('name','') for l in issue.get('labels',[]))
    comments = issue.get('comments') or []
    state = issue.get('state', '')
    all_text = body + ' ' + ' '.join(c.get('body','') for c in comments)

    signals = []
    for keyword in ['MISTAKE', 'RULE:', 'lesson learned', 'never do', 'we decided', 'chose', 'opted for', 'considered.*but', 'TODO', 'REASON:']:
        if keyword.lower() in all_text.lower():
            signals.append(keyword)

    if signals or len(all_text) > 200:
        found += 1
        print(f'  [{state}] #{issue.get(\"number\")} - {title}')
        print(f'    URL: {url}')
        if labels:
            print(f'    Labels: {labels}')
        if signals:
            print(f'    Signals: {', '.join(set(signals))}')
        body_preview = body[:300].replace(chr(10), ' ') if body else '(empty)'
        print(f'    Body: {body_preview}...' if len(body) > 300 else f'    Body: {body_preview}')
        if comments:
            for i, c in enumerate(comments[:3]):
                cbody = (c.get('body') or '')[:200].replace(chr(10), ' ')
                print(f'    Comment {i+1}: {cbody}...' if len((c.get('body') or '')) > 200 else f'    Comment {i+1}: {cbody}')
            if len(comments) > 3:
                print(f'    ... +{len(comments)-3} more comments')
        print()

if found == 0:
    print('  No issues with detectable tribal knowledge found.')
else:
    print(f'  Found {found} issue(s) with potential tribal knowledge.')
" 2>/dev/null || echo "  Error fetching issues. Is 'gh' installed?"

  echo ""
  echo "=== Pull Requests ==="
  echo ""

  # Fetch last 50 merged+open PRs
  gh pr list --repo "$repo" --limit 50 --state all --json number,title,body,state,mergedAt,comments,url,additions,deletions 2>/dev/null | \
    python3 -c "
import json, sys

try:
    prs = json.load(sys.stdin)
except Exception as e:
    print(f'  Error parsing PRs: {e}')
    sys.exit(0)

found = 0
for pr in prs:
    body = pr.get('body') or ''
    title = pr.get('title', '')
    url = pr.get('url', '')
    comments = pr.get('comments') or []
    state = 'MERGED' if pr.get('mergedAt') else pr.get('state', '').upper()
    all_text = body + ' ' + ' '.join(c.get('body','') for c in comments)

    signals = []
    for keyword in ['MISTAKE', 'RULE:', 'lesson learned', 'never do', 'we decided', 'chose', 'opted for', 'considered.*but', 'TODO', 'REASON:', 'trade-off', 'alternative']:
        if keyword.lower() in all_text.lower():
            signals.append(keyword)

    if signals or len(all_text) > 200:
        found += 1
        print(f'  [{state}] #{pr.get(\"number\")} - {title}')
        print(f'    URL: {url}')
        size = pr.get('additions',0)+pr.get('deletions',0)
        print(f'    Size: +{pr.get(\"additions\",0)}/-{pr.get(\"deletions\",0)} ({size} lines)')
        if signals:
            print(f'    Signals: {', '.join(set(signals))}')
        body_preview = body[:300].replace(chr(10), ' ') if body else '(empty)'
        print(f'    Description: {body_preview}...' if len(body) > 300 else f'    Description: {body_preview}')
        if comments:
            for i, c in enumerate(comments[:3]):
                cbody = (c.get('body') or '')[:200].replace(chr(10), ' ')
                print(f'    Comment {i+1}: {cbody}...' if len((c.get('body') or '')) > 200 else f'    Comment {i+1}: {cbody}')
            if len(comments) > 3:
                print(f'    ... +{len(comments)-3} more comments')
        print()

if found == 0:
    print('  No PRs with detectable tribal knowledge found.')
else:
    print(f'  Found {found} PR(s) with potential tribal knowledge.')
" 2>/dev/null || echo "  Error fetching PRs."

  echo "---"
  echo "GitHub scan complete. To ingest these into cued-recall memory,"
  echo "the model will read each candidate and propose entries for validation."
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
  github-scan|github)  github_scan ;;
  *)
    echo "Usage: $0 {scan|ingest|status|github-scan}"
    echo ""
    echo "  scan         — Report what would be ingested (default, dry-run)"
    echo "  ingest       — Initialize .ciel/memory/ structure and instruct model to ingest"
    echo "  status       — Report current corpus stats"
    echo "  github-scan  — Scan GitHub issues/PRs for tribal knowledge"
    exit 1
    ;;
esac

exit 0
