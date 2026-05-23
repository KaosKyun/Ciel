---
name: cicd-pipeline
description: "CI/CD Pipeline — GitHub Actions/GitLab CI, matrix builds, caching, OIDC, SLSA, ephemeral runners. A charger quand on configure des pipelines de build/deploy."
---

# CI/CD Pipeline

## Checklist
- [ ] Chaque etape du pipeline est rapide (< 5 minutes par etape)
- [ ] Le cache est configure (node_modules, pip, etc. — pas de telechargement a chaque build)
- [ ] Les secrets sont injectes via OIDC ou secrets stores (pas de tokens long-lived dans les variables)
- [ ] Les runners sont ephemeres (pas de runners persistants partages)
- [ ] Le pipeline est versionne avec le code (dans le meme repo)
- [ ] Les tests sont parallellises (matrix strategy, test splitting)
- [ ] Une etape de securite est presente (lint, SAST, dependency scan)
- [ ] Le build produit un artefact immutable (Docker image taggee, version pin)

## Anti-patterns
### Pipeline lent
**Ce qu'on voit :** `npm install`, `npm run build`, `npm test` en sequentiel. 15 minutes par build.
**Pourquoi c'est dangereux :** feedback trop lent. Les devs ne lancent pas les tests localement non plus. Le pipeline devient un bottleneck.
**Faire plutot :** paralleliser les etapes independantes. Cacher les dependances. Test splitting. CI < 5 min ou c'est trop long.

### Secrets dans le pipeline
**Ce qu'on voit :** AWS_ACCESS_KEY_ID et SECRET_ACCESS_KEY stockes dans les secrets GitHub. Rotation jamais faite.
**Pourquoi c'est dangereux :** si le runner est compromis, les secrets fuient. Si une PR malveillante ajoute `echo $AWS_SECRET` dans le log, le secret est vole.
**Faire plutot :** OIDC (OpenID Connect). GitHub Actions s'authentifie directement aupres d'AWS/GCP sans secret long-lived. Token temporaire (< 1h).

### Runners persistants
**Ce qu'on voit :** un serveur avec un runner GitLab qui tourne 24/7, avec acces a tout le reseau interne.
**Pourquoi c'est dangereux :** une PR peut executer du code arbitraire sur ce runner. Le runner a acces au VPC, aux secrets, aux autres jobs.
**Faire plutot :** runners ephemeres (GitHub Actions hosted, ou auto-scaling avec ephemeral mode). Chaque build a son environnement isole. Rien ne persiste entre les builds.

## Patterns
### OIDC
**Quand :** tout pipeline qui doit acceder a un cloud provider.
**Comment :** GitHub Actions OIDC -> AWS IAM role. Le workflow demande un token OIDC -> AWS echange contre des credentials temporaires. Pas de secret a stocker ni a faire tourner.

### Matrix build
**Quand :** plusieurs versions de langage, OS, ou configuration a tester.
**Comment :** `matrix: { node: [18, 20, 22], os: [ubuntu, macos] }`. 6 builds en parallele. Chacun independant.

### Build cache
**Quand :** les dependances sont lentes a installer.
**Comment :** `actions/cache` avec key basee sur le lockfile hash. Cache restore au debut, save a la fin. Evite le telechargement des dependances a chaque build.
