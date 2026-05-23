---
name: ask-window
description: How to use the ASK window in Ciel v5 — before coding, clarify ambiguities using the question tool (OpenCode) or plan mode (Claude Code). Covers etapes 3 (ASK) and 10 (ASK2) of the pipeline. Prevents coding on assumptions.
---

# ASK Window — Clarify Before You Code (Ciel v5)

## What this covers

How to use the ASK window in the Ciel v5 pipeline. Before coding, the agent must ask clarifying questions rather than assuming. This skill covers etapes 3 (ASK after QUOI) and 10 (ASK2 after EVALUER).

## Core principle

**Do not code on assumptions.** When requirements are ambiguous, parameters undefined, or choices implicit -> ask. Use the question tool (OpenCode) or plan mode (Claude Code).

## When to use the ASK window

### Etape 3: ASK (after QUOI, before AVEC QUOI)

Clarify before any research or coding:
- Requirements: "Is the email field required?"
- Ambiguities: "Session cookie or JWT?"
- Assumptions: "I assume the database is PostgreSQL, correct?"
- Missing info: "What is the expected throughput?"
- Scope boundaries: "Does this include the admin panel?"

### Etape 10: ASK2 (after EVALUER, before FAIRE)

Validate the plan before implementing:
- Approach validation: "I'm going with approach A because X. OK?"
- Trade-off validation: "Approach A is simpler but B is more flexible. OK with A?"
- Risk confirmation: "The main risk is X. Acceptable?"
- Effort check: "This will take ~2 hours. OK?"

## How to ask

### OpenCode: use the `question` tool

The `question` tool is a built-in OpenCode tool. Each question includes:
1. A header (category of question)
2. The question text
3. A list of options (at least 2)
4. A custom answer option

Example:
```
Tool: question
Parameters:
  header: "Database choice"
  question: "Which database should we use for the new feature?"
  options: ["PostgreSQL (existing)", "SQLite (simpler)", "MySQL (new)"]
```

### Claude Code: use plan mode

In Claude Code, switch to plan mode (Tab key), then:
1. List your assumptions explicitly
2. Ask questions one at a time
3. Wait for answers before proceeding
4. Update the plan based on responses

## Structure of a good question

```
QUESTION CATEGORY: <requirement | assumption | tradeoff | risk | scope>

Context: <1-2 sentences explaining why you're asking>

Question: <clear, specific question>

Options:
  A: <option>
  B: <option>
  C: <other> (if relevant)
```

## What NOT to ask

- Things you can discover yourself (read the code, check package.json)
- Trivial preferences that don't affect the design (naming, formatting)
- The same question twice (check your previous answers)
- Questions you already have the answer to (check .ciel/memory.json, overlay)

## Output format

After the ASK phase, include in the plan:

```
## Questions asked (ASK)

1. <question> -> <answer selected>
2. <question> -> <custom answer>
```

## Common rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just assume and fix it later" | Later is when it's in production and costs 10x to fix. Asking now costs 30 seconds. |
| "The user would have told me if it mattered" | Users don't know what they don't specify. Assumptions are silent bugs waiting to surface. |
| "I can figure it out from the code" | Code tells you WHAT, not WHY. If there are two valid approaches, code can't tell you which one the project prefers. |
| "Asking makes me look uncertain" | Coding on wrong assumptions makes you look incompetent. Asking is what senior engineers do. |

## How to verify

- [ ] All unclear requirements have been asked about?
- [ ] Assumptions have been validated (not silently filled)?
- [ ] Trade-offs have been offered to the user?
- [ ] Questions are specific, not vague ("what do you think?")
- [ ] Answers are captured in the plan?
