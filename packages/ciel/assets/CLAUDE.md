# CLAUDE.md — Ciel v8

**Core principle:** *"Understand before generating. Verify before claiming done."*

---

## Regles dures (violation = CRITICAL)

1. **Ne jamais inventer** — verifier API, package, version avant usage. Pas de citation = tu ne sais pas.
2. **Test d'abord** — RED (test echoue) → GREEN (passe) → REFACTOR. Jamais de code sans test.
3. **Zero secret** — pas de cle, token, ou mot de passe dans le code. Variables d'environnement uniquement.
4. **Pas de placeholder** — pas de `// TODO`, pas de `// ...rest of code`. Tout code est complet ou absent.
5. **Pipeline complet** — 17 etapes dans l'ordre. Ne saute jamais TESTER, RELIRE, ni PROUVER.
6. **Pipeline invisible** — jamais de tableaux d'etapes, de "DOCS termine", de "Passons a QUOI", ni de comptes-rendus META dans la sortie visible. L'utilisateur voit les resultats, jamais la machinerie.
7. **Skills obligatoires** — a chaque etape du pipeline, charger le skill workflow correspondant avec l'outil `Skill` (colonne "Skill a charger" dans le tableau). Ne jamais sauter un skill: son contenu n'est pas dans ta memoire d'entrainement, il est dans le fichier SKILL.md.

---

## Pipeline (17 etapes — a tracker en interne, jamais affiche)

Chaque etape a un skill workflow dedie a charger via `Skill` avant de l'executer.

| Step | Depth | Skill a charger | Action |
|------|-------|-----------------|--------|
| **DOCS** | All | `depth-classifier` | Lire AGENTS.md, CLAUDE.md, ciel-overlay.md, .ciel/map.json. Classifier la profondeur et ecrire le resultat (Trivial/Standard/Critical) dans `.ciel/last-depth`. Charger les skills domaine pertinents via `Skill`. |
| **QUOI** | All | `quoi-framer` | Objectif (1 phrase) + NOT-X + Definition of Done |
| **ASK** | Std/Crit | `ask-window` | `AskUserQuestion` si ambigu. Sinon DECIDE. |
| **AVEC QUOI** | Std/Crit | `avec-quoi-versioner` | Lire les versions installees (package.json) — pas la memoire |
| **DIVERGE** | Std/Crit | `diverge` | 2-3 approches differentes AVANT de choisir |
| **RECHERCHE** | Std/Crit | — | Dispatch `ciel-researcher` avec les skills domaine: docs officielles + anti-patterns + changelog |
| **SECURITE** | Critical | `stride-analyzer` | STRIDE 6 categories → `ciel-critic` MODE=CRITIQUER |
| **CODEBASE** | Std/Crit | — | Dispatch `ciel-explorer` avec les skills domaine: pattern fitness + data flow + git history |
| **EVALUER** | Std/Crit | `evaluer-sizer` | Sizing + 2 modes d'echec + contrefactuel |
| **ASK2** | Std/Crit | — | Valider le plan avec l'utilisateur avant de coder |
| **FAIRE** | All | `faire-gatekeeper` | 6 gates: test-first RED, alternatives, idiomatique, qualite, removal safety, boy-scout |
| **TESTER** | Std/Crit | — | Executer la suite de tests. RED? → FAIRE. GREEN? → continuer. Max 3 boucles. Commande: .ciel/map.json → package.json → Makefile |
| **ADR** | Decision | `adr-auto` | Si decision architecturale → `docs/adrs/` |
| **RELIRE** | Std/Crit | `relire-critic` | Dispatch `ciel-critic` MODE=RELIRE: 4 RISQUES + FIX/ACCEPT/DEFER |
| **PROUVER** | Std/Crit | `prouver-verifier` | Evidence AVANT/APRES + CI gate + issue comment gate |
| **MEMOIRE** | All | `memoire` | Capturer bugs decouverts, patterns appris, decisions utilisateur, anti-patterns detectes → `python3 .claude/hooks/memory-engine.py capture` |
| **META** | All | `meta-critiquer` | Reflection (10 items ci-dessous). Jamais dans la sortie visible. |

---

## Depth Gauge

| Level | Example | Pipeline |
|-------|---------|----------|
| **Trivial** | rename, typo, 1-liner | DOCS → QUOI → FAIRE → META |
| **Standard** | hook, route, component, service | 17 etapes completes |
| **Critical** | auth, DB schema, security, payment | 17 + STRIDE + `ciel-critic` obligatoire |
| **Spike** | POC, draft, experimental | QUOI → ASK → AVEC QUOI → DIVERGE → FAIRE (relaxe) → META |

Doute → Standard. Touche aux donnees utilisateur ou auth → Critical.

---

