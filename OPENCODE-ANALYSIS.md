# Ciel sur OpenCode — Analyse et Plan d'Implémentation

## Résumé de la session

L'utilisateur a passé cette session à tenter d'adapter Ciel (orchestrateur de raisonnement profond pour Claude Code) sur OpenCode.

**Objectif:** Que Ciel fonctionne sur OpenCode comme sur Claude Code — avec `/ciel`, des hooks, des subagents, etc.

---

## Ce qui a été fait ✅

### 1. Scripts d'installation
- [x] Fix syntaxe PowerShell (`for` → `foreach`)
- [x] Release v2.7.1 avec le fix

### 2. Configuration OpenCode
- [x] Agent primaire `ciel` (mode: primary)
- [x] 4 subagents configurés: `ciel-explorer`, `ciel-critic`, `ciel-researcher`, `ciel-improver`
- [x] Frontmatter corrigé pour tous les agents (description: --- invalid)
- [x] Frontmatter corrigé pour toutes les commandes

### 3. Plugin OpenCode
- [x] Plugin ultra-minimal (v2.7.3) — pas de débordement
- [x] Hooks silencieux avec `[C]` prefix
- [x] Depth classification
- [x] FAIRE/RELIRE reminders

### 4. Custom Tools
- [x] Outil `ciel` pour switcher/invoquer l'agent

---

## Ce qui ne fonctionne PAS ❌

### Problème 1: Subagents non invoquables depuis IDE/Web
**Cause:** L'outil `task()` n'est disponible que dans le TUI, pas dans l'interface IDE/Web.

**Impact:**
- On ne peut pas invoquer `@ciel-explorer`, `@ciel-researcher`, etc. depuis cette interface
- Le pipeline Ciel (qui dispatch les subagents) ne fonctionne pas

**Documentation OpenCode confirme:**
> Les subagents peuvent être invoqués automatiquement par les agents primaires ou manuellement via `@` mention dans les messages.

Mais les agents primaires ont besoin de l'outil `task()` pour dispatcher.

### Problème 2: Hooks avec timing différent
**Claude Code vs OpenCode:**

| Hook Claude Code | OpenCode | Différence |
|------------------|----------|------------|
| `UserPromptSubmit` | `experimental.chat.messages.transform` | Pas d'injection immédiate |
| `PreToolUse` | `tool.execute.before` | OK mais timing différent |
| `PostToolUse` | `tool.execute.after` | OK |
| `Stop` | `session.idle` | `idle` ≠ `stop` (timing différent) |
| `PreCompact` | `session.compacted` | Différent timing |
| `SubagentStop` | ❌ Pas d'équivalent | N'existe pas |

### Problème 3: Skills non chargés nativement
**Claude Code:** Le `skill` tool charge le SKILL.md et l'injecte dans le contexte.

**OpenCode:** Les skills doivent être bundleés inline dans les agents (ce qu'on a fait, c'est correct).

---

## Ce qui est possible sur OpenCode ✅

### 1. Plugin System (Équivalent: hooks partiels)
- `session.created` — début de session ✅
- `session.idle` — fin/inactive (timing différent) ⚠️
- `tool.execute.before/after` — hooks outils ✅
- `experimental.chat.system.transform` — injection system prompt ✅
- `experimental.chat.messages.transform` — lecture messages ✅
- `experimental.session.compacting` — compaction ✅

### 2. Agents (Équivalent: subagents)
- `mode: "primary"` — agent principal interactif ✅
- `mode: "subagent"` — assistant spécialisé ✅
- `permission.task` — configurer quels sous-agents invoquer ✅

### 3. Custom Tools (Équivalent: outils personnalisés)
- `tool()` helper pour créer des outils ✅
- Peut hooker sur les tool calls ✅

### 4. Commands (Équivalent: commandes)
- `.opencode/commands/*.md` ✅
- `$ARGUMENTS` substitution ✅

---

## Plan d'implémentation réaliste

### Phase 1: Optimiser ce qui fonctionne (1-2h)

#### 1.1 Plugin avec hooks optimisés
```typescript
// Optimiser le plugin pour:
// - session.created: logique de démarrage
// - system.transform: injection depth hint + RELIRE
// - messages.transform: classification
// - tool.execute.after: FAIRE reminders
// - session.idle: META-CRITIQUER final
```

#### 1.2 Agent primaire Ciel avec instructions claires
```json
{
  "agent": {
    "ciel": {
      "mode": "primary",
      "prompt": "{file:./AGENTS.md}",
      "permission": {
        "task": {
          "ciel-explorer": "allow",
          "ciel-researcher": "allow", 
          "ciel-critic": "allow",
          "ciel-improver": "allow"
        }
      }
    }
  }
}
```

#### 1.3 Instructions dans AGENTS.md
Bien documenter que l'agent peut invoquer les subagents via `task()`.

### Phase 2: Résoudre le problème d'invocation (2-4h)

#### 2.1 Options documentées par OpenCode

**Option A: Plugin avec tool personnalisé**
Créer un tool qui invoque les agents. Mais cela nécessite que le modèle l'appelle.

**Option B: Modifier le prompt de l'agent**
L'agent primaire doit recevoir les instructions pour invoquer les subagents automatiquement via `task()`.

**Option C: Commande `/ciel` modifiée**
La commande `/ciel` pourrait:
1. Lire le contexte
2. Classifier la tâche
3. Suggérer l'agent à invoquer

#### 2.2 Recommandation: Option B + C
Combiner un prompt clair pour l'agent primaire + une commande qui guide.

### Phase 3: Documentation et tests (1h)

#### 3.1 Documenter les différences
Créer `OPENCODE-DIFFERENCES.md` avec:
- Ce qui fonctionne
- Ce qui ne fonctionne pas
- Comment adapter son workflow

#### 3.2 Tests utilisateur
- Tester `/ciel` dans le TUI
- Tester `@ciel` dans le TUI
- Tester l'invocation de subagents

---

## Résumé final

| Feature | Status | Solution |
|---------|--------|----------|
| Agent primaire Ciel | ✅ Fonctionne | Déjà créé |
| Subagents configurés | ✅ Configurés | Mais non invoqués depuis IDE/Web |
| Plugin hooks | ✅ Partiels | Ultra-minimal, silencieux |
| `/ciel` command | ✅ Fonctionne | Affiche instructions |
| Subagents auto-dispatch | ❌ Ne fonctionne pas | Uniquement dans TUI |
| Depth classification | ✅ Fonctionne | Plugin injection |
| FAIRE/RELIRE | ✅ Fonctionne | Plugin reminders |
| META-CRITIQUER | ⚠️ Timing différent | session.idle ≠ stop |

**Conclusion:** Ciel fonctionne **partiellement** sur OpenCode. L'expérience complète (avec auto-dispatch des subagents) n'est disponible que dans le **TUI OpenCode**, pas dans l'interface IDE/Web.

**Pour l'interface IDE/Web**, la solution la plus réaliste est:
1. Utiliser `@ciel` directement dans les messages
2. Ou ouvrir un terminal avec `opencode` pour l'expérience complète
