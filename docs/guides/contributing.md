# Guide de contribution

> **Comment contribuer à Ciel — standards, workflow, et bonnes pratiques.**

---

## Principes

Contribuer à Ciel, c'est contribuer à un système qui **s'améliore lui-même**. Chaque contribution doit respecter la philosophie :

- **Understand before generating** : comprenez le pattern existant avant d'en créer un nouveau
- **Verify before claiming done** : testez avant de soumettre
- **One skill = one problem** : chaque skill fait exactement une chose

---

## Types de contribution

| Type | Description | Difficulté |
|------|-------------|------------|
| **Nouveau skill** | Ajouter une compétence à la bibliothèque | Élevée |
| **Amélioration skill** | Améliorer un skill existant | Moyenne |
| **Correction bug** | Bug dans hooks, plugin, ou CI/CD | Faible-Moyenne |
| **Documentation** | Améliorer la documentation | Faible |
| **Nouveau test** | Ajouter des cas de test | Faible |
| **Nouveau hook** | Ajouter un hook bash | Moyenne |
| **Nouveau workflow** | Ajouter un workflow CI/CD | Moyenne |

---

## Workflow de contribution

### 1. Créer une issue

Pour toute contribution significative, créez d'abord une issue GitHub :

```
/ciel crée une issue pour: "Ajouter un skill de validation email"
```

### 2. Créer une branche

```bash
git checkout -b feat/<issue-number>-<slug>
```

Ou utilisez la commande Ciel :

```
/ciel crée une branche feat/42-email-validator
```

### 3. Développer

Suivez le pipeline Ciel standard :

```
1. QUOI : cadrer l'objectif
2. AVEC QUOI : vérifier les versions
3. RECHERCHE : documentation existante
4. CODEBASE : explorer les patterns existants
5. FAIRE : implémenter (test-first)
6. RELIRE : relecture critique
7. PROUVER : preuve de validation
```

### 4. Tester localement

```bash
# Lint hooks
shellcheck hooks/*.sh

# Test plugin TS
cd .opencode && npx tsc --noEmit plugins/ciel.ts

# Test unitaire
npx tsx test-ciel.ts

# Test hooks
bash scripts/test-stop-hook.sh

# Build platforms
bash scripts/build-platforms.sh --target=all
```

### 5. Commiter

```bash
git add .
git commit -m "feat(#42): add email-validator skill

- Regex RFC 5322 simplifié
- Whitelist de domaines configurables
- 3 cas de test (valide, invalide, domaine refusé)

Refs #42"
```

Format des messages de commit :
- `feat:` pour un nouveau skill ou une nouvelle feature
- `fix:` pour une correction
- `chore:` pour la maintenance
- `docs:` pour la documentation
- `refactor:` pour le refactoring

### 6. Ouvrir une PR

```bash
gh pr create --title "feat(#42): add email-validator skill"
```

Ou :

```
/ciel ouvre une PR
```

### 7. Vérifier la CI

```
/ciel watch CI
```

Ciel surveille la CI et distingue les échecs flaky des vrais échecs.

---

## Standards de code

### Skills

```markdown
---
name: <kebab-case>
description: <1-2 phrases, max 200 caractères>
context: inline | fork
---

# Titre

## Quand l'utiliser
<WHEN-triggered>

## Pattern

```code
```

## Anti-patterns

## Vérification
```

### Hooks

```bash
#!/bin/bash
# Ciel — <Nom> hook
# Never blocks (exit 0 always)

shift $# 2>/dev/null || true

echo "CIEL <CONTEXTE> — <Message>"
exit 0
```

Règles :
- `exit 0` toujours (non-bloquant)
- `set -euo pipefail` sauf pour les hooks qui doivent être tolérants
- `shellcheck` doit passer (niveau error, warnings acceptés)
- Privilégier bash ≥ 4.0 (portable)

### Plugin TypeScript

```typescript
// Ciel — <Nom> event handler
// <Description>

import type { Plugin } from "@opencode-ai/plugin";

const ciel: Plugin = async ({ client }) => {
  return {
    // handlers
  };
};

export default ciel;
```

### CI/CD Workflows

```yaml
name: <Nom>
on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  <nom-job>:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
```

---

## Review de PR

### Pour le reviewer

1. Le skill suit-il le format Skills-first ?
2. Y a-t-il des tests ?
3. La documentation est-elle à jour ?
4. Les byte limits sont-ils respectés ?
5. Les hooks passent-ils shellcheck ?
6. Le plugin compile-t-il ?

### Pour le contributeur

1. Tous les checks CI passent (vert)
2. Au moins 1 review approbation
3. Pas de conflits avec main
4. CHANGELOG.md mis à jour (si pertinent)

---

## CI/CD locale

Avant de pusher, exécutez toujours :

```bash
# 1. Vérifications rapides
shellcheck hooks/*.sh                              # Lint hooks
cd .opencode && npx tsc --noEmit plugins/ciel.ts   # Compile plugin
cd ..

# 2. Tests
npx tsx test-ciel.ts                                # Tests unitaires
bash scripts/test-stop-hook.sh                      # Tests hooks

# 3. Build validation
bash scripts/build-platforms.sh --target=all        # Build toutes platforms
```

---

## Voir aussi

- [Guide : Créer un skill](creating-skill.md) — Détail création de skill
- [Référence : Configuration](../reference/configuration.md)
- [Référence : Hooks](../reference/hooks.md)
- [Architecture CI/CD](../explanation/ci-cd.md)
