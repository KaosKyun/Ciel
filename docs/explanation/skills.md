# Bibliotheque de skills Ciel v5

> **63 competences organisees en 6 categories. Chaque skill est un workflow specialise avec etiquette d'anti-rationalization. Les workflow skills sont liees explicitement au pipeline v5.**

---

## Architecture Skills-first

Ciel suit le paradigme **Skills-first** d'Anthropic : un orchestrateur generique + une bibliotheque de skills specialises > de nombreux agents specialises.

Principes :
- Chaque skill a un job precis, pas de duplication
- Chargement a la demande (pas dans le contexte permanent)
- Anti-rationalization : chaque skill anticipe les excuses de l'agent
- Decouvrable : .opencode/skills/ (OpenCode) + .claude/skills/ (Claude Code)

---

## Categories

### Workflow (26 skills) -- Liees au pipeline v5

| Skill | Pipeline v5 | Description |
|-------|-------------|-------------|
| **quoi-framer** | Etape 2 QUOI | Goal, NOT-X, intentions, DoD |
| **ask-window** | Etapes 3 et 10 ASK | Question tool / plan mode |
| **avec-quoi-versioner** | Etape 4 AVEC QUOI | Verifier versions installees |
| **diverge** | Etape 5 DIVERGE | 2-3 approches radicales |
| **doc-validator-official** | Etape 6 RECHERCHE | Docs officielles |
| **self-consistency-verifier** | Etape 6 RECHERCHE | Verification triple-approche |
| **ai-failure-modes-detector** | Etape 6 RECHERCHE | Detection hallucinations |
| **research-web-sources** | Etape 6 RECHERCHE | WebFetch + best practices |
| **research-github-issues** | Etape 6 RECHERCHE | GitHub issues |
| **research-forums** | Etape 6 RECHERCHE | Fallback forums |
| **validate-source-credibility** | Etape 6 RECHERCHE | Score de fabilite |
| **synthesize-findings** | Etape 6 RECHERCHE | Rapport consolide |
| **stride-analyzer** | Etape 7 SECURITE | STRIDE + killer checklist |
| **security-regression-check** | Etape 7 SECURITE | Diff securite |
| **pattern-fitness-check** | Etape 8 CODEBASE | Fitness 3 questions |
| **flux-narrator** | Etape 8 CODEBASE | Data flow end-to-end |
| **modern-patterns-checker** | Etape 8 CODEBASE | Patterns 2026 |
| **depth-classifier** | Etape 2 QUOI | Classification profondeur |
| **evaluer-sizer** | Etape 9 EVALUER | Sizing + pre-mortem + divcompare |
| **faire-gatekeeper** | Etape 11 FAIRE | 6 quality gates |
| **adr-auto** | Etape 12 ADR | Documentation decisions |
| **relire-critic** | Etape 13 RELIRE | 3 RISQUES hostiles |
| **critiquer-auditor** | Etape 13 RELIRE | Full 7-step audit |
| **debug-reasoning-rca** | Etape 13 RELIRE | Root cause analysis |
| **prouver-verifier** | Etape 14 PROUVER | AVANT/APRES evidence |
| **memoire** | Etape 15 MEMOIRE | Persister map + memory |
| **meta-critiquer** | Etape 16 META | 10-item reflection |
| **spike-mode** | Mode SPIKE | Exploration gates assouplies |
| **test-strategy-vitest-playwright** | Etape 11 tests | Strategie test pyramid |
| **playwright-visual-critic** | Etape 13 UI | Visual review MCP |

### Domaine (11 skills)

backend-mastery, frontend-mastery, database-mastery, api-architecture, security-hardening, cicd-security-hardener, accessibility-wcag-auditor, observability, performance-engineering, refactoring-patterns, test-writing

### Recherche (6 skills)

research-web-sources, research-github-issues, research-forums, validate-source-credibility, synthesize-findings, fact-check-claims

### Utilitaire (8 skills)

commit-writer, pr-opener, pr-body-generator, pr-merger, pr-review-responder, issue-creator, issue-closer, changelog-updater, branch-setup, branch-cleaner

### Meta (6 skills)

ciel-improve, learnings-capture, skill-creator, skill-freshness-auditor, skill-variant-evaluator, skills-first-design-auditor

### Autres (6 skills)

ciel (orchestrateur), ci-watcher, cicd-pipeline-designer, release-publisher, pr-merger, pr-review-responder

---

## Anti-rationalization

Chaque skill workflow v5 inclut une table d'anti-rationalization qui anticipe les excuses de l'agent :

```markdown
## Common rationalizations

| Rationalization | Reality |
|---|---|
| "This is simple, I don't need to frame it" | Simple tasks benefit from 2-line frames. |
| "I'll add tests later" | Later never comes. Tests are proof. |
| "Diverging is a waste of time" | First approach is rarely the best. |
```

Les skills concernes : ask-window, diverge, evaluer-sizer, quoi-framer, adr-auto, memoire, spike-mode, faire-gatekeeper

---

## Chargement

Les skills sont chargees a la demande via :
- **OpenCode** : `skill` tool natif (liste dans le system prompt, contenu charge sur appel)
- **Claude Code** : `.claude/skills/` directory (claire decouvertes)

Les subagents Claude Code prechargent leurs skills pertinentes via le champ `skills` du frontmatter :
- researcher : research-web-sources, research-github-issues, fact-check-claims, synthesize-findings
- explorer : pattern-fitness-check, flux-narrator, modern-patterns-checker
- critic : relire-critic, critiquer-auditor, debug-reasoning-rca

---

## Decouvrabilite

```
skills/                  → Source (63 skills en dossiers)
.opencode/skills/        → Copie decouvrable par OpenCode
.claude/skills/          → Copie decouvrable par Claude Code
```

L'installateur (`scripts/install.sh`) copie les skills dans les bons dossiers.

---

## Voir aussi

- [Pipeline v5 en details](pipeline.md)
- [Systeme d'agents](agents.md)
- [Comment creer un skill](../guides/creating-skill.md)
- [Reference des skills](../reference/skills.md)
