#!/usr/bin/env python3
"""Ciel cued-recall memory engine.

Subcommands:
  query         — given prompt + cwd, return top-K memories under token cap.
                  Updates trigger_count and last_triggered for matched memories.
                  Marks stale entries on the fly.
  init          — create empty .ciel/memory/{episodes,concepts,guards}/ + index.json
  rebuild-index — scan all *.md frontmatter, regenerate index.json from source

Designed to be called from hooks/user-prompt-submit.sh and from
hooks/memory-bootstrap.sh. No external Python dependencies (stdlib only) —
must run wherever Ciel is installed without `pip install`.

See docs/adrs/0001-cued-recall-memory.md for design rationale.
"""

import sys
import os
import json
import math
import re
import fnmatch
import argparse
import secrets
from datetime import datetime, timezone
from pathlib import Path

# ─── Structured Logging ──────────────────────────────────────────────────────

def _log(level, message, **context):
    """Write structured JSON log line to stderr. Never touches stdout."""
    entry = {
        "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
        "level": level,
        "msg": message,
        **context,
    }
    print(json.dumps(entry, ensure_ascii=False), file=sys.stderr)

# ─── Constants ──────────────────────────────────────────────────────────────

TOKEN_CAPS = {
    "trivial": 1000,
    "standard": 3000,
    "critical": 5000,
}

# Map file extensions to language tags. Used for language scoping.
LANG_BY_EXT = {
    ".ts": "typescript", ".tsx": "typescript",
    ".js": "javascript", ".jsx": "javascript", ".mjs": "javascript",
    ".py": "python",
    ".kt": "kotlin", ".kts": "kotlin",
    ".go": "go",
    ".rs": "rust",
    ".sql": "sql",
    ".sh": "bash", ".bash": "bash",
    ".rb": "ruby",
    ".java": "java",
    ".cs": "csharp",
    ".php": "php",
    ".swift": "swift",
    ".c": "c", ".cpp": "cpp", ".cc": "cpp", ".h": "c", ".hpp": "cpp",
    ".md": "markdown",
}

# Common intent keywords. Extensible; first match wins per kw.
INTENT_KEYWORDS = [
    ("migration", "schema-change"),
    ("schema", "schema-change"),
    ("alter table", "schema-change"),
    ("route", "new-route"),
    ("endpoint", "new-route"),
    ("controller", "new-route"),
    ("component", "new-component"),
    ("test", "testing"),
    ("vitest", "testing"),
    ("jest", "testing"),
    ("pytest", "testing"),
    ("deploy", "deploy"),
    ("release", "deploy"),
    ("ci/cd", "deploy"),
    ("auth", "auth"),
    ("login", "auth"),
    ("oauth", "auth"),
    ("jwt", "auth"),
    ("session", "auth"),
    ("payment", "payment"),
    ("stripe", "payment"),
    ("webhook", "webhook"),
    ("hook", "hook"),
    ("refactor", "refactor"),
    ("rename", "rename"),
]

# ─── Cue extraction ─────────────────────────────────────────────────────────


