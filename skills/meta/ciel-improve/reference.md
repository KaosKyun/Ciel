# ciel-improve — Reference

## Correction detection heuristics

Phrases that signal a user correction (case-insensitive):

- "no, use X instead" / "not X, use Y"
- "stop using X"
- "you're wrong about X"
- "that's not right, X is Y"
- "actually, X"
- "no, X"
- "incorrect" / "wrong"
- "don't do X"
- "never X"
- "always X"

Count occurrences per `<X, Y>` pair across transcripts. 2+ identical corrections → high-confidence repeated failure.

## Truncation detection

Heuristic: an agent dispatch with `Task` tool result < 200 tokens on a task classified as Standard or Critical. Also flag: empty `## FINDINGS` blocks, skill outputs containing `[TRUNCATED]` or suspiciously short sections.

## Scoring rubric (binary per criterion)

When `skill-variant-evaluator` scores a variant, each criterion is binary (1 or 0). Aggregate = sum / total criteria. Examples:

- `has_finding`: at least 1 specific finding with version or URL
- `has_anti_pattern`: at least 1 anti-pattern with source citation
- `has_philosophy`: framework philosophy statement present
- `has_version_stamp`: version number mentioned in any finding
- `has_uncertainties_flagged`: `## INCERTITUDES` section non-empty when assumptions were made
- `output_within_budget`: response ≤ configured token cap
- `triggered_correctly`: skill activated on positive prompts and did not activate on negative prompts

Tiebreak order:
1. Aggregate score
2. Token usage (lower wins)
3. Description specificity (more keywords wins)

## Patch format — exact spec

Each patch is a block matching this shape:

```
## Patch <N> — <path-from-repo-root>
Issue: <REPEATED|UNTRIGGERED|MISTRIGGERED|TRUNCATED|CORRECTED>: <summary>
Sessions affected: <N>
Baseline score: <float 0-1> | Candidate <letter> score: <float 0-1> (winner)

--- BEFORE (lines <start>-<end>)
<verbatim old block>
--- AFTER
<verbatim new block>

Rationale: <1-2 sentences>

Approve? [y/n/edit]
```

## When a patch is APPROVED

The user types `y` (or `yes`, `approve`). The patch is applied via Edit tool. The commit message is auto-generated:

```
meta(ciel): improve <skill-name> from session feedback

Issue: <type> — <summary>
Eval delta: <baseline> → <winner>
Sessions analyzed: N

Approved by user.
```

## When a patch is REJECTED

The user types `n` (or `no`, `reject`). The patch is logged to `evals/results/rejected-patches.jsonl` with the user's optional reason. This is used to improve future patch proposals.

## When a patch is EDITED

The user types `edit` or provides a modified AFTER block. The patch is applied with the user's version. Logged as `edited` in rejection log.

## Session transcript paths

Claude Code stores sessions at `~/.claude/projects/<slugified-project-path>/<session-id>.jsonl`.

To find the current project's transcripts:

```bash
PROJECT_SLUG=$(pwd | sed 's|/|-|g' | sed 's|^-||')
ls ~/.claude/projects/-"$PROJECT_SLUG"/*.jsonl
```

For transcript parsing, each line is a JSON object with `type` in `user`, `assistant`, `system`, `tool_use`, `tool_result`. The `message.content` field contains the text.
