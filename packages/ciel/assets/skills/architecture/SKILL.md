---
name: architecture
description: "Architecture Logicielle — monolithe modulaire, microservices, ports/adapters, architecture decisions (ADR), Strangler Fig. À charger quand on définit la structure d'un projet ou qu'on refactorise."
---

# Architecture Logicielle

**Principe premier :** L'architecture n'est pas une collection de patterns — c'est la gestion explicite des dépendances. La qualité d'une architecture se mesure à une chose : combien de modules dois-je toucher pour faire un changement métier ? Si la réponse est > 3, l'architecture est cassée, peu importe le pattern utilisé. Le bon pattern dépend du contexte (taille d'équipe, fréquence de changement, exigences de scale), pas de la mode.

## Checklist
- [ ] Le choix d'architecture est justifié par le contexte et documenté (ADR)
- [ ] Les dépendances pointent vers le domaine — jamais l'inverse (Domain <> Infrastructure)
- [ ] Les modules sont nommés par capacité métier (billing, shipping), pas par couche technique (controllers, services, utils)
- [ ] Chaque module a une interface explicite (contrat) — pas de couplage par import direct interne
- [ ] Démarrer simple (monolithe modulaire) — extraire en service UNIQUEMENT quand le besoin est prouvé
- [ ] Le diagramme de contexte (C4 niveau 1-2) existe et est visible des nouveaux

## Anti-patterns
### Microservices comme défaut
**Ce qu'on voit :** 12 services, 12 repos, 12 pipelines de CI — pour 3 développeurs et 100 utilisateurs. Un changement simple touche 4 repos.
**Pourquoi c'est dangereux :** les microservices ne réduisent pas la complexité — ils la déplacent du code vers le réseau. Chaque service ajoute latence, serialisation, gestion d'erreur réseau, déploiement coordonné. Le seuil n'est pas technologique, il est organisationnel : une équipe par service.
**Faire plutôt :** monolithe modulaire. Domaines séparés en modules, interfaces explicites, même codebase. Un commit = un changement. Extraire un service quand l'équipe grandit ou qu'un module a besoin de scale indépendant.

### Architecture en couches vidée
**Ce qu'on voit :** Controller → Service → Repository. Le Service fait 3 lignes : `return this.repository.findById(id)`. Le domaine n'existe pas — c'est un tuyau HTTP→DB.
**Pourquoi c'est dangereux :** les règles métier sont éparpillées dans les controllers, les validateurs, les middlewares. Changer une règle métier oblige à traquer la logique dans 6 fichiers. Le code ne protège pas les invariants.
**Faire plutôt :** le domaine contient les règles. `order.approve()` vérifie le statut, le crédit, la disponibilité. Le service orchestre, le repository persiste, le controller traduit HTTP. Chaque couche a une VRAIE responsabilité.

### Architecture décidée puis figée
**Ce qu'on voit :** un diagramme d'archi dessiné il y a 3 ans sur un tableau blanc. L'archi réelle a divergé, personne ne l'a documenté.
**Pourquoi c'est dangereux :** l'architecture documentée est un mensonge. Les nouveaux développeurs se fient au diagramme et prennent des décisions sur une base fausse. La dérive architecturale s'accélère.
**Faire plutôt :** ADR (Architecture Decision Records) pour les décisions importantes. Diagrammes régénérés (C4 via structurizr ou PlantUML). L'architecture est vivante — elle change avec le système.

## Patterns
### Ports & Adapters (Hexagonale)
**Quand :** le domaine métier doit survivre aux changements d'infrastructure.
**Comment :** le domaine définit des interfaces (ports : `OrderRepository`, `PaymentGateway`). Les adapters implémentent ces interfaces (PostgresAdapter, StripeAdapter). Le domaine ne dépend de rien d'externe — pas de `import { Prisma }`, pas de `import { Stripe }`.

### Monolithe modulaire
**Quand :** début de projet, équipe < 20, pas de besoin de scale indépendant.
**Comment :** modules par domaine (billing/, shipping/, auth/). Chaque module a son propre schéma DB logique. Communication inter-module par interfaces explicites ou événements. Si un module devient trop gros → extraction en service.

### Strangler Fig
**Quand :** migration progressive d'un legacy vers une nouvelle architecture.
**Comment :** router le trafic. Nouvelle fonctionnalité → nouveau système. Ancienne fonctionnalité migrée → proxy vers le nouveau, puis suppression. Le legacy se réduit jusqu'à disparaître. Chaque étape est déployable et rollbackable.
