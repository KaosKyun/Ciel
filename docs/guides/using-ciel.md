# Guide d'utilisation de Ciel

> **Comment utiliser Ciel au quotidien pour le développement assisté.**

---

## Principes d'utilisation

Ciel n'est pas un outil qu'on "active" — c'est un workflow qui s'exécute à **chaque tâche**. Vous n'avez pas besoin de lancer de commande spéciale : envoyez simplement votre demande de la même manière que d'habitude.

Ciel classifie automatiquement la profondeur de votre demande et adapte son pipeline.

---

## Écrire une bonne demande

Pour que Ciel soit efficace, formulez votre demande clairement :

### ✅ Bonnes pratiques

```
Ajoute un endpoint GET /api/health qui retourne { status: "ok" }
avec:
- Route dans routes/health.js
- Test dans tests/health.test.js
- Logger des accès
```

### ❌ À éviter

```
fais un truc pour la santé du système
```

Plus votre demande est précise, plus la classification et le dispatch sont efficaces.

---

## Classification de profondeur

Ciel classifie votre demande automatiquement. Voici comment influencer cette classification :

### Pour déclencher une classification Critical

Incluez des mots-clés explicites :

```
Corrige la faille de sécurité dans le module d'authentification
```

→ Ciel déclenchera : STRIDE + security-regression-check + critic obligatoire

### Pour une classification Standard

```
Ajoute un composant React UserProfile avec tests
```

→ Ciel dispatchera explorer + appliquera le pipeline complet

### Pour une classification Trivial

```
Corrige la typo "teh" → "the" dans README.md
```

→ Ciel appliquera le changement inline, sans dispatch

---

## Utiliser les subagents

Vous pouvez dispatcher manuellement des subagents si vous avez un besoin spécifique :

### Chercher une documentation

```
@ciel-researcher trouve la documentation officielle de React 19 sur use()
```

### Explorer le codebase

```
@ciel-explorer analyse le pattern de validation dans services/validator.js
```

### Demander une relecture

```
@ciel-critic relis le fichier routes/auth.js
```

### Améliorer Ciel

```
/ciel-improve
```

---

## Cas d'usage courants

### 1. Déboguer une erreur

```
Pourquoi le endpoint POST /api/login retourne 500 depuis le dernier déploiement ?
```

Ce que Ciel fait :
1. Classification : Standard (debug)
2. Intent routing : `@ciel-critic MODE=RCA`
3. 3 hypothèses + fault type classification
4. Suggestion corrective

### 2. Ajouter une feature

```
Ajoute un système de cache Redis pour les sessions utilisateur
```

Ce que Ciel fait :
1. Classification : Critical (session + auth)
2. Dispatch parallèle : researcher + explorer
3. STRIDE analysis
4. Test-first + quality gates
5. RELIRE obligatoire

### 3. Refactorer du code

```
Refactore le service UserService en extrayant la validation email
dans un service ValidatorService dédié
```

Ce que Ciel fait :
1. Classification : Standard (refactor)
2. Explorer : pattern-fitness-check
3. Évaluateur : sizing + pre-mortem
4. FAIRE : strangler fig pattern

### 4. Review open PRs

```
Review les PRs ouvertes et fixe la CI bloquée
```

Ce que Ciel fait :
1. Detection : PR review + CI/CD
2. Floor rule : au moins Standard
3. Critic MODE=CRITIQUER sur les PRs
4. CI watcher sur les workflows

---

## Utiliser les commandes slash

| Commande | Usage |
|----------|-------|
| `/ciel <task>` | Lance une tâche avec le pipeline complet |
| `/ciel-check` | Vérifie l'état de Ciel |
| `/ciel-init` | Répare le câblage Ciel |
| `/ciel-update` | Met à jour Ciel |
| `/ciel-status` | Affiche l'état de la session |
| `/ciel-improve` | Analyse et propose des améliorations |
| `/ciel-eval <skill>` | Évalue un skill |
| `/ciel-create-skill <nom> <but>` | Crée un nouveau skill |
| `/ciel-refresh` | Vérifie la fraîcheur des skills |
| `/ciel-recommend` | Découvre des plugins communautaires |
| `/ciel-audit` | Post-mortem de session |

---

## Workflow quotidien typique

### Matin : Review des PRs

```
/ciel review les PRs et vérifie la CI
```

### Milieu de journée : Développement

```
/ciel ajoute un composant UserAvatar avec lazy loading et tests
```

### Fin de journée : Ménage

```
/ciel nettoie les branches mergées
```

---

## Voir aussi

- [Guide : Créer un skill](creating-skill.md)
- [Guide : Contribuer](contributing.md)
- [Tutoriel : Quick Start](../tutorials/quick-start.md)
- [Tutoriel : Première tâche](../tutorials/first-task.md)
