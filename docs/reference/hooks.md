# Référence des hooks

> **Les 8 hooks bash — points de déclenchement, format d'entrée/sortie, comportement.**

---

## Vue d'ensemble

| # | Hook | Événement | Type | Bloquant |
|---|------|-----------|------|----------|
| 1 | `session-start.sh` | SessionStart | Information | Non |
| 2 | `user-prompt-submit.sh` | UserPromptSubmit | Classification | Non |
| 3 | `pre-tool-write.sh` | PreToolUse (Write\|Edit) | Rappel | Non |
| 4 | `pre-agent-gate.sh` | PreToolUse (Agent) | **Blocage** | **Oui** |
| 5 | `post-tool-write.sh` | PostToolUse (Write\|Edit) | Rappel | Non |
| 6 | `stop.sh` | Stop | Méta-réflexion | Non |
| 7 | `subagent-stop.sh` | SubagentStop | Monitoring | Non |
| 8 | `pre-compact.sh` | PreCompact | Sauvegarde | Non |

**Règle** : tous les hooks non-bloquants retournent `exit 0`. Le seul bloquant est `pre-agent-gate.sh`.

---

## 1. `session-start.sh`

**Fichier** : `hooks/session-start.sh` (12 lignes)

**Déclencheur** : SessionStart

**Entrée** : aucune

**Sortie** :
```
CIEL v4.0.1 — Skills-first deep-reasoning active.
Overlay loaded: /path/to/ciel-overlay.md.
Trace ID: 20260426T120000Z-12345.
Principle: Understand before generating. Verify before claiming done.
```

**Code** :
```bash
#!/bin/bash
shift $# 2>/dev/null || true
OVERLAY=""
[ -f "ciel-overlay.md" ] && OVERLAY=" Overlay loaded: $(pwd)/ciel-overlay.md."
TRACE_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
echo "CIEL v4.0.1 — Skills-first deep-reasoning active.${OVERLAY} Trace ID: ${TRACE_ID}. Principle: Understand before generating. Verify before claiming done."
exit 0
```

---

## 2. `user-prompt-submit.sh`

**Fichier** : `hooks/user-prompt-submit.sh` (34 lignes)

**Déclencheur** : UserPromptSubmit

**Entrée** : JSON via stdin avec champ `prompt`

**Sortie** (JSON) :
```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "CIEL depth hint: Critical (auth/security/payment keyword detected). Invoke depth-classifier if ambiguous before routing pipeline."
  }
}
```

**Logique de classification** :
- Détection `auth|security|payment|jwt|oauth|password|secret|token|session|2fa|encryption|credential` → **Critical**
- Sinon, détection `rename|typo|copyright|comment|readme|spelling` → **Trivial**
- Sinon → **Standard**

---

## 3. `pre-tool-write.sh`

**Fichier** : `hooks/pre-tool-write.sh` (8 lignes)

**Déclencheur** : PreToolUse avec matcher `Write|Edit`

**Sortie** :
```
CIEL FAIRE — Before writing: (1) alternatives considered? (2) idiomatic? (3) quality gates? (4) test-first (RED)? (5) removal gate?
```

---

## 4. `pre-agent-gate.sh`

**Fichier** : `hooks/pre-agent-gate.sh` (47 lignes)

**Déclencheur** : PreToolUse avec matcher `Agent`

**Type** : ⚠️ **BLOQUANT**

**Entrée** : JSON via stdin avec champ `tool_input.subagent_type`

**Logique** :
1. Lit `subagent_type` depuis l'entrée JSON
2. Si `subagent_type` commence par `ciel-` → **autorise** (exit 0)
3. Sinon → **refuse** avec message d'erreur détaillé
4. Escape hatch : `[CIEL_GATE_BYPASS]` dans le prompt force l'autorisation

**Sortie si bloqué** :
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "[CIEL AGENT GATE] Blocked: subagent_type=\"general\" is not a Ciel agent. Re-dispatch with subagent_type=\"ciel-researcher\" | \"ciel-explorer\" | \"ciel-critic\" | \"ciel-improver\". Add [CIEL_GATE_BYPASS] to prompt to force-allow."
  }
}
```

---

## 5. `post-tool-write.sh`

**Fichier** : `hooks/post-tool-write.sh` (8 lignes)

**Déclencheur** : PostToolUse avec matcher `Write|Edit`

**Sortie** :
```
CIEL RELIRE — File written. Review: (1) 3 RISQUES (functional + imports + data) (2) FIX/ACCEPT/DEFER.
```

---

## 6. `stop.sh`

**Fichier** : `hooks/stop.sh` (8 lignes)

**Déclencheur** : Stop

**Sortie** :
```
CIEL STOP — 30s META-CRITIQUER obligatoire avant de declarer fini:
(1) depth match? (2) new failure mode → Guard? (3) user correction → overlay/learnings?
(4) stale branches? (5) uncovered issues? (6) context health?
(7) session-progress.md written? (8) dead code sweep (ruff/knip/Detekt)?
Invoke meta-critiquer skill then learnings-capture if corrections detected.
```

---

## 7. `subagent-stop.sh`

**Fichier** : `hooks/subagent-stop.sh` (39 lignes)

**Déclencheur** : SubagentStop

**Entrée** : JSON via stdin avec champs `agent_type`, `result`/`output`

**Logique** :
1. Calcule la taille du rapport en tokens (ratio 1.33)
2. Si < 200 tokens → alerte de troncature suspecte
3. Log dans `~/.claude/plugins/ciel/evals/results/subagent-stops.jsonl`

**Sortie si troncature** :
```
CIEL WARN — ciel-critic agent report is only 150 tokens. Suspect truncation on Standard/Critical task. Consider re-dispatching with narrower scope.
```

---

## 8. `pre-compact.sh`

**Fichier** : `hooks/pre-compact.sh` (8 lignes)

**Déclencheur** : PreCompact

**Sortie** :
```
CIEL PRE-COMPACT — Invoke learnings-capture skill NOW. Persist user corrections + failure modes + failed approaches.
```

---

## Paires de hooks

Certains hooks fonctionnent en tandem :

| Paire | Premier | Second | Objectif |
|-------|---------|--------|----------|
| FAIRE | `pre-tool-write.sh` | Plugin `tool.execute.before` | Rappel + vérification test-first |
| RELIRE | `post-tool-write.sh` | Plugin `tool.execute.after` | Rappel + sticky RELIRE |
| META | `stop.sh` | Plugin `session.idle` | Post-task reflection |
| LEARN | `pre-compact.sh` | Plugin `experimental.session.compacting` | Capture de leçons |

---

## Voir aussi

- [Système de hooks (explication)](../explanation/hooks.md)
- [Pipeline détaillé](../explanation/pipeline.md)
- [Configuration](configuration.md)
