---
paths:
  - "SKILL.md"
  - "**/SKILL.md"
  - ".claude/skills/**"
---

## Dispatch
- Charge `research` AVANT toute recherche d'information externe (WebSearch, WebFetch, documentation).
- Charge `research` quand tu crées ou modifies un skill (les skills encodent des connaissances, la recherche vérifie leur exactitude).

## Règles dures (zero tolerance)
- **Jamais** citer une API ou option sans vérification dans la doc officielle correspondant à la version utilisée.
- **Jamais** adopter une solution d'une seule source. Minimum deux sources indépendantes pour l'information critique.
- **Jamais** ignorer les issues fermées GitHub — elles contiennent les solutions.

## Conventions du projet
- Hiérarchie des sources : doc officielle > code source > changelog > issues GitHub > StackOverflow > blogs > LLM.
- Vérification de version systématique avant d'appliquer une doc.
- Toute information critique documentée avec ses sources (URL + date de consultation).
