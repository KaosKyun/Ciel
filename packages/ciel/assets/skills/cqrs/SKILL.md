---
name: cqrs
description: "CQRS / Event Sourcing — separation lecture/ecriture, projections, event store, replay. A charger quand les patterns de lecture et d'ecriture divergent fortement."
---

# CQRS / Event Sourcing

## Checklist
- [ ] Le besoin de CQRS est avere (les lectures et ecritures ont des patterns differents)
- [ ] Le modele de lecture est optimise pour les requetes (denormalise, pre-calcule)
- [ ] Le modele d'ecriture est optimise pour la coherence (aggregates, invariants)
- [ ] Si event sourcing : l'event store est append-only
- [ ] Si event sourcing : les projections sont reconstruisibles (replay)
- [ ] Les evenements sont versionnes (schema evolution)

## Anti-patterns
### CQRS sans besoin
**Ce qu'on voit :** CQRS + Event Sourcing pour un blog avec 100 visiteurs/jour.
**Pourquoi c'est dangereux :** complexite enorme (event store, projections, replay) pour zero benefice. Cout de maintenance 5×.
**Faire plutot :** CRUD simple. Ajouter CQRS UNIQUEMENT quand les lectures sont ≥ 10× plus frequentes que les ecritures ou que le pattern de lecture est radicalement different.

### Projection inconsistante
**Ce qu'on voit :** la projection de lecture n'est pas mise a jour apres un evenement.
**Pourquoi c'est dangereux :** l'utilisateur ecrit → l'ecriture reussit → la lecture montre l'ancien etat. Incoherence visible.
**Faire plutot :** eventual consistency assumee et communiquee. Projections mises a jour via abonnement aux evenements.

### Event store non-versionne
**Ce qu'on voit :** l'evenement `OrderPlaced` change de schema sans gestion de version.
**Pourquoi c'est dangereux :** impossible de rejouer les anciens evenements. Corruption silencieuse.
**Faire plutot :** chaque evenement a une version. Upcaster pour migrer les anciens evenements vers le nouveau schema.

## Patterns
### Separation lecture/ecriture
**Quand :** les requetes de lecture sont complexes (JOINs, aggregations) et les ecritures sont simples (validation + insert).
**Comment :** command model → validation + persistence. Query model → vues denormalisees optimisees pour les requetes. Synchro par evenements.

### Event Store
**Quand :** l'historique complet des modifications a de la valeur (audit, conformite, debug).
**Comment :** append-only log. Chaque evenement = un fait passe (past tense : `OrderPlaced`, pas `PlaceOrder`). Projections = vues derivees du flux d'evenements.

### Snapshot
**Quand :** le flux d'evenements devient trop long a rejouer (> 1000 evenements par aggregate).
**Comment :** sauvegarder l'etat complet a intervalle regulier. Replay = dernier snapshot + evenements post-snapshot.
