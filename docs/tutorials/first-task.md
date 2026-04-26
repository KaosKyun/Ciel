# Tutoriel : Première tâche complète

> **Objectif** : Traverser l'intégralité d'un pipeline Ciel — de la classification à la preuve.
>
> **Niveau** : Intermédiaire — avoir fait le [Quick Start](quick-start.md) d'abord.

---

## Le scénario

Vous devez **ajouter une validation d'email** à un endpoint d'inscription existant.

```
Ajoute une validation d'email côté serveur sur /api/register
- Format email valide (regex RFC 5322 simplifié)
- Vérification de domaine (MX lookup simulé)
- Message d'erreur: "Email format invalide" ou "Domaine non accepté"
```

---

## Étape 1 : Ciel classifie la profondeur

Ciel analyse votre prompt :

```
[CIEL] Depth: Critical (auth/security keyword detected)
```

→ **Critical** car la tâche touche à un endpoint d'authentification (validation d'email sur `/api/register`).

**Pipeline complet déclenché :**
- Researcher + Explorer **en parallèle**
- STRIDE analysis + security-regression-check
- Critic **obligatoire** après écriture

---

## Étape 2 : QUOI — Cadrage de l'objectif

Ciel répond avec un plan structuré :

```
## PLAN

**Goal:** Ajouter une validation d'email côté serveur sur POST /api/register
**NOT-X:** Ne PAS modifier la logique d'inscription existante, ne PAS envoyer d'email de confirmation
**Definition of Done:**
  - Route PUT /api/register avec champ email validé
  - Regex email valide
  - Vérification domaine contre liste d'acceptation
  - Tests passent (≥ 2 cas: valide, invalide, domaine refusé)
  - Aucune régression sur les routes existantes

**Depth:** Critical

**Subagents dispatés:**
  - @ciel-researcher: Oui — RFC 5322 regex, patterns validation email
  - @ciel-explorer: Oui — 3+ fichiers impactés
```

---

## Étape 3 : AVEC QUOI — Versions installées

Ciel vérifie les versions réelles :

```bash
# grep "express" package.json
> "express": "^4.18.0"

# grep "joi" package.json (ou autre lib de validation)
```

Il note le framework et la lib de validation disponibles.

---

## Étape 4 : RECHERCHE — Documentation externe

`@ciel-researcher` est dispatché en tâche forkée :

1. Cherche la doc officielle d'Express pour les route validators
2. Vérifie les patterns de validation email (regex RFC 5322)
3. Cherche les anti-patterns (regex trop complexes, ReDoS)
4. Synthétise les résultats

**Résultat de la recherche :**

```
## FINDINGS
- Express route validation: middleware pattern, app.post('/api/register', validate, handler)
- RFC 5322 simplified: /^[^\s@]+@[^\s@]+\.[^\s@]+$/
- Anti-pattern: regex trop stricte rejetée (rejette les +, les . valides)

## ANTI-PATTERNS À ÉVITER
- Ne PAS utiliser une regex RFC 5322 complète (400+ caractères, ReDoS)
- Ne PAS valider côté client seulement

## API SURFACE (vérifiée)
- express.Router().post() à express@4.18
- joi.string().email() pour validation si joi est dispo
```

---

## Étape 5 : SÉCURITÉ (Critical uniquement)

Ciel applique **STRIDE analysis** + **security-regression-check** :

```
## STRIDE Analysis
| Catégorie | Risque | Mitigation |
|-----------|--------|------------|
| Spoofing | Email invalide → usurpation | Validation format + domaine |
| Tampering | Injection dans le champ email | Échappement, validation |
| Repudiation | Logs d'inscription | Ajouter correlation ID |
| Info Disclosure | Email valide leaké | Pas de log d'email complet |
| DoS | Regex ReDoS | Timeout + regex simple |
| Elevation | SQL injection via email | Requête paramétrée (déjà en place) |
```

---

## Étape 6 : CODEBASE — Exploration du code

`@ciel-explorer` explore le code existant :

```
## PATTERNS TROUVÉS
- APPLY: routes/auth.js:42 — pattern middleware validation existant
- ADAPT: services/validator.js:15 — fonction validateEmail à enrichir

## MINI REPO-MAP
Impactés: routes/auth.js, services/validator.js, tests/auth.test.js
Hub check: routes/auth.js (hub à 12 dépendants — attention)

## FLUX
POST /api/register
  → routes/auth.js:register
  → services/validator.js:validateEmail (NOUVEAU)
  → services/auth.js:createUser
  → DB: users table
```

---

## Étape 7 : ÉVALUER — Sizing et alternatives