def estimate_tokens(text: str) -> int:
    """Rough token estimate: 1 token ≈ 4 chars (English/code)."""
    return max(1, len(text) // 4)


# URL/domain patterns that should never be treated as file paths. Matches
# example.com/foo, github.com/x, api.service.io/...
_URL_TLD_RE = re.compile(r'^[\w-]+\.(com|org|io|dev|sh|net|co|me|app|cloud|ai|gg|run|site|xyz|page|blog)\b', re.I)

# Built-in/standard-library names that look like PascalCase but are too generic
# to be useful symbol cues. Mentioning "Promise" in prose shouldn't fire any memory.
_SYMBOL_STOPLIST = frozenset({
    'Promise', 'Array', 'String', 'Number', 'Object', 'Map', 'Set', 'Date',
    'Error', 'Boolean', 'JSON', 'Math', 'RegExp', 'Symbol', 'Function',
    'List', 'Dict', 'Tuple', 'None', 'True', 'False', 'Any',  # Python
    'When', 'Then', 'After', 'Before', 'While', 'If', 'Else', 'Otherwise',
    'TODO', 'FIXME', 'NOTE', 'XXX', 'HACK', 'NB',
})


def extract_path_cues(prompt: str):
    """Find file/path-like tokens in the prompt.

    Filters out URLs, version ratios (1/2), and bare domains. False positives
    on a path-shaped token still get filtered at scoring time when fnmatch
    finds no match against any memory's path_patterns.
    """
    raw = re.findall(r'[\w./*\-]+/[\w./*\-]+|\b[\w-]+\.[a-z]{1,5}\b', prompt)
    cleaned = []
    for p in raw:
        # Strip only TRAILING punctuation (paths can legitimately start with
        # `.` — `.claude/settings.json`, `.gitignore`, `.env`). Leading-dot
        # stripping was a v1 bug that made dotfile paths invisible.
        p = p.rstrip('.,)(\'"`')
        # Strip a few common leading punctuation chars but NEVER the dot.
        p = p.lstrip(',)(\'"`')
        if not p or len(p) <= 2:
            continue
        # Drop URLs / domains (github.com/foo, example.com/bar).
        if _URL_TLD_RE.match(p):
            continue
        # Drop protocol-prefixed cruft from raw URL captures.
        if p.startswith('//') or p.startswith('http'):
            continue
        # Drop pure numeric ratios like "1/2", "2026-05-08".
        if re.match(r'^[\d./-]+$', p):
            continue
        cleaned.append(p)
    return cleaned


def extract_symbol_cues(prompt: str):
    """Extract camelCase, PascalCase, and snake_case identifiers.

    Filters out the symbol stoplist (built-ins like Promise/Array/String,
    English sentence-starts like When/Then/After) to avoid score inflation
    from prose. PascalCase requires ≥2 capital transitions to skip plain
    capitalized words.
    """
    out = set()
    out.update(re.findall(r'\b[a-z]+(?:[A-Z][a-zA-Z0-9]+)+\b', prompt))                    # camelCase
    # PascalCase: require at least one inner camel boundary (≥2 capitals).
    # `+` not `*` rejects single-capital words like "When" / "Then".
    out.update(re.findall(r'\b[A-Z][a-z0-9]+(?:[A-Z][a-zA-Z0-9]+)+\b', prompt))            # PascalCase
    out.update(re.findall(r'\b[a-z]+(?:_[a-z0-9]+){2,}\b', prompt))                        # snake_case (≥2 underscores)
    return [s for s in out if s not in _SYMBOL_STOPLIST]


def extract_intent_cues(prompt: str):
    """Detect intent keywords in the prompt. Lowercase substring match."""
    p = prompt.lower()
    intents = set()
    for kw, label in INTENT_KEYWORDS:
        if kw in p:
            intents.add(label)
    return list(intents)


def extract_language_cues(prompt: str):
    """Infer programming language from file extensions mentioned in prompt."""
    langs = set()
    for ext, lang in LANG_BY_EXT.items():
        if re.search(rf'\b\w+{re.escape(ext)}\b', prompt):
            langs.add(lang)
    return list(langs)


# ─── Matching & scoring ─────────────────────────────────────────────────────


# Cache for compiled glob-to-regex patterns. Patterns are read from the corpus
# and rarely change between calls within a single hook invocation.
_PATTERN_CACHE = {}


def _glob_to_regex(pattern: str):
    """Translate a gitignore-style glob (with `**`) to a Python regex.

    `**` matches any sequence including slashes (recursive).
    `*`  matches any sequence excluding slashes (single segment).
    `?`  matches a single non-slash char.
    Other characters are escaped literally.

    fnmatch.fnmatch's `*` greedily eats slashes too, which silently produces
    false positives on patterns like `src/*.ts`. This translator is stricter
    and matches what users coming from gitignore/tsconfig expect.
    """
    if pattern in _PATTERN_CACHE:
        return _PATTERN_CACHE[pattern]
    out = []
    i = 0
    n = len(pattern)
    while i < n:
        c = pattern[i]
        if c == '*':
            if i + 1 < n and pattern[i + 1] == '*':
                # `**` — match any sequence (including /)
                out.append('.*')
                i += 2
                # Eat trailing `/` after `**` for clean alignment
                if i < n and pattern[i] == '/':
                    i += 1
            else:
                # `*` — match anything except /
                out.append('[^/]*')
                i += 1
        elif c == '?':
            out.append('[^/]')
            i += 1
        elif c in '.+()^$|{}\\[]':
            out.append('\\' + c)
            i += 1
        else:
            out.append(c)
            i += 1
    compiled = re.compile('^' + ''.join(out) + '$')
    _PATTERN_CACHE[pattern] = compiled
    return compiled


def match_path_pattern(pattern: str, paths) -> bool:
    """Match a glob pattern against any candidate path. Supports `**`."""
    rx = _glob_to_regex(pattern)
    for path in paths:
        if rx.match(path):
            return True
    return False


def score_memory(mem, paths, symbols, intents, langs, prompt_lower="") -> int:
    """Score a memory's relevance. 0 = exclude. Positive = include, higher first.

    Symbol and intent matching are case-insensitive and fall back to a
    word-boundary search against the raw prompt. This lets a memory tagged
    `symbols: [OkHttp]` fire on a prompt that mentions "okhttp" in prose,
    and lets free-form intent tags (e.g. `intents: [okhttp, diagnostics]`)
    match without being members of the fixed INTENT_KEYWORDS vocabulary.
    Word boundaries prevent "test" intent from firing on "contest".
    """
    # Hard language gate: if memory is language-specific AND prompt has language
    # cues AND no overlap → exclude. Avoids Kotlin memories firing on TS edits.
    mem_langs = mem.get('languages') or []
    if mem_langs and langs and not (set(mem_langs) & set(langs)):
        return 0

    score = 0
    for pattern in mem.get('path_patterns') or []:
        if match_path_pattern(pattern, paths):
            score += 10

    # Case-insensitive comparison sets — built once per memory call.
    symbols_lower = {s.lower() for s in symbols}
    intents_lower = {i.lower() for i in intents}

    for sym in mem.get('symbols') or []:
        sym_lower = sym.lower()
        if sym_lower in symbols_lower or (
            prompt_lower and re.search(r'\b' + re.escape(sym_lower) + r'\b', prompt_lower)
        ):
            score += 8

    for intent in mem.get('intents') or []:
        intent_lower = intent.lower()
        if intent_lower in intents_lower or (
            prompt_lower and re.search(r'\b' + re.escape(intent_lower) + r'\b', prompt_lower)
        ):
            score += 5

    # No cue match at all → don't include (cued recall, not free recall)
    if score == 0:
        return 0

    # Boost for proven utility (frequent triggers)
    score += min(mem.get('trigger_count') or 0, 10)

    # Recency factor — clamp negative ages (clock skew, future-dated entries)
    last = mem.get('last_triggered') or mem.get('captured_at')
    if last:
        try:
            then = datetime.fromisoformat(last.replace('Z', '+00:00'))
            age_days = max(0, (datetime.now(timezone.utc) - then).days)
            if age_days < 7:
                score += 5
            elif age_days < 30:
                score += 2
            elif age_days > 180:
                score -= 3
        except (ValueError, TypeError):
            pass

    return score


# ─── Decay ──────────────────────────────────────────────────────────────────


def mark_stale_inplace(memories: dict, now: datetime) -> int:
    """Flag stale=True for memories past their Ebbinghaus-adjusted threshold.

    Returns count newly marked. Active memories that have never been triggered
    decay from captured_at; triggered memories from last_triggered.

    Threshold scales with trigger_count using an Ebbinghaus-style forgetting
    curve: well-triggered memories decay slower (stronger engrams). A memory
    triggered 15+ times gets ~5x the base threshold (450 days vs 90).

    Future-dated anchors (clock skew, manual edit) are clamped to now, making
    those memories immune to staling regardless of timestamp source.
    """
    newly_stale = 0
    for mid, m in memories.items():
        if m.get('stale'):
            continue
        anchor = m.get('last_triggered') or m.get('captured_at')
        base_threshold = m.get('stale_after_days', 90)
        if not anchor:
            continue
        try:
            then = datetime.fromisoformat(anchor.replace('Z', '+00:00'))
            age_days = max(0, (now - then).days)
            # Ebbinghaus-style strength factor: more triggers = slower decay.
            # log2(1+count) gives: 0→1x, 1→2x, 3→3x, 7→4x, 15→5x
            tc = max(0, m.get('trigger_count') or 0)
            strength = 1.0 + math.log2(1 + tc)
            effective_threshold = base_threshold * strength
            if age_days > effective_threshold:
                m['stale'] = True
                newly_stale += 1
        except (ValueError, TypeError):
            pass
    return newly_stale


# ─── Subcommands ────────────────────────────────────────────────────────────


def resolve_cwd(arg_cwd):
    return Path(arg_cwd or os.environ.get('CLAUDE_PROJECT_DIR') or os.getcwd())


def atomic_write_json(path: Path, data) -> None:
    """Write JSON atomically via per-process tmp file + rename.

    Per-process unique tmp prevents two concurrent writers from corrupting
    each other's tmp during the write phase. Rename is atomic on the same
    filesystem.

    NOTE: this prevents *partial writes*, not *lost updates*. If session A
    and session B both read index.json at the same time, increment, and
    write, the later writer wins. For lock-protected read-modify-write,
    use atomic_update_index() which holds an fcntl advisory lock for the
    full read-update-write cycle.
    """
    tmp = path.with_suffix(f'.{os.getpid()}.{secrets.token_hex(2)}.tmp')
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    tmp.replace(path)


def atomic_update_index(path: Path, mutator):
    """Read-modify-write index.json under an fcntl advisory lock.

    `mutator` is a callable taking the parsed dict and mutating it in place
    (or returning a new dict). Returns the final dict written to disk.

    This serializes concurrent sessions: each waits for the previous to
    finish its read-modify-write before proceeding. Trigger increments
    therefore compose correctly (8 → 9 → 10) instead of last-writer-wins.

    On platforms without fcntl (Windows), falls back to plain atomic write
    without the lock — accept lost-update risk on those platforms.
    """
    try:
        import fcntl
    except ImportError:
        # Windows fallback — no advisory lock available in stdlib
        if path.exists():
            with open(path, encoding='utf-8') as f:
                data = json.load(f)
        else:
            data = {}
        result = mutator(data)
        final = result if result is not None else data
        atomic_write_json(path, final)
        return final

    # POSIX: hold an exclusive lock on the index file for the read-write cycle.
    # Open in r+ mode so we can read and write through the same fd.
    if not path.exists():
        atomic_write_json(path, {})
    with open(path, 'r+', encoding='utf-8') as f:
        fcntl.flock(f.fileno(), fcntl.LOCK_EX)
        try:
            f.seek(0)
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                data = {}
            result = mutator(data)
            final = result if result is not None else data
            f.seek(0)
            f.truncate()
            json.dump(final, f, indent=2, ensure_ascii=False)
            f.flush()
            os.fsync(f.fileno())
        finally:
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)
    return final


