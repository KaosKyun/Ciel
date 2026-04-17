# Test du script PowerShell install.ps1

## Prérequis

- PowerShell 7+ installé (`pwsh --version`)
- Sur Windows : PowerShell natif ou WSL avec `pwsh` installé
- Sur macOS/Linux : installer PowerShell avec `brew install powershell` ou équivalent

## Tests à exécuter

### 1. Syntax check (toutes plateformes)

```bash
pwsh -NoProfile -Command "Get-Content scripts/install.ps1 | Invoke-Expression -ErrorAction Stop"
```

**Résultat attendu** : Aucune erreur de syntaxe

### 2. Help flag

```bash
pwsh -File scripts/install.ps1 --help
```

**Résultat attendu** : Affiche l'en-tête du script avec les flags disponibles

### 3. Check update (nécessite une install préalable)

```bash
pwsh -File scripts/install.ps1 --check-update
```

**Résultat attendu** :
- Si manifest existe : compare les versions
- Si pas de manifest : warning "run a fresh install first"

### 4. Dry-run avec --platform=opencode

```bash
# Dans un projet de test
cd /tmp/test-opencode
pwsh /path/to/install.ps1 --platform=opencode
```

**Résultat attendu** :
- Détecte OpenCode (si installé) ou demande confirmation
- Copie `AGENTS.md`
- Merge `opencode.json` (si existe) ou le crée
- Copie `.opencode/plugins/ciel.ts`
- Copie `.opencode/agents/ciel-*.md`
- Copie `.opencode/commands/ciel*.md`
- Crée `ciel-overlay.md`
- Écrit le manifest

### 5. Vérifier que opencode.json n'est PAS écrasé

```bash
# Avant install
echo '{"model": "gpt-4", "custom": "value"}' > opencode.json

# Après install avec --platform=opencode
cat opencode.json
```

**Résultat attendu** :
```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "gpt-4",
  "custom": "value",
  "instructions": ["AGENTS.md"],
  "plugin": ["./.opencode/plugins/ciel.ts"]
}
```

Les clés originales (`model`, `custom`) doivent être **préservées**.

### 6. Test du flag --platform

```bash
# Force OpenCode même si Claude est détecté
pwsh install.ps1 --platform=opencode
```

**Résultat attendu** :
- Message : "Using platform: opencode (from --platform flag)"
- N'affiche PAS la liste de détection automatique
- N'installe QUE OpenCode

### 7. Comparaison Bash vs PowerShell

Sur WSL ou une machine avec les deux shells :

```bash
# Bash
bash install.sh --platform=opencode --check-update

# PowerShell
pwsh install.ps1 --platform=opencode --check-update
```

**Résultat attendu** : Même sortie (versions, messages)

## Bugs connus à vérifier

- [ ] `opencode.json` écrasé au lieu d'être fusionné → **FIXED** dans v2.4.0
- [ ] `--platform` flag ignoré → **FIXED** dans v2.4.0
- [ ] Détection automatique force Claude → **FIXED** avec `--platform` override
- [ ] PowerShell hooks en `pwsh -File` au lieu de `bash` → **FIXED** (utilise bash comme install.sh)

## Checklist de parité avec install.sh

- [x] `--platform=<name>` flag
- [x] Non-destructive `opencode.json` merge via Python
- [x] Manifest tracking (`~/.ciel/manifest.json`)
- [x] `--check-update` / `--update` / `--uninstall` flags
- [x] Whitelist preservation (`.mcp.json`, `ciel-overlay.md`, `opencode.json`, `.claude/settings.json`)
- [x] Semver comparison
- [x] Platform detection with auto-detect override
- [x] MCP server registration (`--with-mcp=`)
- [x] Post-install next steps messages

## Comment reporter un bug

1. Version : `pwsh -File scripts/install.ps1 --check-update`
2. Système : Windows native / WSL / macOS / Linux
3. Shell : PowerShell version (`$PSVersionTable.PSVersion`)
4. Erreur complète (copier-coller)
5. Étapes pour reproduire
