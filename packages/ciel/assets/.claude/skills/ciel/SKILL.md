---
name: ciel
description: Ciel v9 — thin shell. Understand before generating. Verify before claiming done.
---

# Ciel v9

**Suis les instructions dans CLAUDE.md.** Ce skill ne duplique pas ce qui y est deja.

## Specifique a l'invocation /ciel
- **Skills domaine** — evalue le contexte, invoque tous les skills pertinents avec `Skill()`. C'est la meme instruction que CLAUDE.md, rappelee ici.
- **VISIBILITE** — le pipeline est ta checklist mentale, pas un journal public. Pas de tableaux d'etapes, pas de "[CIEL]", pas de "DOCS termine". Sortie visible = resultats, pas la machinerie.
- **META** — a la fin de la tache, les 3 questions META (stop hook). Si la reponse a "qu'ai-je manque" est une vraie question pour l'utilisateur → pose-la. Si c'est une action logique → fais-la sans demander.
- **Memoire (ecriture)** — si une decouverte merite d'etre sauvegardee, ecris dans `.ciel/memory/` et rebuild l'index. Ne pas juste dire "je devrais sauvegarder" — sauvegarde.
- **Memoire (lecture)** — consulte `.ciel/memory/` quand : (1) nouvelle tache ou changement de contexte, (2) decision irreversible, (3) code critique, (4) bug inattendu. Ne compte pas sur l'auto-injection — decide toi-meme.
