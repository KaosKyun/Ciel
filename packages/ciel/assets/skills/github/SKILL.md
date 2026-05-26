---
name: github
description: "GitHub — issues, projets, branches, commits conventionnels, PR templates, CI/CD Actions, releases, code review. À charger quand on interagit avec GitHub (issues, PRs, branches, workflows)."
---

# GitHub

**Principe premier :** GitHub n'est pas juste un hébergeur de code — c'est la plateforme de collaboration qui relie le code, les issues, les PRs, la CI et les releases. Chaque élément (issue, branche, commit, PR, release) est un nœud dans un graphe lié. La valeur vient des liens : une PR sans issue liée est orpheline, un commit sans contexte est illisible, une release sans changelog est opaque. Bien utiliser GitHub, c'est maximiser la traçabilité entre ces nœuds.

## Checklist
- [ ] Les commits suivent Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`) — machine-readable, génère le changelog automatiquement
- [ ] Chaque PR est liée à une issue (Closes #N) et fait moins de 400 lignes modifiées
- [ ] Le repo a des templates d'issue (bug, feature) dans `.github/ISSUE_TEMPLATE/`
- [ ] Le repo a un template de PR dans `.github/pull_request_template.md`
- [ ] Les branches suivent une convention : `feat/`, `fix/`, `chore/`, `docs/` — et vivent ≤ 1 jour
- [ ] Les branches sont protégées sur main/master : review obligatoire, CI verte, pas de force-push
- [ ] Les GitHub Actions utilisent OIDC pour les credentials cloud — zéro secret long-lived
- [ ] Les releases sont taggées (semver) avec des release notes générées depuis les conventional commits
- [ ] Les milestones et labels sont utilisés pour grouper le travail par version/thème

## Anti-patterns
### PR monstre sans issue
**Ce qu'on voit :** PR de 2000 lignes, titre "Fix stuff", pas d'issue liée, description vide ou "see commits".
**Pourquoi c'est dangereux :** le reviewer n'a aucun contexte. Pourquoi ce changement ? Quel problème ça résout ? Impossible de reviewer correctement — le reviewer va soit tout accepter sans comprendre, soit bloquer par peur. La PR devient un événement politique au lieu d'un échange technique.
**Faire plutôt :** PR < 400 lignes, liée à une issue qui décrit le problème (PAS la solution), description qui explique le WHY et le HOW. Le diff est petit → la review est rapide → le feedback est court → la vélocité augmente.

### Commit messages vagues
**Ce qu'on voit :** "update", "fix bug", "wip", "changes", "typo". Le git log est un cimetière de messages inutiles.
**Pourquoi c'est dangereux :** `git blame` devient inutile. Le changelog est impossible à générer. Bisecter un bug nécessite de lire chaque diff. Le message de commit est le SEUL artefact qui survit au code (le code change, le message reste). Un mauvais message est une dette permanente.
**Faire plutôt :** Conventional Commits. `feat(auth): add OIDC token refresh` ou `fix(api): handle null user in GET /profile`. Le type (feat/fix/chore) est machine-readable. Le scope (auth/api) localise. Le sujet dit ce qui change. Le corps (optionnel) dit pourquoi.

### Secrets dans les workflows
**Ce qu'on voit :** `env: API_KEY: ${{ secrets.API_KEY }}` puis `curl -H "Authorization: $API_KEY"` — le secret transite par une variable d'environnement accessible à tout le workflow.
**Pourquoi c'est dangereux :** les variables d'environnement sont visibles par tous les steps du job, y compris les actions tierces. Une action compromise lit `process.env` et exfiltre les secrets. Même sans action tierce, un script de build modifié peut les exposer.
**Faire plutôt :** OIDC (OpenID Connect) : le workflow obtient un token temporaire (< 1h) du cloud provider sans stocker de secret. Pour les secrets inévitables : les passer directement au step qui en a besoin, pas en env global. Utiliser `secrets: inherit` avec parcimonie.

### Branch protection absente
**Ce qu'on voit :** pas de ruleset sur main. N'importe qui peut push direct. Pas de review obligatoire. La CI passe mais personne ne la regarde.
**Pourquoi c'est dangereux :** main est la branche de production. Un push direct sans review = un deploy non vérifié. Sans protection, un `git push --force` accidentel peut écraser l'historique. La branch protection est le dernier rempart entre une erreur humaine et la production.
**Faire plutôt :** ruleset sur main : require pull request (min 1 approval), require status checks (CI verte), block force push, require conversation resolution. Pour les hotfixes urgentes : une procédure d'override documentée, pas une désactivation de la règle.

## Patterns
### Conventional Commits
**Quand :** tout commit, sans exception.
**Comment :** `<type>(<scope>): <subject>` — type = feat|fix|chore|docs|test|refactor|ci|perf. Scope = le module/domaine. Subject = impératif présent, < 72 chars. Le corps après une ligne vide, en phrases complètes. Les breaking changes ajoutent `!` après le type ou `BREAKING CHANGE:` dans le footer.

### Issue template
**Quand :** tout repo avec plus d'un contributeur.
**Comment :** `.github/ISSUE_TEMPLATE/bug.yml` avec les champs : version, steps to reproduce, expected vs actual behavior, logs, environment. `.github/ISSUE_TEMPLATE/feature.yml` avec : problème actuel, solution proposée, alternatives considérées. Les templates YAML supportent les dropdowns, textareas, et la validation — bien supérieur au markdown simple.

### PR template
**Quand :** tout repo où le code est revu.
**Comment :** `.github/pull_request_template.md` avec : Summary (1-3 bullet points), Test plan (checklist), Screenshots/recordings (si UI), Breaking changes (oui/non + description). Pas de "What" et "Why" vagues — des sections qui incitent à l'action concrète.

### Branch naming + protection
**Quand :** tout repo en équipe.
**Comment :** `feat/<slug>`, `fix/<slug>`, `chore/<slug>` — slug court en kebab-case depuis le titre de l'issue. Protection sur main : require PR + 1 approval + CI + no force push. Pour les repos solo : au minimum require CI et no force push.

### GitHub Actions OIDC
**Quand :** tout workflow qui déploie sur un cloud.
**Comment :** `permissions: id-token: write` + configure le provider OIDC côté cloud (AWS IAM, GCP WIF). Le workflow reçoit un token temporaire automatiquement. Zéro secret stocké dans GitHub Secrets. Le token expire avant qu'un attaquant puisse l'utiliser même s'il est intercepté.
