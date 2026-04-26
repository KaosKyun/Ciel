---
name: memoire
description: How to persist project knowledge in Ciel v5 (etape 15). After PROUVER but before META, save .ciel/map.json (project map), .ciel/learnings.md (lessons), and .ciel/memory.json (state). Prevents knowledge loss across sessions.
---

# Persist Project Knowledge — Map, Memory, Learnings (Ciel v5)

## What this covers

How to save project knowledge at the end of a Ciel v5 pipeline (etape 15: MEMOIRE). After PROUVER but before META. Ensures the next session starts with the knowledge from this session.

## Core principle

**If you learned something, save it.** The next session starts fresh. Without persistence, every session rediscovers the same things.

## Three persistence targets

### 1. Project map (.ciel/map.json)

Structure:
```json
{
  "modules": [
    {
      "name": "module-name",
      "path": "src/module/",
      "purpose": "what this module does",
      "key_files": [
        { "path": "src/module/main.ts", "responsibility": "entry point" }
      ],
      "decision_log": [
        { "date": "2026-04-26", "adr": "ADR-003: Why JWT" }
      ]
    }
  ],
  "lastUpdated": "2026-04-26T..."
}
```

Update when:
- A new module was discovered or created
- A key file was identified
- An ADR was written

### 2. Learnings (.ciel/learnings.md)

Structure:
```markdown
# Ciel Learnings

## Project patterns
- [date] Pattern: <description>

## Failure modes
- [date] MISTAKE: <what happened> -> RULE: <how to avoid>

## Architecture decisions
- [date] Decision: <what> -> <why>

## Build/debug commands
- [date] Command: <command> -> <purpose>
```

Update when:
- User corrected something -> add MISTAKE/RULE
- New build command discovered
- New architecture decision made

### 3. Session state (.ciel/memory.json)

Structure (auto-persisted by plugin):
```json
{
  "sessionId": "abc12345",
  "depthHint": "...",
  "filesChanged": ["..."],
  "taskCount": 5,
  "timestamp": "..."
}
```

Auto-persisted during session.compacting.

## Common rationalizations

| Rationalization | Reality |
|---|---|
| "I'll remember this next session" | You won't. Every session starts with a fresh context window. If you don't persist it, it's gone. |
| "The learnings file is already long enough" | Persist briefly. A 2-line note is better than no note. Don't let perfect be the enemy of done. |
| "I'll update the map when I have time" | Time never appears. Update the map during MEMOIRE (etape 15) or it doesn't happen. |
| "Git history already captures this" | Git captures WHAT changed. Not WHY. Not WHICH APPROACH FAILED. Failed approaches are the most valuable thing to persist. |

## What to persist vs what to skip

PERSIST:
- Build commands
- Debugging insights
- User corrections (MISTAKE -> RULE)
- Architecture decisions
- Module locations and responsibilities
- Failed approaches + why

SKIP:
- Code itself (it's in git)
- Tests (they're in git)
- Temporary state (it's transient)
- Personal preferences (keep in overlay)

## How to verify

- [ ] .ciel/map.json updated with new modules/files?
- [ ] .ciel/learnings.md updated with new patterns/lessons?
- [ ] No duplicate entries (check before adding)?
- [ ] Format consistent with existing entries?
- [ ] .ciel/memory.json auto-persisted by plugin?
