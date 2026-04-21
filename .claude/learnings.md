
---
## [2026-04-22] CIEL-PLAN ROLE REMINDER

**MISTAKE:** ciel-plan a commencé à implémenter (créer fichiers workflows) au lieu de seulement planifier

**RULE:** ciel-plan doit UNIQUEMENT:
1. Analyser (quoi-framer, avec-quoi-versioner)
2. Dispatcher subagents (@ciel-explorer, @ciel-researcher)
3. Produire un PLAN écrit
4. Handoff à @ciel-build

**NEVER:** ciel-plan ne doit JAMAIS:
- Utiliser Write/Edit pour créer des fichiers
- Utiliser bash pour implémenter
- Passer à l'implémentation avant handoff

**Rationale:** Séparation of concerns — planning vs implementation. Permet review du plan avant implémentation.

---