def cmd_query(args):
    cwd = resolve_cwd(args.cwd)
    index_file = cwd / '.ciel' / 'memory' / 'index.json'
    if not index_file.exists():
        return  # Silent: no memory corpus yet

    prompt = args.prompt or ''
    cap = TOKEN_CAPS.get((args.depth or 'standard').lower(), 3000)

    paths = extract_path_cues(prompt)
    symbols = extract_symbol_cues(prompt)
    intents = extract_intent_cues(prompt)
    langs = extract_language_cues(prompt)
    prompt_lower = prompt.lower()
    now = datetime.now(timezone.utc)
    iso_now = now.isoformat().replace('+00:00', 'Z')

    # The selection is computed inside the mutator so it sees the
    # locked-and-fresh state, then the same mutator persists triggers.
    output_lines = []
    output_used = [0]

    def mutator(idx):
        mems = idx.get('memories', {})
        if not mems:
            return idx

        mark_stale_inplace(mems, now)

        scored = []
        # Language pre-filter: when prompt has language cues (e.g. ".ts" →
        # "typescript"), skip memories tagged with non-matching languages.
        # Language-agnostic memories (no language tags) always included.
        # This is safe because score_memory's hard language gate would return 0
        # for these memories anyway — we skip the path/symbol/intent scoring.
        if langs:
            langs_lower = {l.lower() for l in langs}
            for mid, m in mems.items():
                if m.get('stale'):
                    continue
                mem_langs = m.get('languages') or []
                if not mem_langs or any(l.lower() in langs_lower for l in mem_langs):
                    s = score_memory(m, paths, symbols, intents, langs, prompt_lower=prompt_lower)
                    if s > 0:
                        scored.append((s, mid, m))
        else:
            for mid, m in mems.items():
                if m.get('stale'):
                    continue
                s = score_memory(m, paths, symbols, intents, langs, prompt_lower=prompt_lower)
                if s > 0:
                    scored.append((s, mid, m))

        if not scored:
            return idx

        scored.sort(key=lambda x: -x[0])

        selected = []
        used = estimate_tokens("Cued-recall memory matches:\n")
        overhead = estimate_tokens(
            "\nRead full content from .ciel/memory/{episodes,concepts,guards}/ when relevant."
        )
        budget = cap - overhead
        for _, mid, m in scored:
            line = f"  [{mid}, fired {m.get('trigger_count', 0)}×] {m.get('title', '?')}"
            cost = estimate_tokens(line) + 1
            if used + cost > budget:
                break
            used += cost
            selected.append((mid, m, line))

        if not selected:
            return idx

        # Update triggers under the lock — composes correctly across sessions
        for mid, m, _ in selected:
            m['trigger_count'] = (m.get('trigger_count') or 0) + 1
            m['last_triggered'] = iso_now
            m['last_edited'] = iso_now

        for _, _, line in selected:
            output_lines.append(line)
        output_used[0] = used
        return idx

    atomic_update_index(index_file, mutator)

    if not output_lines:
        return

    print("Cued-recall memory matches:")
    for line in output_lines:
        print(line)
    print(f"Read full content from .ciel/memory/{{episodes,concepts,guards}}/ when relevant. ({output_used[0]}/{cap} tokens)")


