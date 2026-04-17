---
name: self-consistency-verifier
description: When the stakes are high, generates 3 independent solutions to the same problem with different starting prompts, compares them at the AST/semantic level, and scores consistency. Divergent solutions indicate model uncertainty — re-prompt with added constraints or escalate to human review. Based on IdentityChain (2024) and Consistency-Aided Tested Code Generation (ACM 2025). Partner skill to ai-failure-modes-detector for confident-wrong detection.
allowed-tools: Read, Grep, Glob, Bash, Write
context: fork
agent: critic
---

# self-consistency-verifier — If three of you disagree, one of you is wrong

A confident LLM that generates three semantically identical solutions is probably right. A confident LLM that generates three divergent solutions is the dangerous case — it'll ship whichever came out first. Self-consistency is the cheapest high-signal uncertainty estimator available (IdentityChain openreview caW7LdAALh).

---

## Inputs

```
PROBLEM: [precise problem statement — what the code must do]
CONSTRAINTS: [hard constraints — types, performance, dependencies allowed]
EXISTING_SOLUTION: [the code currently proposed or written]
STAKES: [Critical | Standard | Trivial]  # gates depth of verification
```

STAKES=Trivial → this skill is skippable. Use only on Standard/Critical.

---

## Phase 1 — Generate 3 diverse solutions

Re-prompt the LLM (or the current agent) 3 times with DIVERSIFYING seeds. The goal is divergent initial approaches, not different variable names.

### Diversification strategies (pick 3 out of 5)

1. **Constraint-reorder** — restate the problem with constraints in a different order
2. **Language-shift** — ask for a 5-line pseudocode first, THEN translate to target language
3. **Test-first** — ask for the test cases, THEN the implementation
4. **Adversarial framing** — "what would break this naïve solution?" then write the robust version
5. **Reference implementation** — "find the canonical pattern for this in the standard library" then adapt

Record each solution as `solution_1.txt`, `solution_2.txt`, `solution_3.txt` in `/tmp/ciel-consistency-<id>/`.

---

## Phase 2 — Compare at 3 levels

### Level A — Syntactic (cheap)

Run the formatter and normalize whitespace. Compute textual diff.

- **Identical after format** → consistency HIGH, skip to Phase 4
- **Differ only in variable names** → consistency HIGH
- **Structural diff** → proceed to Level B

### Level B — AST-level (medium)

Parse each solution to AST (use `tsc --noEmit` with emit-AST flag, `ast.dump()` in Python, `go/ast` in Go). Compare:

1. **Function signatures** — same in/out types?
2. **Control flow shape** — same number of branches? same loop depth?
3. **Side-effect surface** — same set of external calls (DB, HTTP, fs)?
4. **Data shape flow** — what types move through the function?

Score: `consistency = matched_nodes / total_nodes`. ≥0.85 = HIGH, 0.60-0.85 = MEDIUM, <0.60 = LOW.

### Level C — Behavioral (expensive, Critical only)

Generate 10-20 property-based test cases using `fast-check` (TS) or `hypothesis` (Python). Run each solution against the same test cases.

- **All 3 pass all cases** → consistency HIGH (strong signal of correctness)
- **Divergent pass/fail patterns** → at least one solution is wrong; use majority vote + investigate outlier

---

## Phase 3 — Interpret divergence

When solutions diverge, the divergence itself is diagnostic:

| Divergence type | Interpretation | Action |
|---|---|---|
| One solution handles edge case X, others don't | Missing explicit constraint | Add constraint, re-generate |
| Solutions use different libraries | Library choice under-specified | Pin the lib, pick one, re-generate |
| Solutions use different algorithms with different complexity | Performance under-specified | Add perf constraint |
| Solutions have different error-handling | Error model under-specified | Specify what errors to surface |
| Two solutions agree, one is outlier | Majority-vote the two, investigate outlier for missed insight | Use the majority |
| All three disagree | Problem under-specified or too hard | Escalate to human |

---

## Phase 4 — Confidence score

Compute final score:

```
consistency_score = (
  0.3 * syntactic_agreement +
  0.3 * ast_agreement +
  0.4 * behavioral_agreement  // only if Critical; else skip and renormalize
)
```

Thresholds:
- **≥ 0.85** — HIGH confidence, keep EXISTING_SOLUTION (or switch to the one that covers most edges)
- **0.60-0.85** — MEDIUM, adopt the majority, add tests for the divergent cases
- **< 0.60** — LOW, re-prompt with added constraints OR escalate to human

---

## Output format

```
## SELF-CONSISTENCY VERDICT

### Problem
<1 sentence>

### Diversification strategies used
1. Constraint-reorder
2. Test-first
3. Adversarial framing

### Solutions generated
- solution_1: 42 lines, uses reduce + generator
- solution_2: 38 lines, uses for-loop + accumulator
- solution_3: 51 lines, uses recursion + memo

### Agreement by level
- Syntactic: 0.32 (significant textual divergence — expected, variables renamed)
- AST: 0.78  (control-flow shapes differ — recursion vs loop)
- Behavioral: 0.95 (all 3 pass 18/20 property tests; 2 fail same edge)

### Consistency score
MEDIUM (0.76)

### Divergence interpretation
Solutions differ on whether to memoize. All pass correctness; perf differs. Constraint was under-specified.

### Recommended action
Add perf constraint (max 100ms on N=10k input) → re-generate or pick solution_1 (fastest by benchmark).

### Edge cases surfaced by divergence
- Empty input: solution_3 returns null, others return empty array — specify intended behavior.
```

---

## Guardrails

- **Cost budget**: Critical = full 3-level, ≤15 min. Standard = syntactic + AST only, ≤5 min. Trivial = skip.
- **Don't re-generate with the same prompt** — identical prompts produce highly similar outputs; the check becomes trivial. Always diversify.
- **Don't majority-vote blindly** — an outlier that catches an edge case the other two missed is the RIGHT answer. Investigate before voting.
- **AST compare requires a parser** — if the target language lacks easy AST access, fall back to behavioral compare OR skip Level B.
- **Behavioral tests cost real time** — for hot-loop Critical code only.
- **Three is the magic number** — two is a tie, four is diminishing returns; stick with three.

---

## When triggered

- `@ciel-critic` dispatched with STAKES=Critical
- `@ciel-improver` on a new skill or meta-change
- Before merging AI-authored code to a Critical module (auth, payments, data migration)
- User command: "verify this is right"
- After `ai-failure-modes-detector` flags confident-wrong suspicion

---

## References

- IdentityChain — openreview.net/forum?id=caW7LdAALh — self-consistency for code LLMs
- ACM 2025 — "Consistency-Aided Tested Code Generation with LLM" (dl.acm.org/doi/pdf/10.1145/3728902)
- arxiv 2507.06920 — "Rethinking Verification for LLM Code Generation: From Generation to Testing"
