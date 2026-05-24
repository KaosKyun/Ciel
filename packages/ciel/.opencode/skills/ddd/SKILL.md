---
name: ddd
description: "Domain-Driven Design — Bounded Contexts, Ubiquitous Language, Aggregates, Domain Events, Strategic Design. À charger quand on modélise un domaine métier complexe."
---

# Domain-Driven Design

**Principe premier :** DDD n'est pas un pattern technique — c'est une discipline de modélisation. Le but n'est pas d'utiliser Entities, Value Objects et Aggregates. Le but est de faire en sorte que le code parle le même langage que le métier. Si un expert métier lit ton code et ne reconnaît pas son domaine, tu as échoué, peu importe la qualité technique des patterns. Le Ubiquitous Language est le livrable principal — tout le reste en découle.

## Checklist
- [ ] Le Ubiquitous Language est le même dans le code ET dans les conversations avec le métier
- [ ] Les Bounded Contexts sont identifiés et leurs frontières sont explicites
- [ ] Chaque Aggregate a une racine qui protège ses invariants
- [ ] Les Value Objects sont immutables et validés à la construction
- [ ] La logique métier est dans le domaine — pas dans les services, pas dans les controllers
- [ ] Les Repositories sont des interfaces dans le domaine, implémentées dans l'infrastructure

## Anti-patterns
### Anemic Domain Model
**Ce qu'on voit :** `class Order { id, status, total, getters, setters }` — le domaine est un sac de données. Toute la logique est dans `OrderService.process()`, `OrderService.approve()`, etc.
**Pourquoi c'est dangereux :** le modèle ne protège rien. N'importe quel code peut faire `order.status = "shipped"` sans vérifier le paiement. Les règles métier sont dupliquées. Le code ment sur ce qui est possible.
**Faire plutôt :** le domaine est le gardien. `order.approve()` vérifie le statut, le stock, le crédit. `order.ship()` vérifie que la commande est approuvée. Les setters publics n'existent pas sur les propriétés qui ont des règles.

### Bounded Context unique
**Ce qu'on voit :** une table `users` partagée par l'auth, le billing, le shipping, le marketing. Une entité `Order` unique pour tout le système.
**Pourquoi c'est dangereux :** "Client" ne veut pas dire la même chose pour le support (historique de tickets) et pour la facturation (adresse, TVA). Forcer un modèle unique crée des compromis qui ne satisfont personne et couplent tous les modules ensemble.
**Faire plutôt :** chaque contexte a sa propre représentation. `SalesContext.Order` a les items et le prix. `ShippingContext.Shipment` a l'adresse et le tracking. Ils communiquent par événements (`OrderPlaced` → le shipping crée son Shipment).

### Tactical sans strategic
**Ce qu'on voit :** l'équipe utilise Entities, Value Objects, Aggregates, Repositories — mais n'a jamais défini les Bounded Contexts ni le Ubiquitous Language.
**Pourquoi c'est dangereux :** les patterns tactiques sans design stratégique, c'est comme des murs sans plan d'architecte. Tu construis proprement, mais peut-être au mauvais endroit. Les Bounded Contexts définissent CE QUI va ensemble — sans ça, les Aggregates sont arbitraires.
**Faire plutôt :** commencer par le strategic design : Event Storming, Context Mapping, Ubiquitous Language. Les patterns tactiques viennent APRÈS, pour implémenter ce qui a été modélisé.

## Patterns
### Bounded Context
**Quand :** le domaine a des significations différentes pour le même terme. "Client" pour le support ≠ "Client" pour la facturation.
**Comment :** frontière explicite. Chaque contexte a son propre modèle, son propre langage, sa propre persistence. Communication inter-contexte par Domain Events ou API bien définies. Pas de jointure SQL entre contextes.

### Aggregate Root
**Quand :** un groupe d'objets doit rester cohérent (invariants). Ex: Order + OrderItems. Le total doit toujours = somme des items.
**Comment :** une entité racine protège l'accès. Toute modification passe par la racine : `order.addItem()`, jamais `orderItem.setPrice()`. Les objets externes ne référencent jamais l'intérieur d'un aggregate — ils passent par la racine.

### Domain Events
**Quand :** un changement dans un contexte doit être connu d'un autre.
**Comment :** l'aggregate émet un événement : `OrderPlaced { orderId, customerId, total }`. Les autres contextes s'abonnent. L'événement est un fait passé (past tense), immuable, et contient tout ce dont le consommateur a besoin (pas de référence à l'aggregate).
