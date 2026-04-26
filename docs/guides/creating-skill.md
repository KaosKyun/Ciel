# Guide : Créer un skill

> **Comment créer une nouvelle compétence pour Ciel en suivant le Skills-first design.**

---

## Introduction

Les skills sont l'unité fondamentale de connaissance dans Ciel. Créer un skill, c'est encapsuler un pattern de résolution de problème dans un format réutilisable.

Chaque skill doit répondre à une question précise :

> "Quel problème ce skill résout-il que les autres skills ne résolvent pas ?"

---

## Structure d'un skill

Chaque skill est un dossier dans `skills/` contenant :

```
skills/<nom-du-skill>/
├── SKILL.md          # Définition principale (obligatoire)
├── reference.md      # Référence détaillée (recommandé)
└── scripts/          # Scripts associés (optionnel)
```

### SKILL.md

Le fichier principal. Format :

```markdown
---
name: <nom-kebab-case>
description: <1-2 phrases, ce que fait ce skill, quand l'utiliser>
context: fork | inline
agent: ciel-critic | ciel-explorer | ciel-researcher | ciel-improver
---

# Titre du skill

## Introduction
<1-2 paragraphes : contexte, philosophie, quand utiliser>

## Quand l'utiliser (WHEN-triggered)
<Conditions précises qui déclenchent ce skill>

## Comment l'utiliser
<Étapes concrètes avec exemples de code>
```

---

## Méthode 1 : Via `/ciel-create-skill`

La manière la plus simple :

```
/ciel-create-skill email-validator "Valide les emails côté serveur avec regex + whitelist domaines"
```

Ciel génère un squelette SKILL.md pour vous, que vous n'avez qu'à remplir.

---

## Méthode 2 : Manuellement

### Étape 1 : Créer le dossier

```bash
mkdir -p skills/<nom-kebab-case>
```

### Étape 2 : Écrire SKILL.md

```markdown
---
name: email-validator
description: >
  Validation d'email côté serveur : regex RFC 5322 simplifié + whitelist
  de domaines. Utiliser quand un endpoint accepting un email doit le valider.
context: inline
---

# Email Validator

Valide les emails côté serveur avant traitement.

## Quand l'utiliser
- Endpoint d'inscription (`/api/register`)
- Modification d'email (`/api/user/email`)
- Import de contacts

## Pattern

```javascript
function validateEmail(email) {
  const SIMPLE_EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  const ACCEPTED_DOMAINS = ['example.com']

  if (!email || !SIMPLE_EMAIL_RE.test(email)) {
    return { valid: false, error: 'Email format invalide' }
  }
  const domain = email.split('@')[1].toLowerCase()
  if (!ACCEPTED_DOMAINS.includes(domain)) {
    return { valid: false, error: 'Domaine non accepté' }
  }
  return { valid: true }
}
```

## Anti-patterns à éviter
- Regex RFC 5322 complète (400+ caractères, risque ReDoS)
- Validation côté client uniquement
- Lookup MX réel en temps réel (timeout)

## Vérification
1. Le test existe avant le code
2. Cas valide + invalide + domaine refusé couverts
3. Pas d'email loggé en clair
```

### Étape 3 : Ajouter reference.md (recommandé)

```markdown
# Email Validator — Référence

## RFC 5322
- https://datatracker.ietf.org/doc/html/rfc5322

## Regex simplifiée
Source : https://emailregex.com/ (version simplifiée)
```

### Étape 4 : Ajouter des tests (optionnel)

Créez `skills/email-validator/scripts/test.sh` pour valider le skill.

---

## Règles de design

### 1. Un skill = un problème

```markdown
✅ skills/email-validator        — Valide les emails
❌ skills/validation-utils       — Fait trop de choses
```

### 2. Frontmatter YAML complet

Champs obligatoires :

```yaml
name: mon-skill           # kebab-case
description: "..."        # 1-2 phrases
context: fork | inline    # inline = déterministe, fork = a besoin d'isolation
```

### 3. ≤ 500 lignes

Un skill ne doit pas dépasser 500 lignes. Au-delà, il fait trop de choses.

### 4. 2-3 exemples concrets

Chaque skill doit montrer :
- Le pattern idiomatique
- 1-2 variations
- L'anti-pattern à éviter

### 5. Progressive disclosure

- Les 10 premières lignes doivent suffire pour l'utiliser
- Les détails viennent après

### 6. Verification scripts

Pour les vérifications critiques, incluez un script bash :

```bash
# skills/mon-skill/scripts/verify.sh
# Vérifie que le pattern est bien appliqué
```

---

## Invocation : inline vs fork

### Inline (contexte principal)

Utilisez le Skill tool :

```
Skill(email-validator) → applique inline
```

**Quand utiliser** : skills déterministes, légers, sans besoin d'isolation :
- `quoi-framer`, `depth-classifier`, `faire-gatekeeper`

### Fork (contexte isolé)

Utilisez le Task tool :

```
Task(subagent_type="ciel-critic", prompt="MODE=RELIRE CHANGED_FILES=...")
```

**Quand utiliser** : skills qui ont besoin d'un regard neuf :
- `relire-critic`, `debug-reasoning-rca`, `research-web-sources`

---

## Validation du skill

Avant de soumettre, vérifiez :

```bash
# 1. Frontmatter YAML valide
head -5 skills/mon-skill/SKILL.md | grep -q "^---$"

# 2. ≤ 500 lignes
wc -l < skills/mon-skill/SKILL.md
# → ≤ 500

# 3. Exemples présents
grep -c "```" skills/mon-skill/SKILL.md
# → ≥ 4 (ouverture + fermeture pour 2 exemples)

# 4. reference.md optionnel mais recommendé
test -f skills/mon-skill/reference.md && echo "✓" || echo "optionnel"
```

La CI valide automatiquement avec `skill-integrity.yml` :
- `validate-skill-yaml` — frontmatter présent
- `validate-skill-size` — ≤500 lignes
- `validate-skill-urls` — URLs valides
- `validate-skill-examples` — ≥50% des skills ont des exemples

---

## Voir aussi

- [Bibliothèque de skills](../explanation/skills.md) — Organisation des compétences
- [Référence : Skills list](../reference/skills.md) — Inventaire complet
- [Guide : Contribuer](contributing.md)
- [Skills-first Design Auditor](../../skills/meta/skills-first-design-auditor/SKILL.md)