Ciel évalue la difficulté et explore les alternatives :

```
## SIZING
- 3 fichiers modifiés
- ~30 lignes de code
- 2 cas de test

## PRE-MORTEM
1. Regex trop complexe → rejet d'emails valides (ex: "user+tag@domain.com")
2. Blocage si domaine MX lookup réel → timeout

## ALTERNATIVES
1. ✅ joi.string().email() (si dispo)
2. regex simple + whitelist domaines
3. ❌ lib externe email-validator (dépendance inutile)

## COUNTERFACTUAL
Si on ne fait rien: pas de validation → emails invalides en base
```

---

## Étape 8 : FAIRE — Implémentation

### 8.1 — Test-first (RED)

Avant d'écrire le code, Ciel écrit (ou vérifie) le test :

```javascript
// tests/auth.test.js — NOUVEAU
describe('POST /api/register - validation email', () => {
  it('accepte un email valide', async () => {
    const res = await request(app)
      .post('/api/register')
      .send({ email: 'user@example.com', password: 'Pass123!' })
    expect(res.status).toBe(201)
  })

  it('rejette un email invalide', async () => {
    const res = await request(app)
      .post('/api/register')
      .send({ email: 'invalid', password: 'Pass123!' })
    expect(res.status).toBe(400)
    expect(res.body.error).toContain('Email')
  })
})
```

Les tests sont **Rouges** (RED) — ils échouent car la validation n'existe pas encore.

### 8.2 — Implémentation

```javascript
// services/validator.js
function validateEmail(email) {
  const SIMPLE_EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  const ACCEPTED_DOMAINS = ['example.com', 'company.com']

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

Les 5 **quality gates** sont vérifiés :
1. ✅ Test-first (RED) : écrit avant
2. ✅ Alternatives : regex simple > lib externe
3. ✅ Idiomatique : middleware Express standard
4. ✅ Qualité : < 15 complexity, < 4 nesting
5. ✅ Removal : aucun code supprimé

---

## Étape 9 : RELIRE — Relecture critique

`@ciel-critic MODE=RELIRE` est dispatché en contexte forké :

```
## RISQUE 1 (Fonctionnel)
La regex rejette les emails avec "+" (ex: "user+tag@domain.com").
→ ACCEPT: le scope exclut cette feature, documenté comme limitation connue.

## RISQUE 2 (API)
Le champ "email" est sensible — le logger pourrait exposer l'email utilisateur.
→ FIX: Ajouté un filtre dans le logger pour masquer les emails.

## RISQUE 3 (Données)
La whitelist de domaines est codée en dur — pas de mechanisme de mise à jour.
→ DEFER: Extraction vers config dans une PR séparée.
```

---

## Étape 10 : PROUVER — Preuve de validation

### AVANT/APRÈS

```
AVANT:
  POST /api/register → 201 même avec email invalide
APRÈS:
  POST /api/register email="user@example.com" → 201
  POST /api/register email="invalid" → 400 "Email format invalide"
  POST /api/register email="user@evil.com" → 400 "Domaine non accepté"
```

### CI gate

Les tests passent :

```bash
✓ POST /api/register - validation email
  ✓ accepte un email valide (45ms)
  ✓ rejette un email invalide (32ms)
  ✓ rejette un domaine non accepté (38ms)
3 passing (115ms)
```

---

## Résumé du pipeline vue d'ensemble

```
Votre prompt
    │
    ├─ 1. Depth: Critical (auth/security)
    │
    ├─ 2. QUOI — Cadrage
    ├─ 3. AVEC QUOI — Versions
    ├─ 4. RECHERCHE ← @ciel-researcher  (fork parallèle)
    ├─ 5. SÉCURITÉ ← STRIDE
    ├─ 6. CODEBASE ← @ciel-explorer      (fork parallèle)
    ├─ 7. ÉVALUER — Sizing, alternatives
    ├─ 8. FAIRE — Test-first (RED) → implémentation
    ├─ 9. RELIRE ← @ciel-critic          (fork)
    └─ 10. PROUVER — AVANT/APRÈS + CI
```

---

## À retenir

| Concept | Explication |
|---------|-------------|
| **Depth** | Ciel adapte son pipeline à la complexité |
| **Fork isolation** | Les subagents voient le code sans vos biais |
| **Test-first (RED)** | Jamais de code source sans test d'abord |
| **Quality gates** | 5 vérifications avant chaque écriture |
| **META-CRITIQUER** | 30s de réflexion après chaque tâche |

**Prochaine étape** : Explorez les **[Guides pratiques](../guides/using-ciel.md)** pour des cas d'usage avancés.
