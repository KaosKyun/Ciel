---
description: Slash trigger for the `ciel-improve` skill. Use `/ciel-improve [scope]` to run a self-improvement pass on recent session transcripts. The skill holds the patch-set generation logic.
---

# /ciel-improve — Slash trigger

Invoke the `ciel-improve` skill via the Skill tool with the scope argument:

```
$ARGUMENTS
```

Scope defaults to `last-10-sessions` if `$ARGUMENTS` is empty. Other valid scopes: `last-N-sessions`, `since-date=YYYY-MM-DD`, `skill=<name>`, `project-only`.

---

**Note**: this command file is a thin wrapper. The patch-set generation, variant evaluation, and approval flow all live in `skills/meta/ciel-improve/SKILL.md`. Modify the skill, not this file, to change behavior.