def cmd_init(args):
    cwd = resolve_cwd(args.cwd)
    base = cwd / '.ciel' / 'memory'
    for sub in ('episodes', 'concepts', 'guards'):
        (base / sub).mkdir(parents=True, exist_ok=True)
    index_file = base / 'index.json'
    if not index_file.exists():
        atomic_write_json(index_file, {
            "version": 2,
            "memories": {},
            "by_path": {},
            "by_symbol": {},
            "by_intent": {},
            "by_language": {},
        })
        print(f"Initialized memory corpus at {base}/")
    else:
        print(f"Memory corpus already exists at {base}/")


# Fields whose values must remain string regardless of how they look.
# Prevents int-coercion of numeric-looking ids (e.g. "12345") which would
# break the index keying and JSON round-trip.
_STRING_FIELDS = frozenset({'id', 'title', 'last_triggered', 'captured_at', 'last_edited', 'file', 'source', 'captured_from'})


def parse_yaml_frontmatter(text: str) -> dict:
    """Minimal YAML parser for the frontmatter dialect we use.

    Supports: scalar key:value, inline arrays [a, b], block lists with
    '  - item' continuations, booleans (true/false), null. No anchors,
    no nested maps. Sufficient for our frontmatter schema.

    String-typed fields (id, title, timestamps) are NEVER int-coerced, even
    if they look numeric. See _STRING_FIELDS.
    """
    out = {}
    current_list_key = None
    for raw_line in text.split('\n'):
        if not raw_line.strip() or raw_line.strip().startswith('#'):
            continue
        if raw_line.startswith('  - ') or raw_line.startswith('- '):
            if current_list_key:
                val = raw_line.lstrip(' -').strip().strip('"\'')
                out.setdefault(current_list_key, []).append(val)
            continue
        if ':' in raw_line:
            key, _, val = raw_line.partition(':')
            key = key.strip()
            val = val.strip()
            current_list_key = None
            if not val:
                current_list_key = key
                out[key] = []
            elif val.startswith('[') and val.endswith(']'):
                inner = val[1:-1].strip()
                items = []
                seen = set()
                for x in inner.split(','):
                    x = x.strip().strip('"\'')
                    if x and x not in seen:
                        seen.add(x)
                        items.append(x)
                out[key] = items
            elif val.lower() == 'null' or val == '~':
                out[key] = None
            elif key in _STRING_FIELDS:
                # Hard-typed as string regardless of numeric appearance.
                # Null check above takes precedence so explicit nulls survive.
                out[key] = val.strip('"\'')
            elif val.lower() == 'true':
                out[key] = True
            elif val.lower() == 'false':
                out[key] = False
            else:
                try:
                    out[key] = int(val)
                except ValueError:
                    out[key] = val.strip('"\'')
    return out


