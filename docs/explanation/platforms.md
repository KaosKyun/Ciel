# Distribution multi-plateformes

> **Ciel supporte 7 plateformes de développement. Le même noyau de skills est compressé différemment selon les contraintes de chaque plateforme.**

---

## Pourquoi 7 plateformes ?

Ciel a été initialement conçu pour Claude Code, mais l'écosystème des agents de codage s'est diversifié. Aujourd'hui, Ciel tourne sur :

1. **Cursor** — Agent de codage IA natif
2. **Windsurf** — IDE agentique
3. **Codex** — CLI agentique d'Anthropic
4. **OpenCode** — CLI agentique open-source
5. **Kilocode** — CLI agentique minimaliste
6. **Ollama** — LLM local (sans agent)
7. **LM Studio** — LLM local (sans agent)

---

## Architecture de compression

```
skills/ (~50 skills, ~2 MB)
    │
    ▼
scripts/build-platforms.sh
    │
    ├──→ platforms/cursor/        (.cursor/rules/ciel.mdc)        ≤6 KB
    ├──→ platforms/windsurf/      (.windsurf/rules/*.md)          ≤6 KB rules
    ├──→ platforms/codex/         (AGENTS.md)                     ≤32 KB
    ├──→ platforms/opencode/      (.opencode/plugins/ciel.ts)     ≤65 KB
    ├──→ platforms/kilocode/      (.kilocode/rules/ciel.md)       ≤6 KB
    ├──→ platforms/ollama/        (Modelfile)                     taille libre
    └──→ platforms/lmstudio/      (ciel.preset.json + system-prompt.md)
```

---

## Les 7 plateformes en détail

### 1. Cursor

| Propriété | Valeur |
|-----------|--------|
| **Format** | `.cursor/rules/ciel.mdc` |
| **Limite** | ≤6 KB |
| **Type** | Règle markdown Cursor |
| **Contenu** | Workflow Ciel compressé (depth + pipeline + dispatch rules) |

Cursor utilise un seul fichier de règles. Le contenu est une version fortement compressée du workflow — seuls les éléments essentiels sont conservés.

### 2. Windsurf

| Propriété | Valeur |
|-----------|--------|
| **Format** | `.windsurf/rules/*.md` |
| **Limite** | ≤6 KB per file, ≤12 KB total |
| **Type** | Règles markdown |
| **Contenu** | Workflow + règles de base |

Windsurf permet plusieurs fichiers de règles. Ciel peut donc fragmenter le contenu en 2-3 fichiers distincts.

### 3. Codex

| Propriété | Valeur |
|-----------|--------|
| **Format** | `AGENTS.md` |
| **Limite** | ≤32 KB |
| **Type** | Fichier d'instructions agent |
| **Contenu** | Workflow complet + dispatch rules + skills list |

Codex permet un fichier d'instructions plus volumineux. Ciel y inclut la description du pipeline complet et la liste des skills disponibles.

### 4. OpenCode

| Propriété | Valeur |
|-----------|--------|
| **Format** | `.opencode/plugins/ciel.ts` |
| **Limite** | ≤65 KB |
| **Type** | Plugin TypeScript |
| **Contenu** | Plugin complet : hooks, agents, commands, skills |

**OpenCode est la plateforme de première classe de Ciel.** C'est la seule qui reçoit l'intégralité du plugin TypeScript avec tous les événements, agents, et hooks.

### 5. Kilocode

| Propriété | Valeur |
|-----------|--------|
| **Format** | `.kilocode/rules/ciel.md` |
| **Limite** | ≤6 KB |
| **Type** | Règle markdown |
| **Contenu** | Workflow compressé (minimal) |

Kilocode est une plateforme minimaliste. La règle Ciel est très compressée.

### 6. Ollama

| Propriété | Valeur |
|-----------|--------|
| **Format** | `Modelfile` |
| **Limite** | Aucune |
| **Type** | Configuration de modèle |
| **Contenu** | SYSTEM prompt + configuration du LLM |

Ollama exécute des LLM localement. Ciel fournit un system prompt d'environ 300 tokens qui décrit le principe et le workflow de base.

### 7. LM Studio

| Propriété | Valeur |
|-----------|--------|
| **Format** | `ciel.preset.json` + `system-prompt.md` |
| **Limite** | Aucune |
| **Type** | Preset de modèle |
| **Contenu** | Configuration LLM + system prompt |

LM Studio permet de charger des presets. Ciel fournit une configuration de modèle et un system prompt dédié.

---

## Commandes de build

### Build complet

```bash
./scripts/build-platforms.sh --target=all
```

### Build spécifique

```bash
./scripts/build-platforms.sh --target=opencode
./scripts/build-platforms.sh --target=cursor
```

### Dry run (vérification sans écriture)

```bash
./scripts/build-platforms.sh --dry-run
```

### Vérification des limites

```bash
for platform in cursor windsurf codex opencode kilocode; do
  echo "=== $platform ==="
  du -sh "platforms/$platform/"
done
```

---

## Validation en CI

Le workflow `platform-validation.yml` valide chaque plateforme en parallèle lors des PR modifiant `platforms/` :

```yaml
jobs:
  validate-cursor:
    runs-on: ubuntu-latest
    steps:
      - name: Check size
        run: |
          size=$(wc -c < platforms/cursor/.cursor/rules/ciel.mdc)
          [ "$size" -le 6144 ] || exit 1
```

---

## Voir aussi

- [Architecture CI/CD](ci-cd.md)
- [Guide : Installer Ciel](../guides/install.md)
- [Guide CI/CD complet](../../CI-CD-GUIDE.md)
