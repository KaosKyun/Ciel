# Référence des commandes

> **Les 8 commandes slash Ciel — syntaxe, options, comportement.**

---

## `/ciel`

**Lance une tâche avec le pipeline complet Ciel.**

```
Usage: /ciel <description de la tâche>
```

Le texte de la tâche est analysé pour :
1. Classification de profondeur (Trivial/Standard/Critical)
2. Intent routing (debug → RCA, API → researcher, etc.)
3. Dispatch des subagents appropriés

**Exemples :**
```
/ciel ajoute un endpoint GET /api/status
/ciel pourquoi la CI est rouge ?
/ciel nettoie les branches mergées
```

---

## `/ciel-init`

**Répare ou initialise le câblage Ciel.**

```
Usage: /ciel-init [--check] [--user] [--platform=claude|opencode]
```

| Option | Effet |
|--------|-------|
| `--check` | Dry-run : affiche le diff sans écrire |
| `--user` | Édite la config utilisateur au lieu du projet |
| `--platform=claude` | Force la cible Claude Code |
| `--platform=opencode` | Force la cible OpenCode |

**Comportement :**
1. Détecte la plateforme (OpenCode ou Claude Code)
2. Résout `$CIEL_DIR` (emplacement des plugins)
3. Vérifie que les 8 hooks sont présents
4. Branche Claude : merge hooks dans `settings.json`
5. Branche OpenCode : copie plugin + agents + commands dans `.opencode/`
6. Merge `opencode.json` (préserve les clés existantes)

**Quand l'utiliser :**
- Première installation
- Hooks inactifs (pas de marqueurs `[CIEL]`)
- Après une mise à jour

---

## `/ciel-update`

**Vérifie et applique les mises à jour de Ciel.**

```
Usage: /ciel-update [--check]
```

| Option | Effet |
|--------|-------|
| `--check` | Vérifie la version sans installer |

Vérifie la version GitHub et propose une mise à jour si disponible.

---

## `/ciel-improve`

**Analyse les sessions récentes et propose des améliorations.**

```
Usage: /ciel-improve [--sessions=<N>]
```

| Option | Effet |
|--------|-------|
| `--sessions=10` | Analyse les 10 dernières sessions |

**Processus :**
1. Invoke `@ciel-improver` avec MODE=IMPROVE
2. Détecte les patterns d'échec récurrents
3. Propose des patch-sets pour approbation
4. Ne modifie jamais les skills sans approbation

---

## `/ciel-eval`

**Évalue un skill avec le benchmark harness.**

```
Usage: /ciel-eval [skill-name]
```

**Exemple :**
```
/ciel-eval depth-classifier
```

**Processus :**
1. Invoke `@ciel-improver` avec MODE=EVAL
2. Génère 2-3 variantes du skill
3. Exécute le dataset d'évaluation binaire
4. Retourne le scoreboard + recommendation

---

## `/ciel-create-skill`

**Génère un squelette de skill.**

```
Usage: /ciel-create-skill <nom-kebab-case> "<description>"
```

**Exemple :**
```
/ciel-create-skill email-validator "Valide les emails côté serveur"
```

**Processus :**
1. Invoke `@ciel-improver` avec MODE=CREATE-SKILL
2. Génère un squelette SKILL.md valide
3. Retourne le fichier pour approbation (n'écrit pas automatiquement)

---

## `/ciel-refresh`

**Vérifie la fraîcheur des skills (URLs, versions, citations).**

```
Usage: /ciel-refresh [--skill=<nom>]
```

| Option | Effet |
|--------|-------|
| `--skill=depth-classifier` | Vérifie un skill spécifique |
| (aucune) | Vérifie tous les skills |

**Vérifie :**
- URLs mortes
- Pins de version obsolètes
- Citations de recherche périmées
- Références à des APIs dépréciées

---

## `/ciel-recommend`

**Découvre des plugins communautaires compatibles.**

```
Usage: /ciel-recommend [--category=<cat>]
```

Analyse le stack du projet et suggère des plugins OpenCode de la communauté.

---

## `/ciel-audit`

**Post-mortem de session — détecte les violations du paradigme Ciel.**

```
Usage: /ciel-audit [--sessions=<N>]
```

Analyse les sessions récentes et produit un rapport sur les violations du workflow Ciel (dispatch manqué, gates ignorés, etc.).

---

## Résumé des commandes

| Commande | Arguments | Agent dispatché | Contexte |
|----------|-----------|-----------------|----------|
| `/ciel <tâche>` | Texte libre | — | Session principale |
| `/ciel-init` | `--check`, `--user`, `--platform` | — | Inline |
| `/ciel-update` | `--check` | — | Inline |
| `/ciel-improve` | `--sessions` | improver | Fork |
| `/ciel-eval` | `[skill-name]` | improver | Fork |
| `/ciel-create-skill` | `<nom> "<desc>"` | improver | Fork |
| `/ciel-refresh` | `--skill` | improver (ou inline si complet) | Mixte |
| `/ciel-recommend` | `--category` | — | Inline |
| `/ciel-audit` | `--sessions` | — | Inline |

---

## Voir aussi

- [Guide : Utiliser Ciel](../guides/using-ciel.md)
- [Référence : Configuration](configuration.md)
- [Système d'agents](../explanation/agents.md)