def cmd_rebuild_index(args):
    cwd = resolve_cwd(args.cwd)
    base = cwd / '.ciel' / 'memory'
    if not base.exists():
        _log("error", "No memory directory", path=str(base))
        sys.exit(1)

    # Preserve trigger counts from existing index. cmd_query updates counts
    # in the index but does not write back to episode frontmatter; rebuilding
    # from scratch would lose all accumulated trigger history.
    old_index = base / 'index.json'
    old_mems = {}
    if old_index.exists():
        try:
            with open(old_index) as f:
                old_data = json.load(f)
            old_mems = old_data.get('memories') or {}
        except (json.JSONDecodeError, OSError):
            pass

    # Index schema contract (version 2)
    # ─────────────────────────────────────────────────────────────────
    # memories:     mid → frontmatter          1:1  PK — mid is unique
    # by_path:      pattern → [mid, ...]       1:N  FK → memories
    # by_symbol:    symbol  → [mid, ...]       1:N  FK → memories
    # by_intent:    intent  → [mid, ...]       1:N  FK → memories
    # by_language:  lang    → [mid, ...]       1:N  FK → memories
    #
    # Guarantees (enforced at rebuild time):
    #   G1 — Referential integrity: every mid in any index exists in memories
    #   G2 — No self-duplicates: a given (key, mid) pair appears at most once
    #        per index list (setdefault+append is safe when source frontmatter
    #        has no duplicate entries — which the parser guarantees)
    #   G3 — Index values are always lists, never None/scalar
    #   G4 — No orphan index keys: empty [] keys are pruned after build
    #
    # Non-guarantees (by design):
    #   - Order within index lists is insertion order (filesystem order), not
    #     relevance-sorted. Callers (cmd_query) re-rank by trigger_count.
    #   - Duplicate mids across different keys in the same index: a memory
    #     with symbols [auth, oauth] appears under both keys. This is correct.
    #   - Index is a cache: rebuild-index reconstructs it from source .md files.
    #     The source of truth is always the .md frontmatter, never the index.
    idx = {
        "version": 2,
        "memories": {},
        "by_path": {},
        "by_symbol": {},
        "by_intent": {},
        "by_language": {},
    }

    parsed = 0
    for mdfile in base.rglob('*.md'):
        if mdfile.name.lower() in ('readme.md', 'review-queue.md', 'insights.md'):
            continue
        try:
            content = mdfile.read_text(encoding='utf-8')
            m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
            if not m:
                continue
            fm = parse_yaml_frontmatter(m.group(1))
            mid = fm.get('id')
            if not mid:
                continue
            # Merge: keep the higher trigger_count between old index and file frontmatter
            old = old_mems.get(mid) if old_mems else None
            if old:
                old_tc = old.get('trigger_count') or 0
                file_tc = fm.get('trigger_count') or 0
                fm['trigger_count'] = max(old_tc, file_tc)
                old_lt = old.get('last_triggered')
                if old_lt and not fm.get('last_triggered'):
                    fm['last_triggered'] = old_lt
                old_le = old.get('last_edited')
                new_le = fm.get('last_edited')
                if old_le and (not new_le or old_le > new_le):
                    fm['last_edited'] = old_le
            fm['file'] = str(mdfile.relative_to(base))
            idx['memories'][mid] = fm
            for path in fm.get('path_patterns') or []:
                idx['by_path'].setdefault(path, []).append(mid)
            for sym in fm.get('symbols') or []:
                idx['by_symbol'].setdefault(sym, []).append(mid)
            for intent in fm.get('intents') or []:
                idx['by_intent'].setdefault(intent, []).append(mid)
            for lang in fm.get('languages') or []:
                idx['by_language'].setdefault(lang, []).append(mid)
            parsed += 1
        except (OSError, UnicodeDecodeError) as e:
            _log("warn", "Skipping unparseable memory file", file=str(mdfile), error=str(e))

    # Integrity checks (G1, G3)
    mid_set = set(idx['memories'].keys())
    for index_name in ('by_path', 'by_symbol', 'by_intent', 'by_language'):
        idx_map = idx[index_name]
        empty_keys = [k for k, v in idx_map.items() if not v]
        for k in empty_keys:
            del idx_map[k]
        for key, mids in idx_map.items():
            orphans = [m for m in mids if m not in mid_set]
            if orphans:
                _log("warn", "Dangling reference in index — repaired",
                     index=index_name, key=key, orphans=orphans)
                idx_map[key] = [m for m in mids if m in mid_set]

    out = base / 'index.json'
    atomic_write_json(out, idx)
    print(f"Rebuilt index: {parsed} memories")


