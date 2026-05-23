---
name: ddd
description: "Domain-Driven Design — Bounded Contexts, Entities, Value Objects, Aggregates, Ubiquitous Language. A charger quand on modelise un domaine metier complexe."
---

# Domain-Driven Design

## Checklist
- [ ] Le ubiquitous language est partage avec le metier (pas de jargon technique dans le domaine)
- [ ] Les bounded contexts sont identifies (frontieres explicites entre domaines)
- [ ] Chaque aggregate a une racine (aggregate root) et des invariants
- [ ] Les value objects sont immutables (pas de setters)
- [ ] Les entities ont une identite (ID unique) — les value objects non
- [ ] Les regles metier sont DANS le domaine, pas dans les services ou controllers
- [ ] Les repositories sont des interfaces dans le domaine, implementees dans l'infra

## Anti-patterns
### Anemic domain model
**Ce qu'on voit :** des classes `User`, `Order`, `Product` avec seulement des getters/setters. Toute la logique est dans `UserService`, `OrderService`.
**Pourquoi c'est dangereux :** le domaine est anemique. Les regles metier sont eparpillees dans des services sans cohesion. Le modele ne protege rien.
**Faire plutot :** le domaine contient le comportement. `order.approve()` verifie les invariants. Le service orchestre, il ne contient pas la logique metier.

### Un seul bounded context pour tout
**Ce qu'on voit :** une table `orders` avec des colonnes pour le shipping, la facturation, le marketing. Un `User` unique utilise par tous les modules.
**Pourquoi c'est dangereux :** chaque changement metier impacte tout le monde. Le shipping ne peut pas evoluer sans la facturation.
**Faire plutot :** `Order` dans `SalesContext` (commande), `Shipment` dans `ShippingContext` (expedition). Chaque contexte a sa propre representation.

### Violation d'aggregate
**Ce qu'on voit :** modification d'un `OrderItem` directement depuis l'exterieur sans passer par la racine `Order`.
**Pourquoi c'est dangereux :** les invariants de l'aggregate sont violes. `Order.total` n'est plus coherent avec les `OrderItems`.
**Faire plutot :** `order.addItem()` modifie l'aggregate et recalcule le total. Les objets internes ne sont jamais modifies directement.

## Patterns
### Bounded Context
**Quand :** le domaine est assez large pour avoir des significations differentes du meme terme. "Client" pour le support ≠ "Client" pour la facturation.
**Comment :** definir des frontieres explicites. Chaque contexte a son propre modele, son propre ubiquitous language. Communication inter-contexte par domain events ou API.

### Aggregate Root
**Quand :** un groupe d'objets doit etre coherent (invariants). Ex: Order + OrderItems.
**Comment :** une entite racine protege l'acces. Toute modification passe par la racine. Les objets internes ne sont jamais references de l'exterieur.

### Value Object
**Quand :** une valeur n'a pas d'identite propre, elle est definie par ses attributs. Ex: Money, Email, Address.
**Comment :** immutable. Pas d'ID. Egalite par valeur. `new Money(10, "EUR").equals(new Money(10, "EUR"))` → true.
