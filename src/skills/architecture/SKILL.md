---
name: architecture
description: "Architecture Logicielle — monolithe modulaire, microservices, ports/adapters, ADR, Strangler Fig, trade-offs. A charger quand on definit la structure d'un projet."
---

# Architecture Logicielle

**Principe premier :** L'architecture n'est pas une collection de patterns — c'est la gestion explicite des dependances. La qualite d'une architecture se mesure a une chose : combien de modules dois-je toucher pour faire un changement metier ? Si la reponse est > 3, l'architecture est cassee, peu importe le pattern utilise. Le bon pattern depend du contexte (taille d'equipe, frequence de changement, exigences de scale), pas de la mode.

## Checklist
- [ ] Le choix d'architecture est justifie par le contexte et documente (ADR)
- [ ] Les dependances pointent vers le domaine — jamais l'inverse (Domain <> Infrastructure)
- [ ] Les modules sont nommes par capacite metier (billing, shipping), pas par couche technique (controllers, services, utils)
- [ ] Chaque module a une interface explicite (contrat) — pas de couplage par import direct interne
- [ ] Demarrer simple (monolithe modulaire) — extraire en service UNIQUEMENT quand le besoin est prouve
- [ ] Le diagramme de contexte (C4 niveau 1-2) existe et est visible des nouveaux

## Trade-offs : les 3 architectures

### Monolithe simple vs Monolithe modulaire vs Microservices

| | Monolithe simple | Monolithe modulaire | Microservices |
|--|-----------------|-------------------|--------------|
| **Structure** | 1 codebase, pas de frontieres internes | 1 codebase, modules separes par domaine (billing/, orders/) | N codebases independantes |
| **Deploiement** | 1 artefact | 1 artefact | N artefacts |
| **Avantages** | Simple, rapide a demarrer | Deploiement simple, frontieres claires, peut extraire en service plus tard | Scale independant, equipes autonomes, isolation de pannes |
| **Desavantages** | Devient vite un "big ball of mud" | Modules peuvent se coupler par import direct si pas discipline | Cout reseau, latence, serialisation, deploiements coordonnes |
| **Quand choisir** | POC, equipe 1-3, court-terme | Equipe 4-20, projet long-terme | > 5 equipes, besoin de scale independant |
| **Piege** | "On modularisera plus tard" → jamais fait | Modules deviennent des services deguises (imports croises) | Microservices sans equipes autonomes = pire que monolithe |

**Regle :** commencer monolithe modulaire. Extraire en microservice quand : (1) l'equipe est trop grande pour une codebase (> 20), OU (2) un module a besoin de scale independant, OU (3) un module a un cycle de release different.

## Anti-patterns
### Microservices comme defaut
**Ce qu'on voit :** 12 services, 12 repos, 12 pipelines — pour 3 devs et 100 utilisateurs. Un changement simple touche 4 repos.
**Pourquoi c'est dangereux :** les microservices deplacent la complexite du code vers le reseau. Chaque service ajoute latence, serialisation, gestion d'erreur reseau. Le seuil n'est pas technologique, il est organisationnel : une equipe par service.
**Faire plutot :** monolithe modulaire. Domaines separes en modules, interfaces explicites, meme codebase. Un commit = un changement. Extraire un service quand l'equipe grandit (> 20) ou qu'un module a besoin de scale independant.

### Architecture en couches videe
**Ce qu'on voit :** Controller → Service → Repository. Le Service fait 3 lignes : `return this.repository.findById(id)`. Le domaine n'existe pas — c'est un tuyau HTTP→DB.
**Pourquoi c'est dangereux :** les regles metier sont eparpillees dans les controllers, validateurs, middlewares. Changer une regle oblige a traquer la logique dans 6 fichiers.
**Faire plutot :** le domaine contient les regles. `order.approve()` verifie le statut, le credit, la dispo. Le service orchestre, le repository persiste, le controller traduit HTTP. Chaque couche a une VRAIE responsabilite.

