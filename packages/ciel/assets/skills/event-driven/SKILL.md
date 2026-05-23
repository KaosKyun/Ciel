---
name: event-driven
description: "Event-Driven Architecture — pub/sub, event bus (Kafka/RabbitMQ), idempotence, dead letter queues. A charger des qu'on a ≥ 3 services qui communiquent."
---

# Event-Driven Architecture

## Checklist
- [ ] Les evenements sont des faits passes (past tense : `PaymentReceived`, pas `ReceivePayment`)
- [ ] Chaque consumer est idempotent (meme evenement recu 2× = meme resultat)
- [ ] Dead letter queue configuree pour les messages qui echouent
- [ ] Le schema des evenements est versionne
- [ ] L'ordre des evenements est gere (ordering key / partition key)
- [ ] Les timeouts de traitement sont explicites (pas de consumer bloque a l'infini)
- [ ] Le monitoring des files est en place (lag, retry rate, DLQ size)

## Anti-patterns
### HTTP synchrone en chaine
**Ce qu'on voit :** `POST /orders` → `POST /payments` → `POST /notifications`. Chaque appel attend le suivant.
**Pourquoi c'est dangereux :** si `notifications` est lent, toute la chaine est lente. Si `notifications` echoue, la commande est perdue.
**Faire plutot :** `POST /orders` publie `OrderCreated`. PaymentService s'abonne. NotificationService s'abonne. Chacun a son rythme.

### Consumer non-idempotent
**Ce qu'on voit :** le consumer insere en DB sans verifier si l'evenement a deja ete traite.
**Pourquoi c'est dangereux :** retry = double insertion. Un client est debite 2×.
**Faire plutot :** stocker l'event_id traite. Verifier avant de traiter. Ou utiliser INSERT ON CONFLICT DO NOTHING.

### Pas de DLQ
**Ce qu'on voit :** un message invalide bloque le consumer indefiniment (retry infini).
**Pourquoi c'est dangereux :** tous les messages suivants sont bloques. Le consumer est paralyse par un seul message pourri.
**Faire plutot :** DLQ apres N retries. Alerte sur DLQ non vide. Re-traiter les messages de la DLQ apres correction.

## Patterns
### Event Bus
**Quand :** plusieurs services doivent reagir au meme evenement sans couplage direct.
**Comment :** producer publie sur un topic. Chaque consumer a sa propre queue ou son consumer group. Pas de dependance directe entre producer et consumer.

### Outbox Pattern
**Quand :** une operation doit ecrire en DB ET publier un evenement de maniere atomique.
**Comment :** ecrire l'evenement dans une table outbox dans la meme transaction DB. Un worker lit l'outbox et publie les evenements. Garantit at-least-once delivery.

### Idempotency Key
**Quand :** une operation ne doit etre executee qu'une seule fois meme si l'appel est repete.
**Comment :** le producer envoie un idempotency-key unique. Le consumer stocke la cle. Si la cle est deja connue → repondre avec le resultat deja calcule, ne pas re-executer.
