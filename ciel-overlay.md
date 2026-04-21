# Ciel Overlay — [Nom du projet]

> Ce fichier est l'overlay projet pour le plugin Ciel.
> Il contient tout ce qui est spécifique à CE projet et override les defaults de Ciel.
> À créer à la racine du projet et compléter les sections ci-dessous.

---

## Stack exacte

- **Frontend:** [ex: React 19.0.0 / Vue 3.5 / Svelte 5]
- **Backend:** [ex: Ktor 3.0.0 / FastAPI 0.115 / Express 5]
- **Langage:** [ex: Kotlin 2.1.0 / TypeScript 5.5 / Python 3.12]
- **DB:** [ex: PostgreSQL 16 / SQLite 3.45 / MongoDB 7]
- **Cache:** [ex: Redis 7.2 / in-memory]
- **Test:** [ex: Vitest 3.x + Playwright / pytest 8 / JUnit 5]
- **Build:** [ex: pnpm 9.15 / Gradle 8.5 / npm 10]

---

## URLs de documentation

| Lib | Version installée | URL docs officielle |
|-----|-------------------|--------------------|
| [lib] | [version exacte] | [URL] |
| React | 19.0.0 | https://react.dev/reference/react |
| [ajouter vos libs ici] | | |

---

## Fichiers critiques (patterns pour hooks)

Fichiers/dossiers à traiter comme **Critical** dans les hooks :

- `[ex: src/auth/]` — Authentification
- `[ex: src/db/migration/]` — Schéma DB
- `[ex: *Service.kt]` — Business logic
- `[ex: *Routes.ts]` — Route handlers
- `[ex: src/security/]` — Sécurité

---

## Commandes CI / Vérification

- **CI système:** [ex: GitHub Actions / GitLab CI]
- **Runners:** [ex: ubuntu-latest / self-hosted]
- **Build local:** `[ex: pnpm build / ./gradlew build]`
- **Test local:** `[ex: pnpm test:unit / ./gradlew test]`
- **Lint:** `[ex: pnpm lint / ./gradlew detekt]`
- **Staging URL:** `[ex: https://staging.example.com]`
- **Deploy staging:** `[ex: git push origin main]`
- **Délai deploy:** `[ex: ~30-45s]`

---

## Comptes de test

- `[ex: admin@example.com]` — rôle: admin
- `[ex: user@example.com]` — rôle: user standard

## Secrets (sensitive: true)

> Les sections marquées `sensitive: true` sont automatiquement redactées par le plugin avant injection dans le prompt système.

- `[ex: Token de test: $TEST_TOKEN]`
- `[ex: API_KEY: sk-xxx]`
- `[ex: DB_PASSWORD: xxx]`

---

## Leçons projet

> Format: `[date] MISTAKE: [ce qui s'est passé] → RULE: [comment éviter]`

- `[2025-01] MISTAKE: forgot transaction block → RULE: Toujours envelopper les queries DB dans transaction { }`
- `[ajouter vos leçons ici]`

---

## Règles projet-spécifiques

> Ce qui override ou complète les defaults Ciel — patterns du projet, conventions, contraintes

- `[ex: Pas de business logic dans les controllers]`
- `[ex: Tests unitaires obligatoires pour tout nouveau service]`
- `[ex: Review mandatory pour tout fichier auth/]`
