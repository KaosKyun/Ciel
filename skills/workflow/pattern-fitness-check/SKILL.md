---
name: pattern-fitness-check
description: For every existing code pattern being considered for reuse, applies a 3-question fitness check (same problem? same constraints? same volume?) before copying. Flags HUBs (high fan-in files), duplication candidates, and prior AI-generated patterns that contradict official docs. Invoked during the CODEBASE step of every Ciel task.
allowed-tools: Read, Grep, Glob, Bash
context: fork
agent: Explore
---

# pattern-fitness-check — Don't copy patterns blindly

Part of CRÉER step 5 (CODEBASE). Pattern-matching without fitness checking is the single most common LLM coding failure (per Ciel's Guards table).

---

## 3-question fitness check

For EACH pattern considered for reuse, answer all 3:

1. **Same problem?** — What problem did this pattern solve originally? (git blame the commit)
   - If the pattern was written for use case A and you're facing use case B → NOT the same problem.

2. **Same constraints?** — Volume, transport, sync/async, batch/single, cardinality
   - Pagination pattern written for 1k items might fail at 100M items.
   - Sync validation pattern might not fit async flow.
   - REST pagination pattern doesn't fit WebSocket message stream.

3. **Same data shape?** — Is the input/output structure identical?
   - Different field names → adapter needed
   - Different nullable fields → null-safety differs
   - Different ordering guarantees → might break downstream

→ **All yes** → APPLY. **Any no** → ADAPT or DO NOT USE.

---

## Additional checks

### Prior AI-generated patterns

Treat existing code written during a prior AI session as a **suggestion, not law**. If it contradicts current official docs → likely an inherited anti-pattern. Flag and do not follow.

Signal: code with unusual structure, comments like `// AI-suggested` or `// TODO: verify this approach`.

### Duplication check

If 2+ copies of the pattern you're about to write ALREADY EXIST → extract a shared helper FIRST, then use it.

```bash
# Find similar patterns
grep -rn "fun <functionName>" --include='*.kt' src/
```

### Mini repo-map (3 greps)

For impacted files, build a minimal map:

1. **Signatures** — `grep -n "^fun \|^class \|^interface \|^object " <file>`
2. **Dependents** — `grep -rln "import .*<filename>" src/`
3. **Hub check** — if step 2 returns 5+ files → **HUB WARNING**: changes ripple widely, proceed with caution

---

## Output format

```
## PATTERN FITNESS

### Patterns considered
- APPLY: <pattern at file:line> — same problem ✓ same constraints ✓ same shape ✓
- ADAPT: <pattern at file:line> — <what differs> → <how to adapt>
- DO NOT USE: <pattern at file:line> — <reason>

### Mini repo-map
- Impacted files: <list>
- Key signatures: <func/class at file:line>
- Dependents (1 hop): <list>
- Hub check: <NO — safe | YES — N files, changes ripple>

### Duplication check
- [None / Found N copies at file:line — extract helper first]

### Prior AI patterns
- [None / Flagged: <file:line> contradicts <doc URL> — do not follow]
```

---

## Guardrails

- **Git blame mandatory** for "same problem?" — don't rely on current code reading. Read the commit message where the pattern was introduced.
- **Numeric constraints**: quantify "volume" — "1k items" vs "1M items" matters. Don't say "big" or "small".
- **HUB threshold**: 5+ importers is the default; adjust per project size. A core util imported by 50+ files is extremely high-ripple — needs cross-team coordination.
- **Don't over-adapt**: if adaptation grows to > 50 lines different from the original, just write new code. Adapting is not saving effort.

---

## When triggered

- Standard/Critical tasks, during CODEBASE step
- Trivial tasks, if the fix is "use an existing pattern" (quickly — 1 pattern, 1 fitness check)
- When user says "we already have code for this" or "reuse X"
- When `explorer` agent identifies a candidate pattern
