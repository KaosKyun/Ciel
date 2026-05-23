---
name: event-driven
description: "Event-Driven Architecture — pub/sub, idempotence, dead letter queues, ordering, outbox pattern. À charger quand on a des services qui doivent communiquer sans couplage direct."
---

# Event-Driven Architecture

**Principe premier :** L'event-driven architecture n'est pas un pattern d'intégration — c'est une stratégie de découplage temporel. Le producer n'attend pas le consumer. Le consumer n'a pas besoin que le producer soit vivant. Cette indépendance temporelle est la vraie valeur, pas le "pub/sub". Mais elle a un prix : tu perds la consistence immédiate. Tu ne sais pas QUAND le consumer traitera l'événement. Assumer ce trade-off explicitement, c'est ça faire de l'event-driven.

## Checklist
- [ ] Chaque événement est un fait passé (past tense : `PaymentReceived`, pas `ReceivePayment`)
- [ ] Chaque consumer est idempotent — même événement reçu 2× = même résultat (pas de double charge)
- [ ] Dead Letter Queue configurée avec alerte — un message qui échoue > N fois ne bloque pas les autres
- [ ] L'ordre est géré explicitement quand il est nécessaire (partition key, ordering key)
- [ ] Les timeouts sont explicites — pas de consumer bloqué à l'infini sur un appel externe
- [ ] Outbox pattern pour les opérations DB + événement atomiques
- [ ] Métriques sur chaque file : lag, retry rate, DLQ size, processing time

## Anti-patterns
### Chaîne HTTP synchrone déguisée en événementielle
**Ce qu'on voit :** Service A publie un événement, attend la réponse de B via un autre événement. B attend C, qui attend D. Timeout à 30s.
**Pourquoi c'est dangereux :** c'est du HTTP synchrone avec plus d'étapes et de points de défaillance. Si D est lent, toute la chaîne timeout. Tu as ajouté la complexité de l'event-driven sans le bénéfice (découplage temporel).
**Faire plutôt :** si tu as besoin d'une réponse synchrone, fais du HTTP. L'event-driven est pour le "fire and forget" — le producer émet et continue sa vie, le consommateur traite quand il peut.

### Consumer non-idempotent
**Ce qu'on voit :** le consumer insère en DB sans vérifier si l'événement a déjà été traité. Un retry → double insertion.
**Pourquoi c'est dangereux :** en event-driven, at-least-once est la règle, pas l'exception. Les retries arrivent. Si ton consumer n'est pas idempotent, chaque retry corrompt les données. Un client débité 2×, un email envoyé 3×.
**Faire plutôt :** stocker l'event_id traité (dans la même transaction que le traitement). `INSERT ON CONFLICT (event_id) DO NOTHING`. Si l'event_id existe déjà, ACK sans traiter.

### Pas de DLQ
**Ce qu'on voit :** un message mal formé bloque le consumer. Retry infini. Tous les messages suivants sont bloqués derrière le message poison.
**Pourquoi c'est dangereux :** un seul message invalide paralyse tout le pipeline d'événements. Le lag s'accumule. Quand le consumer est débloqué, il a 100 000 messages de retard — et certains sont périmés.
**Faire plutôt :** DLQ après N retries (3-5). Alerte immédiate sur DLQ non vide. Mécanisme de replay depuis la DLQ après correction. Ne jamais ignorer silencieusement la DLQ.

## Patterns
### Outbox Pattern
**Quand :** une opération doit écrire en DB ET publier un événement de manière atomique.
**Comment :** écrire l'événement dans une table `outbox` dans la MÊME transaction DB que l'écriture métier. Un worker lit l'outbox et publie. Si le publish échoue, il retry. Si le worker crashe, l'événement est dans l'outbox. Garantit at-least-once sans 2PC.

### Idempotency Key
**Quand :** une opération doit être exécutée exactement une fois.
**Comment :** le producer génère une clé unique (`idempotency-key`). Le consumer stocke la clé + le résultat. Si la clé est déjà connue → retourner le résultat stocké, ne pas ré-exécuter. Stripe utilise ce pattern pour les paiements.

### Schema evolution
**Quand :** le format des événements change avec le temps.
**Comment :** chaque événement a un champ `version` et un `type`. Les upcasters transforment les anciens événements vers le nouveau format au replay. Ne jamais modifier un type d'événement existant — en créer un nouveau (ex: `OrderPlacedV2`).
