# Ciel Overlay — [Nom du projet]

> Ce fichier est l'overlay projet pour le plugin Ciel.
> Il contient tout ce qui est spécifique à CE projet et override les defaults de Ciel.
> Placer à la racine du projet ou dans `.claude/` sous le nom `ciel-overlay.md`.

## Stack

- Frontend: [lib + version — ex: React 19.0.0]
- Backend: [framework + version — ex: Ktor 3.0.0 / Kotlin 2.0.21]
- DB: [type + version — ex: PostgreSQL 16]
- Cache: [ex: Redis 7.2]
- Test: [framework — ex: Vitest 3.x + Playwright]
- Build: [ex: pnpm 9.15 / Gradle 8.5]

## Versions + URLs docs (pour RECHERCHE)

| Lib | Version installée | URL docs officielle |
|-----|-------------------|--------------------|
| [lib] | [version exacte] | [URL] |

## Règles projet-spécifiques

[Ce qui override ou complète les defaults Ciel — patterns du projet, conventions, contraintes]

## CI / Vérification

- CI système: [ex: GitHub Actions]
- Runners: [ex: self-hosted, ubuntu-latest]
- Commande test locale: [ex: pnpm test:unit]
- Staging URL: [ex: https://staging.example.com]
- Commande staging deploy: [ex: git push origin branch]
- Délai deploy staging: [ex: ~30-45s]

## Fichiers critiques (patterns pour hooks)

Fichiers/dossiers à traiter comme Critical dans les hooks :
- [ex: src/auth/]
- [ex: *Routes.kt]
- [ex: *Service.kt]

## Comptes de test

- [ex: admin@example.com — rôle admin]
- [ex: user@example.com — rôle user standard]

## Leçons projet

[Erreurs passées spécifiques à ce projet]
[Format: [date] MISTAKE: [ce qui s'est passé] → RULE: [comment éviter]]
