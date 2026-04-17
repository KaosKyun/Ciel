---
name: skills-first-design-auditor
description: Lints and audits Agent Skills (Anthropic format) for design quality — frontmatter completeness, body length ≤500 lines, presence of 2-3 concrete examples, verification scripts for critical checks, clear WHEN-triggered section, and alignment with the 6 principles from Anthropic's April 2026 skills guide. Used by @ciel-improver when creating or reviewing a skill.
allowed-tools: Read, Grep, Glob, Bash
context: fork
agent: improver
---

# skills-first-design-auditor — Good skills discover themselves

A skill that doesn't auto-activate is just a document. Anthropic's April 2026 guide ("Equipping Agents for the Real World with Agent Skills") codifies what makes a skill actually useful to an agent. This skill audits against those principles.

---

## Inputs

```
SKILL_PATH: [absolute path to a SKILL.md file OR a directory containing SKILL.md + companions]
```

---

## The 6 principles (Anthropic April 2026)

### 1. Evaluation-driven design

The skill must encode a capability the agent ACTUALLY lacks. Don't add skills that duplicate what the base model does well.

**Audit**: is there evidence (a failing eval, a user complaint, a prior incident) that motivated this skill? → Check git history / CHANGELOG entry.

### 2. Searchable frontmatter

`description` must be specific enough that agents invoke it via semantic search. "Helps with code" is USELESS; "Validates that each proposed external API call exists in the pinned version's official documentation" is GOOD.

**Audit**:
- `name`: kebab-case, < 40 chars
- `description`: 1-3 sentences, names the trigger condition AND the output
- `allowed-tools`: present, minimal (`Read, Grep` not `*`)
- Agent field if applicable (`agent: critic` / `agent: researcher` / ...)

### 3. Body ≤ 500 lines

Skills are loaded into agent context. A 2000-line skill burns 5k tokens just to be available. If the body exceeds 500 lines:

- Split into a core SKILL.md + reference docs in the same folder
- Link from SKILL.md to the references; agent fetches them on demand

**Audit**: `wc -l SKILL.md`. Frontmatter doesn't count. 500-700 lines = WARN. >700 = BLOCK.

### 4. Concrete examples, not abstract prose

Each skill body must contain 2-3 examples showing input → reasoning → output. Not "the skill handles X" — an actual trace.

**Audit**: grep for `### Example` or `#### Example` or ```` ```<lang> `` code blocks with realistic values. 0 examples = BLOCK. 1 example = WARN. 2+ = PASS.

### 5. Verification scripts for critical checks

If the skill includes a "is this condition met?" check, that check should be executable (bash, python, grep), not a prose instruction telling the agent to "verify visually". Executable checks are reliable; prose checks degrade.

**Audit**: does the PROCESS section contain at least one runnable command per check? If all checks are prose ("verify the input is valid") → WARN.

### 6. Clear WHEN-triggered section

The skill must state explicitly when it activates: which step of the pipeline, which agent dispatches it, which user command. Without this, auto-activation via description-matching misfires.

**Audit**: presence of a `## When triggered` section (or equivalent) with at least 2 concrete triggers.

---

## Ciel-specific additions

### A. Consistency with existing skills

- Same section order as peer skills in the same category (workflow/ research/ domain/ utility/ meta)
- Same frontmatter field ordering (`name`, `description`, `allowed-tools`, `context`, `agent`)
- Output format uses `##` + `###` hierarchy consistent with `relire-critic` style

### B. No duplication

Before approving a new skill, grep the existing 36 skills for overlap. If the new skill covers ≥70% of an existing skill's scope → reject or merge.

### C. Dispatch target aligned

`agent: <role>` must match where the skill logically fits:
- **researcher** — external investigation, doc fetching, source validation
- **explorer** — codebase reading, pattern detection, domain knowledge
- **critic** — post-write review, hostile analysis, correctness checking
- **improver** — meta-level, auditing other skills or the system itself

Wrong `agent:` = skill won't be dispatched via the right fork context.

---

## Audit output format

```
## SKILL AUDIT: <name>

### Frontmatter
[✓] name: kebab-case, 22 chars
[✓] description: specific, names trigger + output
[✓] allowed-tools: minimal (Read, Grep, Glob, Bash)
[✓] agent: explorer (aligned with body content)

### Body
[✓] Length: 342 lines (under 500)
[✓] Examples: 3 (passes minimum 2)
[✓] Executable checks: 4 (grep commands, wc -l, etc.)
[✓] "When triggered" section: present, 4 triggers listed

### Principles
[✓] 1. Evaluation-driven — CHANGELOG v2.1.0 references ISSTA 2025 gap
[✓] 2. Searchable frontmatter
[✓] 3. Body ≤500 lines
[✓] 4. Concrete examples
[✓] 5. Verification scripts
[✓] 6. WHEN-triggered clarity

### Ciel-specific
[✓] Consistent section order with peer skills in workflow/
[✓] No overlap with existing skills (checked: pattern-fitness-check, flux-narrator)
[✓] agent field matches skill content (explorer for codebase-reading)

### Findings
(none — skill passes audit)

### Verdict
PASS — ready to ship
```

---

## Typical issues found (with fixes)

### Issue: vague description
```yaml
# BAD
description: Helps with code review.
# GOOD
description: Generates 3 hostile critiques per changed file (1 functional, 1 import, 1 data-assumption) and resolves each with FIX/ACCEPT/DEFER. Invoked by the PostToolUse hook on Write/Edit for Standard/Critical tasks with 3+ changed files.
```

### Issue: no examples
Add at least 2 concrete `### Example` blocks showing input → skill output. Prose-only skills don't transfer knowledge well; examples anchor behavior.

### Issue: missing WHEN section
Add section listing: (a) pipeline step, (b) dispatching agent, (c) user command triggers. 4-6 bullets is plenty.

### Issue: overbroad allowed-tools
```yaml
# BAD
allowed-tools: "*"
# GOOD
allowed-tools: Read, Grep, Glob, Bash
```

---

## Guardrails

- **Don't auto-fix, just audit** — propose changes in the report; let the human/improver decide.
- **Don't re-audit on every commit** — this is a "when a skill is added or significantly edited" task.
- **Prior-session skills** count under principle 1 — if the skill came from a past Ciel iteration and was never re-validated, flag for re-evaluation.
- **Skills in `skills/meta/`** should be extra strict — they shape how the system grows.
- **Exceptions allowed** — a meta skill legitimately exceeds 500 lines if it encodes a taxonomy; document the rationale in a comment at the top of the file.

---

## When triggered

- `@ciel-improver` on `/ciel-create-skill`
- PR touching `skills/**/SKILL.md`
- Before merging a skill from a research branch
- Quarterly sweep across all skills (release gate)

---

## References

- Anthropic April 2026 — "Equipping Agents for the Real World with Agent Skills" — anthropic.com/engineering
- Anthropic Skills intro — anthropic.skilljar.com/introduction-to-agent-skills
- Claude API docs — platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
