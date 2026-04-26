# Référence des skills

> **Inventaire complet des ~50 skills Ciel — nom, description, contexte d'invocation.**

---

## Groupe : Orchestrateur (1)

| Skill | Description | Contexte |
|-------|-------------|----------|
| `ciel` | Orchestrateur principal : classification depth + dispatch + pipeline | inline |

---

## Groupe : Workflow (20)

### Classification et cadrage

| Skill | Description | Contexte |
|-------|-------------|----------|
| `depth-classifier` | Classifie la tâche (Trivial/Standard/Critical) par signaux mécaniques | inline |
| `quoi-framer` | Cadre l'objectif (goal + NOT-X + Definition of Done) | inline |
| `avec-quoi-versioner` | Lit les versions installées réelles (package.json, go.mod, etc.) | inline |
| `evaluer-sizer` | Sizing + pre-mortem + alternatives + counterfactual | inline |

### Recherche et exploration

| Skill | Description | Contexte |
|-------|-------------|----------|
| `pattern-fitness-check` | 3-question fitness avant réutilisation de pattern | fork (explorer) |
| `flux-narrator` | Data flow end-to-end avec BOUNDARIES/ASSUMPTIONS/BREAK POINTS | fork (explorer) |
| `doc-validator-official` | Vérifie les appels API contre la doc officielle | fork (researcher) |

### Sécurité

| Skill | Description | Contexte |
|-------|-------------|----------|
| `stride-analyzer` | Threat modeling : Spoofing/Tampering/Repudiation/Info Disco/DoS/Elevation | fork (critic) |
| `security-regression-check` | Attacker-eye review du diff | fork (critic) |

### Implémentation

| Skill | Description | Contexte |
|-------|-------------|----------|
| `faire-gatekeeper` | 5 quality gates (test-first, alternatives, idiomatic, quality, removal) | inline |
| `self-consistency-verifier` | Génère 3 solutions indépendantes, les compare | fork (critic) |
| `modern-patterns-checker` | Flags les patterns obsolètes (LLM training data stale patterns) | fork (explorer) |
| `ai-failure-modes-detector` | Détecte 6 failure modes de code généré par LLM | fork (explorer) |
| `test-strategy-vitest-playwright` | Planification de test pyramid (70/20/10) | fork (explorer) |

### Relecture

| Skill | Description | Contexte |
|-------|-------------|----------|
| `relire-critic` | 3 RISQUES hostiles (functional, imports, data) | fork (critic) |
| `critiquer-auditor` | 7-step audit complet (APPRENDRE → CAPITALISER) | fork (critic) |
| `playwright-visual-critic` | Review UI visuelle via Playwright MCP | fork (explorer) |

### Preuve et rétrospective

| Skill | Description | Contexte |
|-------|-------------|----------|
| `prouver-verifier` | AVANT/APRÈS evidence + CI gate + PR body | inline |
| `meta-critiquer` | 30s post-task reflection (7 questions) | inline |
| `debug-reasoning-rca` | Root-cause analysis : 3 hypothèses + fault type + verdict | fork (critic) |

---

## Groupe : Domain (11)

| Skill | Description | Domaine | Contexte |
|-------|-------------|---------|----------|
| `frontend-mastery` | React, Vue, Svelte, Solid — hooks, state, routing | Frontend | inline |
| `backend-mastery` | Ktor, Express, Django, Rails — routing, middleware, auth | Backend | inline |
| `database-mastery` | PostgreSQL, MySQL, Redis, MongoDB — migrations, indexes | Database | inline |
| `security-hardening` | OWASP, auth, crypto, secrets hygiene, STRIDE | Security | inline |
| `api-architecture` | REST, GraphQL, gRPC, WebSocket — versioning, pagination | API | inline |
| `observability` | Logs structurés, metrics RED/USE, traces OpenTelemetry | Observability | inline |
| `performance-engineering` | Profiling, N+1, hot-path, allocation budgets | Performance | inline |
| `refactoring-patterns` | Extract, strangler fig, branch by abstraction | Refactoring | inline |
| `test-writing` | Test patterns, mocking, assertions, coverage | Testing | inline |
| `accessibility-wcag-auditor` | WCAG 2.2 Level AA audit (axe-core + manual) | Accessibilité | fork (explorer) |
| `cicd-security-hardener` | SLSA L3, Sigstore, SBOM, dependency pinning | CI/CD | fork (explorer) |

---

## Groupe : Research (6)

| Skill | Description | Contexte |
|-------|-------------|----------|
| `research-web-sources` | Docs officielles + best practices + anti-patterns | fork (researcher) |
| `research-github-issues` | GitHub issues pour symptômes d'erreur | fork (researcher) |
| `research-forums` | Fallback : StackOverflow, Reddit, Hacker News | fork (researcher) |
| `validate-source-credibility` | Score de fiabilité des sources (Tier 1-5) | fork (researcher) |
| `synthesize-findings` | Merge de tous les résultats en rapport unique | inline |
| `fact-check-claims` | Vérification d'assertions avant engagement | fork (researcher) |

---

## Groupe : Utility (10)

| Skill | Description | Contexte |
|-------|-------------|----------|
| `commit-writer` | Message de commit conventionnel (feat/fix/chore/docs) | inline |
| `pr-body-generator` | Corps de PR : Summary + Test plan + Closes # | inline |
| `pr-opener` | `gh pr create` avec body + Closes # | inline |
| `pr-merger` | `gh pr merge --auto` avec branch protection | inline |
| `issue-creator` | `gh issue create` avec description structurée | inline |
| `issue-closer` | `gh issue close` avec preuve observable | inline |
| `branch-cleaner` | `git branch --merged` delete + prune remote | inline |
| `branch-setup` | `git checkout -b fix/<N>-<slug>` | inline |
| `staging-verifier` | Log streaming + health check staging | inline |
| `changelog-updater` | Keep-a-Changelog entry sur version bump | inline |

---

## Groupe : Meta (6)

| Skill | Description | Contexte |
|-------|-------------|----------|
| `ciel-improve` | Analyse sessions → proposer patch-set | fork (improver) |
| `skill-creator` | Générer squelette SKILL.md valide | fork (improver) |
| `skill-variant-evaluator` | Benchmark 2-3 variantes de skill | fork (improver) |
| `learnings-capture` | Extraire MISTAKE→RULE pairs dans overlay | inline |
| `skill-freshness-auditor` | URLs mortes, pins obsolètes, citations périmées | fork (improver) |
| `skills-first-design-auditor` | Audit qualité de design Skills-first | fork (improver) |

---

## Skills additionnels (via plugins/bibliothèque étendue)

| Skill | Description | Contexte |
|-------|-------------|----------|
| `branch-cleaner` | Nettoyage branches mergées | inline |
| `ci-watcher` | Stream CI + flaky vs real classification | inline |
| `cicd-pipeline-designer` | Génération pipeline CI/CD from scratch | inline |
| `release-publisher` | `git tag -s` + `gh release create` + Sigstore | inline |
| `pr-review-responder` | Répondre aux commentaires de review | inline |

---

## Voir aussi

- [Bibliothèque de skills (explication)](../explanation/skills.md)
- [Guide : Créer un skill](../guides/creating-skill.md)
- [Système d'agents](../explanation/agents.md)
