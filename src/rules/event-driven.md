---
paths:
  - "**/*consumer*"
  - "**/*subscriber*"
  - "**/*producer*"
  - "**/*.event.*"
  - "**/*events*"
  - "**/*message-handler*"
  - "**/*messagehandler*"
---

## Dispatch
- Charge `event-driven` AVANT d'ecrire un producer/consumer ou un handler de message.
- Si paiement ou operation critique → charge aussi `appsec` (l'idempotence est une garantie financiere).

## Regles dures (zero tolerance)
- **Toujours** des consumers idempotents — at-least-once est la regle, les retries arrivent. Stocker l'`event_id` traite dans la MEME transaction (`INSERT ON CONFLICT DO NOTHING`).
- **Toujours** une Dead Letter Queue avec alerte — un message poison ne bloque jamais les suivants (N retries puis DLQ).
- **Jamais** de dual-write DB + publish non-atomique — utiliser l'Outbox pattern (event dans une table outbox, meme transaction, worker publie).
- **Jamais** de chaine d'evenements synchrone deguisee — si tu attends une reponse, fais du HTTP.

## Conventions du projet
- Evenements au passe (`PaymentReceived`) ; ne jamais modifier un type existant, creer un `V2`.
- Ordre gere explicitement (partition / ordering key) seulement quand c'est necessaire.
- Timeouts explicites sur tout appel externe dans un consumer.
- Metriques par file : lag, retry rate, DLQ size, processing time.
