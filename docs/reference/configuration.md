# Référence de configuration

> **Les fichiers de configuration de Ciel — structure, champs, valeurs possibles.**

---

## `opencode.json`

Le fichier de configuration principal pour OpenCode. Situé à la racine du projet.

**Source** : `opencode.json`

### Structure complète

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "plugin": [
    "./.opencode/plugins/ciel.ts"
  ],
  "agent": {
    "ciel": { ... },
    "ciel-researcher": { ... },
    "ciel-explorer": { ... },
    "ciel-critic": { ... },
    "ciel-improver": { ... }
  },
  "permission": {
    "task": {
      "*": "allow"
    }
  }
}
```

### Champs

| Champ | Type | Obligatoire | Description |
|-------|------|-------------|-------------|
| `$schema` | string | non | Schéma de validation JSON |
| `instructions` | string[] | recommandé | Fichiers d'instructions système |
| `plugin` | string[] | oui (pour Ciel) | Chemins des plugins TypeScript |
| `agent` | object | oui (pour Ciel) | Définitions des agents |
| `permission` | object | recommandé | Permissions des outils |

### Définition des agents

Chaque agent est défini avec :

```json
"<agent-name>": {
  "description": "<texte>",
  "mode": "primary | subagent",
  "prompt": "{file:./.opencode/agents/<agent>.md}",
  "temperature": 0.1 | 0.2 | 0.7,
  "tools": {
    "read": true | false,
    "write": true | false,
    "edit": true | false,
    "bash": true | false,
    "glob": true | false,
    "grep": true | false,
    "webfetch": true | false,
    "websearch": true | false
  }
}
```

### Permissions

```json
"permission": {
  "task": {
    "ciel-researcher": "allow",
    "ciel-explorer": "allow",
    "ciel-critic": "allow",
    "ciel-improver": "allow",
    "*": "allow"
  }
}
```

---

## `.opencode/agents/ciel.md`

Le fichier de définition de l'agent primaire. Frontmatter YAML :

```yaml
---
description: Ciel — Primary orchestrator. Full pipeline...
mode: primary
temperature: 0.2
permission:
  edit: allow
  bash: allow
  task:
    ciel-researcher: allow
    ciel-explorer: allow
    ciel-critic: allow
    ciel-improver: allow
---
```

Les permissions dans le frontmatter sont les permissions par défaut de l'agent, qui peuvent être overridées par `opencode.json`.

---

## `ciel-overlay.md`

Overlay projet chargé automatiquement par le plugin. Situé à la racine du projet.

### Structure

```markdown
# Ciel Overlay — [Nom du Projet]

## Stack
- Frontend: [lib + version]
- Backend: [framework + version]
- DB: [type + version]

## URLs docs
| Lib | Version | URL |
|-----|---------|-----|
| React | 19.0.0 | https://react.dev |

## Fichiers critiques
- src/auth/
- *Service.*
- *Routes.*

## CI commands
- Test: `pnpm test`
- Lint: `pnpm lint`

## Leçons projet
- [date] MISTAKE: ... → RULE: ...
```

Le plugin injecte ce contenu dans chaque system prompt après avoir redacté les sections marquées `sensitive: true`.

---

## `.claude/settings.json` (Claude Code)

Pour les utilisateurs Claude Code, les hooks sont configurés dans `settings.json` :

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/session-start.sh", "statusMessage": "Ciel: session starting..." }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/user-prompt-submit.sh", "statusMessage": "Ciel: classifying depth..." }] }
    ],
    "PreToolUse": [
      { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/pre-tool-write.sh", "statusMessage": "Ciel: FLUX check..." }] },
      { "matcher": "Agent", "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/pre-agent-gate.sh", "statusMessage": "Ciel: agent type gate..." }] }
    ],
    "PostToolUse": [
      { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/post-tool-write.sh", "statusMessage": "Ciel: RELIRE dispatch..." }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/stop.sh", "statusMessage": "Ciel: META-CRITIQUER..." }] }
    ],
    "SubagentStop": [
      { "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/subagent-stop.sh", "statusMessage": "Ciel: agent report size log..." }] }
    ],
    "PreCompact": [
      { "hooks": [{ "type": "command", "command": "bash $CIEL_DIR/hooks/pre-compact.sh", "statusMessage": "Ciel: session progress save..." }] }
    ]
  }
}
```

---

## `package.json` (OpenCode plugin)

```json
{
  "devDependencies": {
    "@types/node": "^25.6.0",
    "typescript": "^6.0.3"
  },
  "dependencies": {
    "@opencode-ai/plugin": "1.14.20"
  }
}
```

---

## Configuration des platforms

Chaque platform a sa propre configuration dans `platforms/<platform>/` :

| Platform | Fichier de config | Format |
|----------|------------------|--------|
| Cursor | `.cursor/rules/ciel.mdc` | Markdown rule |
| Windsurf | `.windsurf/rules/*.md` | Markdown rules |
| Codex | `AGENTS.md` | Markdown |
| OpenCode | `opencode.json` | JSON |
| Kilocode | `.kilocode/rules/ciel.md` | Markdown rule |
| Ollama | `Modelfile` | Docker-like |
| LM Studio | `ciel.preset.json` | JSON |

---

## Voir aussi

- [OpenCode config](https://opencode.ai/docs) — Documentation officielle OpenCode
- [Guide d'installation](../guides/install.md)
- [Guide : Utiliser Ciel](../guides/using-ciel.md)
- [Référence des agents](agents.md)
