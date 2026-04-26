# Installer Ciel v5

> **Zero-config. Auto-detecte OpenCode ou Claude Code. Commande unique, idempotent, securise.**

---

## Installation

### Option 1 : Commande unique (recommande)

Depuis la racine de votre projet :

```bash
curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh | bash
```

Ou avec PowerShell (Windows) :

```powershell
irm https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.ps1 | iex
```

**Ce que l'installateur fait automatiquement :**
1. Detecte la plateforme (OpenCode ou Claude Code)
2. Telecharge les fichiers necessaires
3. Copie le plugin (.opencode/) ou les hooks (.claude/)
4. Cree `.ciel/` avec map.json, memory.json, parking.md
5. Copie les skills dans le dossier decouvrable
6. Configure les permissions

### Option 2 : Installation locale

```bash
git clone https://github.com/KaosKyun/Ciel.git
cd Ciel
bash scripts/install.sh
```

### Option 3 : Mise a jour

Re-executez la commande d'installation. L'installateur est idempotent :

```bash
curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh | bash
```

### Option 4 : Desinstallation

```bash
bash <(curl -fsSL .../install.sh) --uninstall
```

---

## Verification

### OpenCode

```bash
opencode
# Envoyez un message contenant "auth" ou "password"
# -> le system prompt doit contenir "[CIEL] Depth: Critical"
# -> le pipeline 16 etapes doit etre visible dans le system prompt
```

Options supplementaires :
```bash
OPENCODE_EXPERIMENTAL_LSP_TOOL=true opencode  # Navigation LSP avancee
OPENCODE_ENABLE_EXA=1 opencode                 # WebSearch via Exa
```

### Claude Code

```bash
cd votre-projet
claude
# /memory doit montrer auto memory enabled
# Editer un fichier .ts sans test -> hook doit bloquer
```

---

## Ce qui est installe

### OpenCode

```
.opencode/
  plugins/ciel.ts     # Plugin principal v5 (562 lignes)
  agents/ciel.md       # Agent orchestrateur pipeline 16 etapes
  agents/ciel-researcher.md
  agents/ciel-explorer.md
  agents/ciel-critic.md
  agents/ciel-improver.md
  commands/ciel-init.md
  commands/ciel-update.md
  commands/ciel-refresh.md
  commands/ciel-improve.md
  commands/ciel-eval.md
  commands/ciel-create-skill.md
  commands/ciel-recommend.md
  commands/ciel-audit.md
  skills/               # 63 skills discoverables
AGENTS.md              # Workflow complet
.ciel/                 # Etat persistant
```

### Claude Code

```
.claude/
  agents/ciel-researcher.md  # memory: user, model: haiku
  agents/ciel-explorer.md    # memory: project, isolation: worktree
  agents/ciel-critic.md      # memory: local, model: opus
  agents/ciel-improver.md
  hooks/check-test-first.sh
  hooks/block-destructive.sh
  hooks/track-file.sh
  hooks/meta-critiquer.sh
  settings.json              # 7 hooks configures
  rules/security.md
  rules/testing.md
  rules/api.md
  skills/                    # 63 skills discoverables
CLAUDE.md               # Instructions Claude Code
AGENTS.md               # Workflow partage
.ciel/                  # Etat persistant
```

---

## Configuration minimale

Aucune configuration manuelle necessaire. L'installateur gere tout.

Si vous voulez personnaliser :

```json
// opencode.json
{
  "plugin": ["./.opencode/plugins/ciel.ts"],
  "instructions": ["AGENTS.md"],
  "permission": {
    "question": "allow",
    "websearch": "allow",
    "bash": { "git *": "allow", "rm *": "deny" }
  }
}
```

```json
// .claude/settings.local.json (personnel, gitignore)
{
  "autoMemoryEnabled": true
}
```

---

## Migration depuis Ciel v4

1. Sauvegardez vos fichiers personnalises
2. Re-installez avec la commande unique
3. Les nouveautes v5 :
   - Pipeline 16 etapes (vs 10)
   - ASK window (question tool / plan mode)
   - DIVERGE (2-3 approches)
   - ADR auto (docs/adrs/)
   - MEMOIRE (.ciel/map.json persistant)
   - SPIKE mode (exploration.active)
   - Boy-scout rule (gate 6)
   - Anti-rationalization tables
   - Claude Code support complet

---

## Voir aussi

- [Utiliser Ciel au quotidien](using-ciel.md)
- [Architecture](../explanation/architecture.md)
- [Pipeline 16 etapes](../explanation/pipeline.md)
