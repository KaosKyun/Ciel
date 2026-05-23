---
name: code-quality
description: "Code Quality — linting, formatting, analyse statique, dette technique, conventions, style guide. A charger quand on parle de qualite de code."
---

# Code Quality

## Checklist
- [ ] Le projet a un linter (ESLint, Biome, Ruff) avec des regles strictes
- [ ] Le formattage est automatise (Prettier, dprint, gofmt) — pas de debat de style
- [ ] L'analyse statique est dans la CI (bloque si regle violee)
- [ ] La dette technique est suivie (pas de seuil, mais tendance)
- [ ] Les imports sont tries et aucun import inutile
- [ ] Les types sont explicites (pas de `any`, `object`, `var`)
- [ ] La complexite cyclomatique est < 10 par fonction

## Anti-patterns
### Linter sans CI
**Ce qu'on voit :** ESLint configure mais pas dans la CI. `npm run lint` est lance manuellement.
**Pourquoi c'est dangereux :** le linter est ignore apres la premiere semaine. Les regles sont violees partout. Il devient du bruit.
**Faire plutot :** `lint` dans le pipeline CI. La PR est bloquee si le linter echoue. Pas d'exception.

### Trop de regles
**Ce qu'on voit :** 200 regles ESLint, 50 plugins, des regles personnalisees partout.
**Pourquoi c'est dangereux :** le linter devient un enfer. Les devs desactivent des regles, ajoutent des ignores, ou passent leur temps a fixer des warnings inutiles.
**Faire plutot :** regles strictes mais peu nombreuses. Les plus importantes : `no-unused-vars`, `no-any` (TS), `no-console`. Ajouter au besoin, pas par precaution.

### Dette technique non suivie
**Ce qu'on voit :** "on nettoiera apres la release". La release arrive, on nettoie jamais.
**Pourquoi c'est dangereux :** la dette s'accumule. Le code devient impossible a maintenir. Chaque nouvelle feature prend 3x plus de temps.
**Faire plutot :** budget dette : 20% du temps sprint dedie au refactoring. Suivi dans un backlog. Jamais de "on nettoiera plus tard" sans ticket.

## Patterns
### Pre-commit hook
**Quand :** tout projet avec plusieurs contributeurs.
**Comment :** linter + formatteur lance avant chaque commit. Correction automatique si possible. Le commit est bloque si le code est mal formatte.

### Strict mode dès le debut
**Quand :** nouveau projet.
**Comment :** TypeScript strict, ESLint avec regles strictes, Biome ou Prettier. Configurer au `npm init` ou `create`. Ajouter des regles est plus dur que commencer strict.
