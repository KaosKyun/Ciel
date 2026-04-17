---
name: evaluer-sizer
description: Back-of-envelope sizing + pre-mortem (2 failure modes) + recent-churn check + alternative-named gate + counterfactual ("what if we do nothing?"). Invoked before FAIRE on Standard and Critical tasks to prevent under-thinking scope and missing simpler solutions.
allowed-tools: Read, Bash
---

# evaluer-sizer — Sanity check before coding

Step 6 of CRÉER. Before committing to an approach, apply 4 cheap gates.

---

## 4 gates

### 1. Sizing (back-of-envelope)

Compute rough estimates:
- Memory: bytes per row × row count
- Connections: concurrent users × connections per user
- Throughput: req/s × processing time per req
- Storage: items × avg size × retention

Target: does the solution fit in the budget? If a caching scheme would require 10 GB of RAM and the server has 2 GB, the solution is wrong — don't start coding.

### 2. Pre-mortem

State explicitly: "In production, this could fail in these 2 ways:"
- Failure mode 1
- Failure mode 2

If you can't imagine 2 failure modes, you don't understand the system well enough. Go back to CODEBASE/FLUX.

### 3. Recent churn

```bash
git log --oneline --since="7 days" -- <impacted files>
```

If 2+ commits in the last week touched the same module:
- Read those commits BEFORE proposing your fix
- Someone already fixed this area twice this week → incomplete mental model somewhere
- Your "fix" might be the 3rd attempt at the same bug

### 4. Alternative + counterfactual

**Alternative**: "I chose X over Y because [reason]." If no Y named → think harder.

**Counterfactual**: "What if we do NOTHING?" If doing nothing solves 80% of the problem with 0 risk → reconsider scope.

---

## Output format

```
## ÉVALUER

### Sizing
- Memory: <estimate>
- Connections: <estimate>
- Throughput: <estimate>
- Fit: <yes — within budget | no — <what breaks>>

### Pre-mortem (2 ways this could fail in prod)
1. <failure mode>
2. <failure mode>

### Recent churn
- Commits in last 7 days on impacted files: <N>
- Relevant commits: <list with 1-line summary>
- Read them? <yes — findings: ...>

### Alternative
- Chose: <X>
- Over: <Y>
- Because: <reason>

### Counterfactual
- What if we do nothing? <consequence>
- Does 80% solve with 0 risk? <yes → reconsider | no → proceed>
```

---

## Guardrails

- **No hand-waving sizing**: give numbers, even rough. "Small memory footprint" is not a sizing. "~2 MB per cache entry × 10k entries = 20 MB" is.
- **Pre-mortem cannot be the same as tests**: "might have bugs" is useless. "Query times out if user has > 10k notifications" is useful.
- **Recent churn is informational, not blocking**: if 2+ commits exist, reading them is MANDATORY before proposing. Finding nothing new is fine; skipping the read is not.
- **Alternatives must be real**: "I chose React over Assembly" is not an alternative. "I chose page-based pagination over cursor-based because the API is public and page numbers are user-expected" is real.

---

## When triggered

- Standard/Critical tasks, after CODEBASE+FLUX and before FAIRE
- When scope feels "too easy" — the 80% counterfactual catches over-engineering
- When user proposes a large change — sizing forces quantification