### Architecture decidee puis figee
**Ce qu'on voit :** un diagramme dessine il y a 3 ans. L'archi reelle a diverge. Personne ne l'a documente.
**Pourquoi c'est dangereux :** l'architecture documentee est un mensonge. Les nouveaux devs prennent des decisions sur une base fausse. La derive architecturale s'accelere.
**Faire plutot :** ADR (Architecture Decision Records) pour les decisions importantes. Diagrammes regeneres (C4 via structurizr ou PlantUML). L'architecture est vivante.

## Patterns
### Monolithe modulaire
**Quand :** debut de projet, equipe < 20, pas de besoin de scale independant.
**Comment :** modules par domaine (billing/, shipping/, auth/). Chaque module a son propre schema DB logique. Communication inter-module par interfaces explicites.
- **Avantages :** deploy simple, refactoring facile (un commit), pas de latence reseau
- **Desavantages :** scale tout-ou-rien, un module peut bloquer le deploiement
- **Mise en place :** (1) Creer un dossier par domaine (`src/billing/`, `src/shipping/`). (2) Chaque module expose une interface publique (`index.ts` avec exports explicites). (3) Les imports entre modules passent UNIQUEMENT par l'interface publique. (4) Chaque module a ses propres migrations DB. (5) Tester les modules isolement. (6) Si un module devient trop gros → Strangler Fig pour l'extraire.

### Ports & Adapters (Hexagonale)
**Quand :** le domaine metier doit survivre aux changements d'infrastructure.
**Comment :** le domaine definit des interfaces (ports : `OrderRepository`, `PaymentGateway`). Les adapters implementent ces interfaces (PostgresAdapter, StripeAdapter). Le domaine ne depend de rien d'externe.
- **Avantages :** changer de DB ou de payment provider sans toucher le domaine. Testable sans infra.
- **Desavantages :** couche d'abstraction supplementaire. Plus de fichiers.
- **Mise en place :** (1) Definir les ports dans le domaine. (2) Implementer les adapters dans un dossier `infrastructure/`. (3) Injecter les adapters au runtime (constructor injection). (4) Tester le domaine avec des adapters in-memory. (5) Tester les vrais adapters en integration.

### Strangler Fig (migration progressive)
**Quand :** migration d'un legacy vers une nouvelle architecture sans big bang.
**Comment :** router le trafic progressivement. Nouvelle fonctionnalite → nouveau systeme. Ancienne migree → proxy vers nouveau, puis suppression.
- **Avantages :** chaque etape est deployable et rollbackable. Zero downtime.
- **Desavantages :** plus lent qu'un big bang. Cout de maintenance du proxy et des deux systemes en parallele.
- **Mise en place :** (1) Placer un proxy/API Gateway devant le legacy. (2) Creer le nouveau service avec un sous-ensemble de fonctionnalites. (3) Router par endpoint : `GET /orders` → nouveau, le reste → legacy. (4) Migrer les endpoints un par un, valider chaque migration. (5) Migrer les donnees progressivement (dual-write puis backfill). (6) Quand tout le trafic est sur le nouveau → supprimer le legacy. (7) Supprimer le proxy. Chaque etape = une PR deployable.

### ADR (Architecture Decision Record)
**Quand :** toute decision architecturale non triviale.
**Comment :** document leger (1-2 pages) dans `docs/adrs/NNNN-title.md`. Format : Titre, Statut (proposed/accepted/deprecated), Contexte, Decision, Alternatives, Consequences.
- **Mise en place :** (1) Creer `docs/adrs/`. (2) Template ADR. (3) Chaque decision significative → un ADR. (4) Les ADR sont revus en PR comme du code. (5) Les ADR obsoletes sont marques `deprecated` (pas supprimes — l'historique a de la valeur). Un nouveau membre lit les ADR dans l'ordre pour comprendre l'histoire de l'architecture.
