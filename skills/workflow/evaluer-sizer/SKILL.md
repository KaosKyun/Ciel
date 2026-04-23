---
name: evaluer-sizer
description: How to size and assess risk before coding — back-of-envelope sizing, pre-mortem (2 failure modes), recent-churn check, alternative-named gate, and counterfactual ("what if we do nothing?"). Prevents under-thinking scope and missing simpler solutions.
allowed-tools: Read, Bash
---

# Pre-Implementation Sizing — 4 Cheap Gates

## What this covers

How to sanity-check an approach before committing to it. These 4 gates take 2 minutes and prevent hours of wasted work.

## Core principle

**Quantify before coding.** "Small memory footprint" is not sizing. "~2 MB × 10k entries = 20 MB" is.

## Gate 1: Back-of-envelope sizing

Compute rough estimates:
- Memory: bytes per row × row count
- Connections: concurrent users × connections per user
- Throughput: req/s × processing time per req
- Storage: items × avg size × retention

Does the solution fit in the budget? If caching requires 10 GB and the server has 2 GB → wrong solution, don't start.

## Gate 2: Pre-mortem

State explicitly: "In production, this could fail in these 2 ways:"
1. <failure mode 1>
2. <failure mode 2>

Can't imagine 2 failure modes → don't understand the system well enough.

## Gate 3: Recent churn

```bash
git log --oneline --since="7 days" -- <impacted files>
```

If 2+ commits in the last week touched the same module:
- Read those commits BEFORE proposing your fix
- Someone already fixed this area twice this week → incomplete mental model
- Your "fix" might be the 3rd attempt at the same bug

## Gate 4: Alternative + counterfactual

**Alternative**: "I chose X over Y because [reason]." No Y named → think harder.

**Counterfactual**: "What if we do NOTHING?" If doing nothing solves 80% of the problem with 0 risk → reconsider scope.

## Output format

```
## ÉVALUER

### Sizing
- Memory: <estimate>
- Connections: <estimate>
- Throughput: <estimate>
- Fit: <yes — within budget | no — what breaks>

### Pre-mortem (2 ways this could fail)
1. <failure mode>
2. <failure mode>

### Recent churn
- Commits in last 7 days: <N>
- Relevant: <list>
- Read them? <yes — findings>

### Alternative
- Chose: <X> over <Y> because <reason>

### Counterfactual
- What if nothing? <consequence>
- 80% solve with 0 risk? <yes → reconsider | no → proceed>
```

## How to verify

- [ ] Sizing has concrete numbers (request rate, data volume, latency budget)?
- [ ] Pre-mortem identifies ≥ 2 specific failure modes?
- [ ] Recent churn checked (git log for affected files)?
- [ ] ≥ 1 alternative considered?
- [ ] Counterfactual stated ("what if we don't do this")?

## Common mistakes

- **Hand-waving sizing**: "small footprint" without numbers
- **Pre-mortem = tests**: "might have bugs" is useless. "Query times out at > 10k notifications" is useful.
- **Fake alternatives**: "React over Assembly" is not real. "Page vs cursor pagination because API is public" is real.
