# Système de hooks

> **Les 8 hooks bash de Ciel forment le système nerveux qui connecte le cycle de vie d'OpenCode aux décisions de Ciel.**

---

## Vue d'ensemble

Ciel utilise le système de hooks d'OpenCode (ou de Claude Code) pour s'injecter dans le cycle de vie de chaque session. Les hooks sont des scripts bash qui s'exécutent à des moments précis, sans jamais bloquer (exit 0 toujours).

```
Session             User            PreToolUse        PostToolUse           Stop
Start             Prompt            (Write/Edit)       (Write/Edit)
   │                 │                  │                  │                 │
   ▼                 ▼                  ▼                  ▼                 ▼
┌──────┐       ┌──────────┐      ┌──────────┐       ┌──────────┐      ┌────────┐
│session│──────►│user──────►│──────►│pre───────►│──────►│post──────►│──────►│stop   │
│start │       │prompt    │      │tool-write│       │tool-write│       │       │
│.sh   │       │submit.sh │      │.sh       │       │.sh       │       │.sh    │
└──────┘       └──────────┘      └──────────┘       └──────────┘      └────────┘
                                                       │
                                                       │ (Agent dispatch)
                                                       ▼
                                                ┌──────────────┐
                                                │subagent-stop │
                                                │.sh           │
                                                └──────────────┘
```

---

## Les 8 hooks

### 1. `session-start.sh` — Début de session

**Déclencheur** : `SessionStart` (au démarrage de la session)

**Action** :
- Affiche la bannière Ciel avec la version
- Génère un TRACE_ID unique (`YYYYMMDDTHHMMSSZ-$$`)
- Vérifie si `ciel-overlay.md` existe

**Sortie typique** :
```
CIEL v4.0.1 — Skills-first deep-reasoning active.
Overlay loaded: /path/to/ciel-overlay.md.
Trace ID: 20260426T120000Z-12345.
Principle: Understand before generating. Verify before claiming done.
```

### 2. `user-prompt-submit.sh` — Classification de profondeur

**Déclencheur** : `UserPromptSubmit` (à chaque message utilisateur)

**Action** :
- Analyse le texte du prompt
- Détecte les mots-clés (auth, security, payment → Critical ; rename, typo → Trivial)
- Injecte un hint de classification dans le contexte

**Sortie** :
```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "CIEL depth hint: Standard (). Invoke depth-classifier if ambiguous before routing pipeline."
  }
}
```

### 3. `pre-tool-write.sh` — Rappel FAIRE gates

**Déclencheur** : `PreToolUse` avec matcher `Write|Edit`

**Action** :
- Rappelle les 5 FAIRE gates avant chaque écriture

**Sortie** :
```
CIEL FAIRE — Before writing: (1) alternatives considered?
(2) idiomatic? (3) quality gates? (4) test-first (RED)? (5) removal gate?
```

### 4. `pre-agent-gate.sh` — Bloqueur de subagents non-Ciel ⚠️

**Déclencheur** : `PreToolUse` avec matcher `Agent`

**Action** : **BLOQUE** tout dispatch de subagent qui n'est pas `ciel-*`.

**Fonctionnement** :
1. Lit le `subagent_type` depuis l'entrée JSON
2. Si le type commence par `ciel-` → autorise (exit 0)
3. Sinon → refuse avec message d'erreur

**Sortie en cas de blocage** :
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[CIEL AGENT GATE] Blocked: subagent_type=\"general\" is not a Ciel agent. Re-dispatch with subagent_type=\"ciel-researcher\" | \"ciel-explorer\" | \"ciel-critic\" | \"ciel-improver\". Add [CIEL_GATE_BYPASS] to prompt to force-allow."
  }
}
```

**Escape hatch** : inclure `[CIEL_GATE_BYPASS]` dans le prompt du Task pour forcer l'autorisation.

### 5. `post-tool-write.sh` — Déclencheur RELIRE

**Déclencheur** : `PostToolUse` avec matcher `Write|Edit`

**Action** :
- Rappelle de faire une relecture critique après écriture

**Sortie** :
```
CIEL RELIRE — File written. Review: (1) 3 RISQUES (functional + imports + data) (2) FIX/ACCEPT/DEFER.
```

### 6. `subagent-stop.sh` — Log de taille de rapport

**Déclencheur** : `SubagentStop` (quand un subagent termine)

**Action** :
- Calcule la taille du rapport en tokens
- Si < 200 tokens sur une tâche Standard/Critical → alerte (truncation suspecte)
- Log dans `~/.claude/plugins/ciel/evals/results/subagent-stops.jsonl`

**Sortie si troncature suspecte** :
```
CIEL WARN — ciel-critic agent report is only 150 tokens. Suspect truncation on Standard/Critical task. Consider re-dispatching with narrower scope.
```

### 7. `stop.sh` — META-CRITIQUER obligatoire

**Déclencheur** : `Stop` (fin de session)

**Action** :
- Force une méta-réflexion de 30 secondes
- 8 questions obligatoires avant de déclarer la tâche finie

**Sortie** :
```
CIEL STOP — 30s META-CRITIQUER obligatoire avant de declarer fini:
(1) depth match? (2) new failure mode → Guard? (3) user correction → overlay/learnings?
(4) stale branches? (5) uncovered issues? (6) context health?
(7) session-progress.md written? (8) dead code sweep (ruff/knip/Detekt)?
Invoke meta-critiquer skill then learnings-capture if corrections detected.
```

### 8. `pre-compact.sh` — Capture de leçons

**Déclencheur** : `PreCompact` (avant compression de session)

**Action** :
- Rappelle d'invoquer `learnings-capture` avant que le contexte ne soit perdu

**Sortie** :
```
CIEL PRE-COMPACT — Invoke learnings-capture skill NOW. Persist user corrections + failure modes + failed approaches.
```

---

## Configuration des hooks

Les hooks sont configurés dans le fichier de settings du platform :

### Claude Code (`settings.json`)
```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/session-start.sh" }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/user-prompt-submit.sh" }] }
    ],
    "PreToolUse": [
      { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/pre-tool-write.sh" }] },
      { "matcher": "Agent", "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/pre-agent-gate.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/post-tool-write.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/stop.sh" }] }
    ],
    "SubagentStop": [
      { "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/subagent-stop.sh" }] }
    ],
    "PreCompact": [
      { "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/pre-compact.sh" }] }
    ]
  }
}
```

### OpenCode (via plugin `ciel.ts`)
Les hooks sont injectés automatiquement par le plugin — aucune configuration manuelle requise.

---

## Principes de conception

### Non-bloquant
Tous les hooks se terminent par `exit 0`. Ils informent, rappellent, alertent — mais ne bloquent jamais le flux de travail.

### Légers
Chaque hook est un script bash de 5-50 lignes. Pas de dépendances lourdes, pas de logique complexe.

### Contextuels
Les hooks injectent du contexte dans la session — ils ne prennent pas de décisions. Les décisions sont prises par l'agent principal et le plugin TypeScript.

### Auto-réparateurs
Le hook bloquant (`pre-agent-gate.sh`) est le seul à pouvoir refuser une action — et il donne toujours la solution dans le message d'erreur.

---

## Voir aussi

- [Architecture générale](architecture.md)
- [Pipeline détaillé](pipeline.md)
- [Référence des hooks](../reference/hooks.md) — détails techniques
- [Guide : Installer Ciel](../guides/install.md)