## Subagent Dispatch (Standard/Critical — avant tout Edit/Write)

Ne jamais faire d'Edit/Write sur du code source avant d'avoir dispatche `ciel-researcher` + `ciel-explorer` en parallele. Le hook `pre-tool-write.sh` bloque les ecritures sur `.ts/.tsx/.js/.py/.go/.rs` (etc.) tant que le dispatch n'a pas eu lieu.

Si la tache est Trivial (rename, typo), utiliser `[CIEL_GATE_BYPASS]` dans l'input du tool pour passer le gate.

| Agent | Quand | Dispatch |
|-------|-------|----------|
| `ciel-researcher` | RECHERCHE | `Agent` subagent_type=`ciel-researcher` |
| `ciel-explorer` | CODEBASE | `Agent` subagent_type=`ciel-explorer` (en parallele avec researcher) |
| `ciel-critic` | RELIRE (Std/Crit), SECURITE (Crit) | `Agent` subagent_type=`ciel-critic` |
| `ciel-improver` | UNIQUEMENT /ciel-improve, /ciel-eval | `Agent` subagent_type=`ciel-improver` |

Prompt chercheur: `"Research: [topic]. Apply domain skills: [skill1], [skill2]. Installed: [version]. Goal: [quoi]."`
Prompt explorateur: `"Explore: [intention]. Apply domain skills: [skill1], [skill2]. Goal: [quoi]. NOT-X: [constraints]."`
Prompt critique: `"MODE: RELIRE. CHANGED_FILES: [list]. QUOI_GOAL: [quoi]. Apply domain skills: [skill1], [skill2]."`

---

## Top 10 Guards

1. **"I already know this" = red flag** → RESEARCH. Fais-le.
2. **Pas de citation = tu ne sais pas** → verifie avant d'affirmer.
3. **Colonnes DB** → verifier le vrai schema avant de query (fichier migration, pas memoire).
4. **Pattern copie aveuglement** → fitness check echoue. Verifie avant de copier.
5. **Auto-critique dans le meme contexte** = memes angles morts → dispatch `ciel-critic`.
6. **Aucune alternative consideree** → retour a EVALUER. Trouve 2-3 approches.
7. **Scope drift a 3+ fichiers** → relire QUOI. Recentre-toi.
8. **Test d'abord (RED)**, jamais apres. Toujours.
9. **"No error in logs" ≠ preuve** → declenche le scenario, vois un signal positif.
10. **Test suite doit passer** — execute la commande de test apres FAIRE. RED → corrige → re-run. Max 3 boucles puis escalade.

---

## Cued-recall memory

Ecrire dans `.ciel/memory/episodes/` via `memory-engine.py capture`. Ne jamais ecrire dans le Claude Code auto-memory (`MEMORY.md`). Confirmer avec `AskUserQuestion` avant chaque capture.

---

## META — 10 items de reflexion (interne, jamais visible)

A la fin de chaque tache, charger `meta-critiquer` et repondre a ces 10 questions DANS LE THINKING:

1. Depth match — la classification etait-elle correcte ? Sinon, quel indice a ete manque ?
2. Pipeline — etape sautee ou baclee ? Laquelle ?
3. Skill manquant — un skill domaine aurait-il du etre charge et ne l'a pas ete ?
4. Subagent — un dispatch a-t-il ete oublie ? (researcher/explorer en parallele)
5. RELIRE — le critique a-t-il trouve quelque chose que je n'avais pas vu ?
6. PROUVER — l'evidence est-elle concrete (log/curl/screenshot) ou juste "no error" ?
7. MEMOIRE — y a-t-il une intervention, decision, ou decouverte a capturer ?
8. Contrefactuel — qu'aurais-je fait differemment avec 2x plus de temps ?
9. Angle mort — qu'ai-je omis que l'utilisateur va probablement me demander ensuite ?
10. Lecon — 1 phrase a memoriser pour la prochaine tache similaire

---

## Echecs frequents

- **Pas de DOCS** → toujours lire `.ciel/map.json` + `ciel-overlay.md` en premier
- **Pas de QUOI** → definir objectif + NOT-X + DoD avant de toucher au code
- **Pas de DIVERGE** → generer 2-3 alternatives avant d'en choisir une
- **Pas de subagents** → dispatcher researcher + explorer en parallele avant tout Edit/Write
- **Pas de RELIRE** → toujours dispatcher `ciel-critic` MODE=RELIRE avant merge
- **Pas de PROUVER** → montrer evidence AVANT/APRES (logs, curl, screenshot)
- **Pas de MEMOIRE** → sauver `.ciel/map.json` et capturer a `.ciel/memory/` en fin de tache
- **Pas de META** → toujours executer la reflection (10 items)
- **Pipeline visible** → le pipeline est dans le thinking UNIQUEMENT
