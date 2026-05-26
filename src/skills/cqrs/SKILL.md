---
name: cqrs
description: "CQRS & Event Sourcing — séparation lecture/écriture, projections, event store, eventual consistency. À charger quand les patterns de lecture et d'écriture divergent radicalement."
---

# CQRS & Event Sourcing

**Principe premier :** CQRS n'est pas une architecture — c'est la reconnaissance d'un fait : lire et écrire sont deux opérations fondamentalement différentes. Une écriture doit protéger des invariants, une lecture doit être rapide et façonnée pour le client. Les forcer dans le même modèle crée un compromis qui ne satisfait ni l'un ni l'autre. L'event sourcing est orthogonal : c'est la décision de stocker des événements (faits) plutôt que l'état courant. CQRS + Event Sourcing n'est pas un package deal — tu peux faire du CQRS sans event sourcing.

## Checklist
- [ ] Le besoin de CQRS est avéré — les lectures et écritures ont VRAIMENT des patterns différents
- [ ] Le modèle d'écriture protège les invariants (aggregates, validation)
- [ ] Le modèle de lecture est optimisé pour les requêtes du client (dénormalisé, pré-calculé)
- [ ] L'eventual consistency est assumée et documentée — pas de "surprise" pour les utilisateurs
- [ ] Si event sourcing : l'event store est append-only, les projections sont reconstruisibles
- [ ] Les événements sont versionnés (schema evolution) — un événement de 2024 doit être lisible en 2026

## Anti-patterns
### CQRS pour un CRUD
**Ce qu'on voit :** CQRS + Event Sourcing pour un formulaire de contact. CommandBus, EventStore, Projections, ReadModels — pour stocker un nom et un message.
**Pourquoi c'est dangereux :** le coût de cette architecture est énorme : eventual consistency, debugging complexe, replay à maintenir. Pour un CRUD, ce coût n'est jamais amorti. Tu passes 10× plus de temps sur l'infrastructure que sur la logique métier.
**Faire plutôt :** CRUD simple. Repository pattern. Ajouter CQRS UNIQUEMENT quand les lectures sont ≥ 10× plus fréquentes que les écritures ET que les patterns divergent. Même là, commencer par du CQRS sans event sourcing.

### Event sourcing sans besoin d'audit
**Ce qu'on voit :** tout le système en event sourcing "au cas où on aurait besoin de l'historique". 200 événements par aggregate, replay de 30 secondes au démarrage.
**Pourquoi c'est dangereux :** l'event sourcing a un coût permanent : snapshots, upcasters, replay, debugging d'event streams. Si le métier n'a pas besoin de l'historique complet des changements (audit, conformité, debug), ce coût est du gaspillage pur.
**Faire plutôt :** stocker l'état courant. Logger les changements importants dans une table d'audit séparée (pas l'event store). Event sourcing UNIQUEMENT quand l'historique est une exigence métier, pas technique.

### Projections non monitorées
**Ce qu'on voit :** la projection de lecture est stale (lag de 50 000 événements). Personne ne le sait. Les utilisateurs voient des données vieilles de 10 minutes.
**Pourquoi c'est dangereux :** l'eventual consistency sans monitoring devient de l'inconsistance tout court. Le lag des projections est la métrique #1 d'un système CQRS — si tu ne la mesures pas, tu ne sais pas dans quel état est ton système.
**Faire plutôt :** métriques sur le lag des projections. Alerte si lag > N événements ou > M secondes. Read-model reconstruit automatiquement si trop de lag (pas de rattrapage infini).

## Patterns
### CQRS sans Event Sourcing
**Quand :** lectures et écritures divergent mais l'historique n'est pas requis.
**Comment :** command → validation → DB transactionnelle (état courant). Projection → vue dénormalisée mise à jour dans la même transaction ou via un worker. Pas d'event store, pas de replay. La complexité est proportionnelle au besoin.

### Event Store
**Quand :** l'historique complet est une exigence métier (finance, audit, conformité).
**Comment :** append-only. Chaque événement = un fait passé (`OrderPlaced`, pas `PlaceOrder`). Projections = vues dérivables à tout moment. Snapshots réguliers pour éviter le replay complet.