def cmd_new_id(args):
    """Emit a fresh, collision-free memory id.

    Format: mem_<unix_seconds>_<6 hex chars>. Two parallel sessions calling
    this within the same second still get distinct ids (~16M space per sec).
    """
    ts = int(datetime.now(timezone.utc).timestamp())
    suffix = secrets.token_hex(3)
    print(f"mem_{ts}_{suffix}")


def cmd_capture(args):
    cwd = resolve_cwd(args.cwd)
    base = cwd / '.ciel' / 'memory'
    mem_type = args.type or 'episode'
    target_dir = base / (mem_type + 's' if not mem_type.endswith('s') else mem_type)

    if not target_dir.exists():
        target_dir.mkdir(parents=True, exist_ok=True)

    ts = int(datetime.now(timezone.utc).timestamp())
    suffix = secrets.token_hex(3)
    mid = f"mem_{ts}_{suffix}"

    now = datetime.now(timezone.utc)
    iso_now = now.isoformat().replace('+00:00', 'Z')
    date_str = now.strftime('%Y-%m-%d')

    slug = re.sub(r'[^a-z0-9]+', '-', args.title.lower()).strip('-')[:60]
    filename = f"{date_str}-{slug}.md"

    languages = [l.strip() for l in (args.languages or '').split(',') if l.strip()]
    path_patterns = [p.strip() for p in (args.path_patterns or '').split(',') if p.strip()]
    symbols = [s.strip() for s in (args.symbols or '').split(',') if s.strip()]
    intents = [i.strip() for i in (args.intents or '').split(',') if i.strip()]

    content = args.content or args.title

    frontmatter = {
        "id": mid,
        "title": args.title,
        "languages": languages,
        "path_patterns": path_patterns,
        "symbols": symbols,
        "intents": intents,
        "captured_at": iso_now,
        "captured_from": args.captured_from or 'runtime',
        "source": args.source or 'manual capture',
        "last_edited": iso_now,
        "trigger_count": 0,
        "last_triggered": None,
        "stale_after_days": 90,
        "stale": False,
    }

    lines = ["---"]
    for key, val in frontmatter.items():
        if isinstance(val, list):
            lines.append(f"{key}:")
            if val:
                for item in val:
                    lines.append(f"  - \"{item}\"")
            else:
                lines.append("  []")
        elif val is None:
            lines.append(f"{key}: null")
        elif isinstance(val, bool):
            lines.append(f"{key}: {'true' if val else 'false'}")
        else:
            lines.append(f"{key}: {val}")
    lines.append("---")
    lines.append("")
    lines.append(f"# {args.title}")
    lines.append("")
    lines.append(content)
    lines.append("")

    episode_text = '\n'.join(lines)
    filepath = target_dir / filename
    filepath.write_text(episode_text, encoding='utf-8')
    print(f"Created: {filepath.relative_to(cwd)}")

    cmd_rebuild_index(args)
    print(f"Index rebuilt with memory: {mid}")


