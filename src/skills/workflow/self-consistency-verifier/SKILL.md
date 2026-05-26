---
name: self-consistency-verifier
description: How to verify AI-generated code by generating 3 independent solutions, comparing them at syntactic/AST/behavioral levels, and scoring consistency. Divergent solutions indicate model uncertainty — re-prompt with constraints or escalate. Based on IdentityChain (2024) and Consistency-Aided Tested Code Generation (ACM 2025).
allowed-tools: Read, Grep, Glob, Bash, Write
---

# Self-Consistency Verifier — If Three of You Disagree, One of You Is Wrong

## What this covers

How to verify AI-generated code by generating 3 diverse solutions and comparing them. A confident LLM that generates 3 semantically identical solutions is probably right. A confident LLM that generates 3 divergent solutions is the dangerous case — it'll ship whichever came out first. Self-consistency is the cheapest high-signal uncertainty estimator available.

## Core principle

**Divergence is diagnostic.** When solutions disagree, the disagreement itself tells you what constraint is missing. Don't just pick one — understand WHY they differ.

## Methodology

### Generate 3 diverse solutions

Re-prompt the LLM 3 times with diversifying seeds. The goal is divergent initial approaches, not different variable names.

**Diversification strategies** (pick 3 out of 5):
1. **Constraint-reorder** — restate the problem with constraints in a different order
2. **Language-shift** — ask for pseudocode first, THEN translate to target language
3. **Test-first** — ask for test cases first, THEN the implementation
4. **Adversarial framing** — "what would break this naïve solution?" then write the robust version
5. **Reference implementation** — "find the canonical pattern" then adapt

### Compare at 3 levels

**Level A — Syntactic (cheap)**
- Run formatter, normalize whitespace, compute textual diff
- Identical after format → consistency HIGH, skip to verdict
- Differ only in variable names → consistency HIGH
- Structural diff → proceed to Level B

**Level B — AST-level (medium)**
- Parse each solution to AST
- Compare: function signatures, control flow shape, side-effect surface, data shape flow
- Score: `consistency = matched_nodes / total_nodes`. ≥0.85 = HIGH, 0.60-0.85 = MEDIUM, <0.60 = LOW

**Level C — Behavioral (expensive, Critical only)**
- Generate 10-20 property-based test cases (`fast-check` / `hypothesis`)
- Run each solution against the same test cases
- All 3 pass all cases → consistency HIGH
- Divergent pass/fail patterns → at least one is wrong; use majority vote + investigate outlier

### Interpret divergence

| Divergence type | Interpretation | Action |
|---|---|---|
| One solution handles edge case X, others don't | Missing explicit constraint | Add constraint, re-generate |
| Solutions use different libraries | Library choice under-specified | Pin the lib, pick one |
| Solutions use different algorithms with different complexity | Performance under-specified | Add perf constraint |
| Solutions have different error-handling | Error model under-specified | Specify what errors to surface |
| Two agree, one is outlier | Majority-vote the two, investigate outlier for missed insight | Use the majority |
| All three disagree | Problem under-specified or too hard | Escalate to human |

## Key points

- **Cost budget**: Critical = full 3-level compare, ≤15 min. Standard = syntactic + AST only, ≤5 min. Trivial = skip entirely
- **Don't re-generate with the same prompt** — identical prompts produce highly similar outputs; the check becomes trivial. Always diversify
- **Don't majority-vote blindly** — an outlier that catches an edge case the other two missed is the RIGHT answer. Investigate before voting
- **AST compare requires a parser** — if the target language lacks easy AST access, fall back to behavioral compare or skip Level B
- **Three is the magic number** — two is a tie, four is diminishing returns

## Common anti-patterns

1. **Same-prompt re-generation**: identical prompts produce near-identical outputs, making the check trivial and useless
2. **Blind majority voting**: an outlier may be the only one that caught a real edge case — investigate before discarding
3. **Skipping divergence analysis**: the WHY of divergence is more valuable than the score itself
4. **Running behavioral tests on every task**: reserve for Critical code only; syntactic + AST is enough for Standard

## How to verify

- **Score threshold**: ≥0.85 = HIGH confidence, proceed. 0.60-0.85 = MEDIUM, adopt majority + add tests. <0.60 = LOW, re-prompt or escalate
- **Edge case surfacing**: divergence analysis should produce at least 1 concrete edge case to test
- **Constraint improvement**: after divergence, the problem statement should have more constraints than before

## References

- IdentityChain — openreview.net/forum?id=caW7LdAALh — self-consistency for code LLMs
- ACM 2025 — "Consistency-Aided Tested Code Generation with LLM" (dl.acm.org/doi/pdf/10.1145/3728902)
- arxiv 2507.06920 — "Rethinking Verification for LLM Code Generation: From Generation to Testing"
