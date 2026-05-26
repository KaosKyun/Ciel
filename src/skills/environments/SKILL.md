---
name: environments
description: "Environments — dev/staging/prod separation, GitHub Environments, CI/CD promotion gates, secrets per env, infra isolation. À charger quand on configure des environnements de déploiement."
---

# Environments

**Principe premier :** Un bug en dev coûte 5 minutes. Un bug en staging coûte une réunion. Un bug en production coûte de l'argent, de la réputation, ou pire. La séparation des environnements n'est pas un luxe d'entreprise — c'est le filet de sécurité qui attrape les erreurs avant qu'elles n'atteignent les utilisateurs. Le but n'est pas d'avoir 3 environnements identiques, c'est d'avoir 3 chances de détecter un problème avant qu'il soit critique. Chaque environnement est un filtre : dev filtre les erreurs de code, staging filtre les erreurs d'intégration, production est le dernier rempart.

## Checklist
- [ ] Au moins 2 environnements : un pour tester (staging/preview) et un pour la production
- [ ] Les environnements sont isolés — comptes/projets séparés (Vercel, Render, AWS), pas juste des dossiers ou des branches
- [ ] Les secrets sont par environnement — `DB_URL` en staging ≠ `DB_URL` en production, jamais partagés
- [ ] Le déploiement en production a une gate d'approbation humaine (pas de push-to-deploy direct sur prod)
- [ ] Staging est le jumeau de production — même stack, même config, juste les données et l'échelle qui diffèrent
- [ ] La promotion se fait dans un seul sens : dev → staging → prod. Jamais l'inverse (pas de "je fix en prod et je backport")
- [ ] Les logs et métriques sont centralisés par environnement avec un tag `env:` (staging/production)
- [ ] L'accès à la production est restreint — moins de monde peut déployer/modifier la production que le staging

## Anti-patterns
### Un seul environnement pour tout
**Ce qu'on voit :** le projet a un seul déploiement. Les features sont testées "en local" puis mergées sur main et déployées. Pas de staging.
**Pourquoi c'est dangereux :** chaque merge est un pari. "Ça marchait sur ma machine" n'est pas une vérification. Sans staging, la première fois que le code rencontre une vraie DB, un vrai réseau, une vraie config — c'est en production. Les bugs d'intégration sont découverts par les utilisateurs.
**Faire plutôt :** minimum 2 environnements. Un staging/preview qui est déployé automatiquement à chaque PR. La production qui est déployée après merge + validation sur staging. Pour un projet solo sans budget : une preview branch (Vercel/Render/Netlify la donnent gratuitement) + la production.

### Secrets partagés entre environnements
**Ce qu'on voit :** `.env` avec `DATABASE_URL=postgres://...` — le même fichier copié en staging et en production. Ou pire : `.env` commité.
**Pourquoi c'est dangereux :** un secret de staging qui fuit donne accès à la DB de staging (pas grave). Un secret de production qui fuit donne accès à la DB de production (catastrophique). Si c'est le même secret, le staging devient un vecteur d'attaque vers la production. Le staging est moins sécurisé par nature (plus de gens y accèdent, logs plus verbeux, debugging actif).
**Faire plutôt :** secrets distincts par environnement. GitHub Environments → `DB_URL` configuré séparément pour `staging` et `production`. En local : `.env` dans `.gitignore`, jamais commité. Les clés API de production sont générées séparément, avec des permissions plus restrictives.

### Promotion inversée (prod → staging)
**Ce qu'on voit :** un bug en production, on fix directement sur le serveur, et "on backportera plus tard". Le code de production diverge du code source. Personne ne sait exactement ce qui tourne.
**Pourquoi c'est dangereux :** le git n'est plus la source de vérité. Le prochain déploiement écrase le fix. Impossible de reproduire l'état de production en local. L'écart entre le code source et la production s'accumule jusqu'à ce qu'un déploiement casse tout.
**Faire plutôt :** le flux est toujours dev → staging → prod. Si un fix urgent est nécessaire : créer une branche `fix/...`, déployer en staging, valider, merger, déployer en production. Le cycle normal, juste accéléré. La production est toujours le reflet exact de main.