def cmd_analyze(args):
    """Mine recurring patterns across the corpus and emit insights.

    Read-only on memories. Computes promotion candidates, dead anchors,
    intent/path clusters and 7 health metrics, then writes:
      - .ciel/memory/insights.json (machine; consumed by ciel-audit Dim 10)
      - .ciel/memory/INSIGHTS.md (human digest)

    Min-support floor (3 memories) enforced by the engine — refuses to
    surface a "cluster" the model could narrate from sparse evidence.
    Generation cap is computed from optional `derived_from` chains so a
    future synthesizer cannot recurse on its own outputs without it
    showing up as a metric.
    """
    cwd = resolve_cwd(args.cwd)
    base = cwd / '.ciel' / 'memory'
    if not base.exists():
        _log("error", "No memory directory", path=str(base))
        sys.exit(1)

    index_file = base / 'index.json'
    if index_file.exists():
        with index_file.open('r', encoding='utf-8') as f:
            index = json.load(f)
    else:
        index = {"version": 2, "memories": {}, "by_path": {}, "by_symbol": {},
                 "by_intent": {}, "by_language": {}}

    memories = index.get('memories', {}) or {}
    by_intent = index.get('by_intent', {}) or {}
    by_path = index.get('by_path', {}) or {}

    MIN_PROMOTION = 5
    MIN_SUPPORT = 3

    episodes = {mid: m for mid, m in memories.items()
                if str(m.get('file', '')).startswith('episodes/')}
    concepts = {mid: m for mid, m in memories.items()
                if str(m.get('file', '')).startswith('concepts/')}
    guards = {mid: m for mid, m in memories.items()
              if str(m.get('file', '')).startswith('guards/')}

    promotion_candidates = [mid for mid, m in episodes.items()
                            if (m.get('trigger_count') or 0) >= MIN_PROMOTION]
    promotion_candidates.sort(key=lambda mid: -(episodes[mid].get('trigger_count') or 0))

    dead_anchors = []
    for mid, m in memories.items():
        patterns = m.get('path_patterns') or []
        if not patterns:
            continue
        alive = False
        for pat in patterns:
            try:
                # Path.glob raises NotImplementedError on absolute patterns
                # in Python 3.13+, so route absolute paths through Path.exists
                # directly. Relative patterns keep the glob (** support).
                if pat.startswith('/'):
                    if Path(pat).exists():
                        alive = True
                        break
                elif any(True for _ in cwd.glob(pat)):
                    alive = True
                    break
            except (ValueError, OSError, NotImplementedError):
                continue
        if not alive:
            dead_anchors.append(mid)
    dead_anchors.sort()

    intent_clusters = {k: sorted(v) for k, v in by_intent.items() if len(v) >= MIN_SUPPORT}
    path_clusters = {k: sorted(v) for k, v in by_path.items() if len(v) >= MIN_SUPPORT}

    now = datetime.now(timezone.utc)

    def days_ago(iso_str):
        if not iso_str:
            return None
        try:
            dt = datetime.fromisoformat(str(iso_str).replace('Z', '+00:00'))
            return (now - dt).days
        except (ValueError, TypeError):
            return None

    total = len(memories)

    recent = sum(1 for m in memories.values()
                 if (days_ago(m.get('captured_at')) or 10**6) <= 30)
    recency_30d_ratio = round(recent / total, 3) if total else 0.0

    intent_counts = [len(ids) for ids in by_intent.values() if ids]
    intent_diversity_entropy = 0.0
    if intent_counts:
        total_tags = sum(intent_counts)
        for c in intent_counts:
            p = c / total_tags
            intent_diversity_entropy -= p * math.log2(p)
        intent_diversity_entropy = round(intent_diversity_entropy, 3)

    dead_anchor_ratio = round(len(dead_anchors) / total, 3) if total else 0.0

    # Generation depth from optional `derived_from` chains. Cycle-guarded.
    def gen_depth(mid, seen):
        if mid in seen:
            return 0
        m = memories.get(mid, {})
        parents = m.get('derived_from') or []
        if not parents:
            return 1
        return 1 + max(gen_depth(p, seen | {mid}) for p in parents)

    max_generation_depth = max((gen_depth(mid, set()) for mid in memories), default=0)

    flat_intents = [i for m in memories.values() for i in (m.get('intents') or [])]
    tag_specificity = round(len(set(flat_intents)) / len(flat_intents), 3) if flat_intents else 0.0

    promotion_ratio = round(len(concepts) / len(episodes), 3) if episodes else 0.0

    corrections = sum(1 for m in episodes.values()
                      if m.get('captured_from') in ('user-intervention', 'intervention'))
    capture_correction_ratio = round(corrections / len(episodes), 3) if episodes else 0.0

    health = {
        "recency_30d_ratio": recency_30d_ratio,
        "intent_diversity_entropy": intent_diversity_entropy,
        "dead_anchor_ratio": dead_anchor_ratio,
        "max_generation_depth": max_generation_depth,
        "tag_specificity": tag_specificity,
        "promotion_ratio": promotion_ratio,
        "capture_correction_ratio": capture_correction_ratio,
    }

    insights = {
        "version": 1,
        "generated_at": now.isoformat().replace('+00:00', 'Z'),
        "corpus_size": {
            "episodes": len(episodes),
            "concepts": len(concepts),
            "guards": len(guards),
            "total": total,
        },
        "promotion_candidates": promotion_candidates,
        "dead_anchors": dead_anchors,
        "intent_clusters": intent_clusters,
        "path_clusters": path_clusters,
        "health": health,
        "thresholds": {
            "min_promotion_trigger_count": MIN_PROMOTION,
            "min_support_episodes": MIN_SUPPORT,
        },
    }

    insights_json = base / 'insights.json'
    atomic_write_json(insights_json, insights)

    # Cap human-readable INSIGHTS.md sections when the corpus is large.
    # insights.json (machine consumer) keeps everything; INSIGHTS.md is read
    # by humans + by ciel-audit narration so token cost matters at scale.
    LARGE_CORPUS_THRESHOLD = 150
    TOP_N = 10

    def maybe_cap(items):
        if total > LARGE_CORPUS_THRESHOLD and len(items) > TOP_N:
            return items[:TOP_N], len(items) - TOP_N
        return items, 0

    lines = [
        "# Memory insights",
        "",
        f"_Generated {insights['generated_at']} by `memory-engine.py analyze`. Read by `ciel-audit` Dim 10._",
        "",
        f"**Corpus**: {len(episodes)} episodes, {len(concepts)} concepts, {len(guards)} guards (total {total}).",
        "",
        "## Health metrics",
        "",
    ]
    for key, val in health.items():
        lines.append(f"- `{key}`: **{val}**")
    lines.append("")

    if promotion_candidates:
        shown, omitted = maybe_cap(promotion_candidates)
        lines += [
            "## Promotion candidates",
            "",
            f"Episodes triggered >= {MIN_PROMOTION} times. Promote via skill `memoire-consolidator`.",
            "",
        ]
        for mid in shown:
            m = episodes[mid]
            lines.append(f"- `{mid}` (trigger_count={m.get('trigger_count', 0)}) - {m.get('title', '?')}")
        if omitted:
            lines.append(f"- _+{omitted} more, see insights.json_")
        lines.append("")

    if dead_anchors:
        shown, omitted = maybe_cap(dead_anchors)
        lines += [
            "## Dead anchors",
            "",
            "Memories whose every `path_patterns` entry resolves to no file. Triage in `.ciel/memory/review-queue.md`.",
            "",
        ]
        for mid in shown:
            m = memories[mid]
            patterns = ", ".join(m.get('path_patterns') or [])
            lines.append(f"- `{mid}` - {m.get('title', '?')} (patterns: {patterns})")
        if omitted:
            lines.append(f"- _+{omitted} more, see insights.json_")
        lines.append("")

    if intent_clusters:
        ranked = sorted(intent_clusters.items(), key=lambda x: -len(x[1]))
        shown, omitted = maybe_cap(ranked)
        lines += [
            "## Intent clusters",
            "",
            f"Intents shared by >= {MIN_SUPPORT} memories - recurring topics.",
            "",
        ]
        for intent, ids in shown:
            lines.append(f"- `{intent}` ({len(ids)}): {', '.join(ids)}")
        if omitted:
            lines.append(f"- _+{omitted} more, see insights.json_")
        lines.append("")

    if path_clusters:
        ranked = sorted(path_clusters.items(), key=lambda x: -len(x[1]))
        shown, omitted = maybe_cap(ranked)
        lines += [
            "## Path clusters",
            "",
            f"Paths referenced by >= {MIN_SUPPORT} memories - high-traffic surface.",
            "",
        ]
        for path, ids in shown:
            lines.append(f"- `{path}` ({len(ids)}): {', '.join(ids)}")
        if omitted:
            lines.append(f"- _+{omitted} more, see insights.json_")
        lines.append("")

    insights_md = base / 'INSIGHTS.md'
    insights_md.write_text('\n'.join(lines), encoding='utf-8')

    # Write review-queue.md when dead anchors exist so the memoire-consolidator
    # skill has a concrete file to reference. Timestamped so re-runs don't wipe
    # manual triage notes.
    if dead_anchors:
        rq = base / 'review-queue.md'
        rq_lines = [
            f"# Dead Anchor Review Queue",
            f"",
            f"_Generated {insights['generated_at']} by `memory-engine.py analyze`._",
            f"",
            f"Memories whose every `path_patterns` entry resolves to no file on disk.",
            f"Triage each entry: **promote** (update patterns), **demote** (set stale), or **delete**.",
            f"",
        ]
        for mid in dead_anchors:
            m = memories[mid]
            patterns = ", ".join(m.get('path_patterns') or [])
            rq_lines.append(f"- [ ] `{mid}` — {m.get('title', '?')} (patterns: {patterns})")
        rq.write_text('\n'.join(rq_lines) + '\n', encoding='utf-8')

    print(f"Insights written: {insights_json.relative_to(cwd)}, {insights_md.relative_to(cwd)}")
    print(f"  promotion_candidates: {len(promotion_candidates)}")
    print(f"  dead_anchors: {len(dead_anchors)}")
    print(f"  intent_clusters: {len(intent_clusters)}")
    print(f"  path_clusters: {len(path_clusters)}")


