---
name: evaluer-sizer
description: How to size and assess risk before coding — back-of-envelope sizing, pre-mortem (2 failure modes), recent-churn check, alternatives comparison, and counterfactual ("what if we do nothing?"). Use before committing to an approach.
---

# Pre-Implementation Sizing — 5 Cheap Gates (Ciel)

## What this covers

How to sanity-check the selected approach before committing to it. These 5 gates take 2 minutes and prevent hours of wasted work.

## Core principle

**Quantify before coding.** "Small memory footprint" is not sizing. "~2 MB × 10k entries = 20 MB" is.

## Gate 1: Back-of-envelope sizing

Compute rough estimates:
- Memory: bytes per row × row count
- Connections: concurrent users × connections per user
- Throughput: req/s × processing time per req
- Storage: items × avg size × retention

Does the solution fit in the budget? If caching requires 10 GB and the server has 2 GB -> wrong solution, don't start.

## Gate 2: Pre-mortem

State explicitly: "In production, this could fail in these 2 ways:"
1. <failure mode 1>
2. <failure mode 2>

Can't imagine 2 failure modes -> don't understand the system well enough.

## Gate 3: Recent churn

```bash
git log --oneline --since="7 days" -- <impacted files>
```

If 2+ commits in the last week touched the same module:
- Read those commits BEFORE proposing your fix
- Someone already fixed this area twice this week -> incomplete mental model
- Your "fix" might be the 3rd attempt at the same bug

## Gate 4: Diverged approach comparison (v5)

Compare the approaches explored earlier:
- Approach A (from DIVERGE): <summary>
- Approach B (from DIVERGE): <summary>
- Selected: <A or B> because <reason>
- Why NOT the other: <specific limitation, not "it's worse">

If only 1 approach was explored -> DIVERGE was incomplete.

## Gate 5: Counterfactual

**Counterfactual**: "What if we do NOTHING?" If doing nothing solves 80% of the problem with 0 risk -> reconsider scope.

## Output format

```
## EVALUER

### Sizing
- Memory: <estimate>
- Connections: <estimate>
- Throughput: <estimate>
- Fit: <yes -- within budget | no -- what breaks>

### Pre-mortem (2 ways this could fail)
1. <failure mode>
2. <failure mode>

### Recent churn
- Commits in last 7 days: <N>
- Relevant: <list>
- Read them? <yes -- findings>

### Diverged approach comparison (v5)
- A: <summary>
- B: <summary>
- Selected: <A/B> because <reason>

### Counterfactual
- What if nothing? <consequence>
- 80% solve with 0 risk? <yes -> reconsider | no -> proceed>
```

## How to verify

- [ ] Sizing has concrete numbers (request rate, data volume, latency budget)?
- [ ] Pre-mortem identifies >= 2 specific failure modes?
- [ ] Recent churn checked (git log for affected files)?
- [ ] >= 2 approaches compared from DIVERGE?
- [ ] Counterfactual stated ("what if we don't do this")?
- [ ] Selected approach justified with specific reason?

## Common rationalizations

| Rationalization | Reality |
|---|---|
| "I'll size it as I go" | Sizing after coding is guessing. Sizing before prevents committing to the wrong approach. |
| "I can't estimate without coding" | Back-of-envelope takes 2 minutes. 2 minutes of thinking saves 2 hours of coding the wrong thing. |
| "Pre-mortem is pessimistic" | Pre-mortem is the cheapest bug fix you'll ever write. Imagining failure costs nothing. Production failure costs everything. |
| "Diverging is a waste of time, the first approach is fine" | The first approach is rarely the best. It's just the first. Generating 2-3 approaches takes 5 minutes. Committing to the wrong one takes days. |

## Common mistakes

- **Hand-waving sizing**: "small footprint" without numbers
- **Pre-mortem = tests**: "might have bugs" is useless. "Query times out at > 10k notifications" is useful.
- **Fake alternatives**: "React over Assembly" is not real. "Page vs cursor pagination because API is public" is real.
- **Single-approach bias (v5)**: if DIVERGE was skipped, EVALUER cannot compare alternatives. Go back to DIVERGE.