### Staging ≠ production
**Ce qu'on voit :** staging tourne sur SQLite, production sur PostgreSQL. Staging a 10 rows, production en a 10M. Staging n'a pas de Redis, production en a un cluster. "C'est plus simple pour tester".
**Pourquoi c'est dangereux :** les bugs les plus dangereux sont ceux qui n'apparaissent QUE dans l'environnement de production. Une requête qui scanne 10 rows en 1ms peut scanner 10M rows en 30 secondes. Un index qui existe en production mais pas en staging. Un timeout réseau qui n'arrive jamais en local. Staging doit être le jumeau de production — différences = angles morts.
**Faire plutôt :** même stack, même versions, même configuration (hors secrets et scale). La DB de staging peut être plus petite mais doit utiliser le même moteur. Idéalement : staging est une copie anonymisée de la DB de production, rafraîchie régulièrement. Le coût : un deuxième déploiement. Le bénéfice : les bugs sont découverts avant les utilisateurs.

### Déploiement production sans gate humaine
**Ce qu'on voit :** push sur main → CI passe → déploiement automatique en production. Personne n'a validé. "La CI est verte, c'est bon".
**Pourquoi c'est dangereux :** la CI ne teste pas tout. Elle ne teste pas l'UX, la performance perçue, l'impact sur les utilisateurs. Sans gate humaine, un vendredi 17h un dev merge une PR "refactor rapide" et part en weekend — le déploiement automatique casse la production, personne ne voit l'alerte.
**Faire plutôt :** déploiement automatique en staging. Déploiement en production avec une gate d'approbation. GitHub Environments → `production` → Required reviewers: 1. La gate peut être un clic dans l'UI GitHub ("Review deployments"), pas un processus lourd. Pour un projet solo : au minimum, le déploiement en production est déclenché manuellement ou après un délai (30 min après le merge, le temps de vérifier staging).

## Patterns
### GitHub Environments (sans org)
**Quand :** tout projet GitHub avec au moins un déploiement.
**Comment :** Settings → Environments → `staging` et `production`. Chaque environnement a ses propres secrets (`DB_URL`, `API_KEY`), ses propres rules (required reviewers, wait timer, deployment branches), et ses propres variables d'environnement. Les workflows référencent l'environnement : `environment: staging` dans le job. GitHub suit l'historique des déploiements par environnement. Fonctionne sur les repos personnels — pas besoin d'une organisation.

### Promotion pipeline
**Quand :** tout projet avec staging + production.
**Comment :** 3 jobs dans le workflow CI/CD :
1. `test` — lint + tests unitaires + intégration (toutes les branches)
2. `deploy-staging` — déploie sur staging après merge sur main, automatique
3. `deploy-production` — déploie sur production, manuel ou après approbation, avec `environment: production`

Le job production ne peut pas s'exécuter si le job staging a échoué. La promotion est linéaire et vérifiable.

### Infrastructure isolation sans budget
**Quand :** projet solo ou petite équipe, pas de budget pour des comptes cloud séparés.
**Comment :** utiliser les fonctionnalités gratuites des plateformes. Vercel : preview deployments (par branche) + production. Render : PR previews + production. Netlify : deploy previews + production. Pour les DB : une DB de dev locale (Docker), une DB de staging (instance gratuite ou partagée), une DB de production (instance dédiée). Les clés API ont des permissions restreintes : la clé de staging ne peut pas envoyer d'emails réels, la clé de production oui.

### Secrets rotation par environnement
**Quand :** tout projet avec des secrets.
**Comment :** chaque environnement a ses propres credentials, générés indépendamment. Si un secret de staging fuit : rotation sur staging uniquement, production inchangée. Les secrets ne sont jamais transmis entre environnements — pas de "copier-coller le .env de staging vers production". Pour les clés API tierces (Stripe, SendGrid) : utiliser leurs clés de test en staging/dev, leurs clés de production uniquement en production.