# ─── CLI ────────────────────────────────────────────────────────────────────


def main():
    p = argparse.ArgumentParser(description='Ciel cued-recall memory engine')
    sub = p.add_subparsers(dest='cmd', required=True)

    qp = sub.add_parser('query', help='Match memories against prompt cues; update triggers')
    qp.add_argument('--prompt', default='')
    qp.add_argument('--cwd', default=None)
    qp.add_argument('--depth', default='standard', choices=['trivial', 'standard', 'critical', 'Trivial', 'Standard', 'Critical'])
    qp.set_defaults(func=cmd_query)

    ip = sub.add_parser('init', help='Initialize empty .ciel/memory/ structure')
    ip.add_argument('--cwd', default=None)
    ip.set_defaults(func=cmd_init)

    rp = sub.add_parser('rebuild-index', help='Scan *.md frontmatter, regenerate index.json')
    rp.add_argument('--cwd', default=None)
    rp.set_defaults(func=cmd_rebuild_index)

    np = sub.add_parser('new-id', help='Emit a collision-free memory id')
    np.set_defaults(func=cmd_new_id)

    cp = sub.add_parser('capture', help='Create episode file and rebuild index in one call')
    cp.add_argument('--title', required=True, help='Memory title')
    cp.add_argument('--source', default=None, help='Source of the capture (e.g. hook name, PR URL)')
    cp.add_argument('--intents', default=None, help='Comma-separated intent tags')
    cp.add_argument('--path-patterns', default=None, help='Comma-separated glob patterns')
    cp.add_argument('--symbols', default=None, help='Comma-separated symbol names')
    cp.add_argument('--languages', default=None, help='Comma-separated language tags')
    cp.add_argument('--content', default=None, help='Memory body text (defaults to title)')
    cp.add_argument('--captured-from', default='runtime', help='Capture source (user-intervention, agent-observed, etc.)')
    cp.add_argument('--type', default='episode', choices=['episode', 'concept', 'guard'], help='Memory type')
    cp.add_argument('--cwd', default=None)
    cp.set_defaults(func=cmd_capture)

    ap = sub.add_parser('analyze', help='Mine patterns + emit insights.json + INSIGHTS.md (read by ciel-audit Dim 10)')
    ap.add_argument('--cwd', default=None)
    ap.set_defaults(func=cmd_analyze)

    args = p.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()
