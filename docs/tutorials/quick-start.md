# Quick-start Ciel v5

> **Installez Ciel et faites votre premiere tache en 5 minutes.**

---

## 1. Installation

```bash
cd /path/to/your/project
curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh | bash
```

L'installateur auto-detecte OpenCode ou Claude Code et copie tous les fichiers necessaires.

## 2. Demarrage

**OpenCode :**
```bash
opencode
```

**Claude Code :**
```bash
claude
```

## 3. Premiere tache

Envoyez ce message :

```
"J'ai besoin d'ajouter une validation d'email sur le formulaire d'inscription."
```

Ciel v5 va automatiquement :

1. **DOCS** : Lire les fichiers de configuration et la carte du projet
2. **QUOI** : Cadrer l'objectif (goal, NOT-X, intentions, DoD)
3. **ASK** : Vous demander des clarifications (via question tool / plan mode)
4. **AVEC QUOI** : Verifier les versions installees
5. **DIVERGE** : Proposer 2-3 approches
6. **RECHERCHE** : Si necessaire, chercher la doc
7. **CODEBASE** : Explorer les patterns existants
8. **EVALUER** : Sizing + pre-mortem
9. **ASK2** : Valider le plan avec vous
10. **FAIRE** : Implementer avec test-first et quality gates
11. **ADR** : Si decision significative, la documenter
12. **RELIRE** : Faire relire le code par un agent forke
13. **PROUVER** : Montrer les preuves
14. **MEMOIRE** : Sauvegarder la connaissance
15. **META** : Reflechir a la tache

## 4. Next steps

- Explorez le [pipeline 16 etapes](../explanation/pipeline.md)
- Decouvrez les [63 skills](../explanation/skills.md)
- Consultez la [reference des agents](../reference/agents.md)

---

## Voir aussi

- [Premiere tache guidee](first-task.md)
- [Guide d'installation](../guides/install.md)
