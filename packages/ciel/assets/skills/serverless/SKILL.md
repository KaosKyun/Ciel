---
name: serverless
description: "Serverless — Lambda/Cloud Functions, API Gateway, Step Functions, cold starts, concurrency, cost traps. A charger quand on utilise des fonctions serverless."
---

# Serverless

## Checklist
- [ ] Les fonctions sont stateless (pas de donnees persistees dans le filesystem local)
- [ ] Les connexions DB/Redis sont hors du handler (initialisees dans le global scope)
- [ ] Les timeouts sont explicites et coherents avec le comportement attendu
- [ ] Les cold starts sont acceptables ou attenues (provisioned concurrency)
- [ ] Les erreurs sont dans une DLQ (Dead Letter Queue) — pas silencieuses
- [ ] Les permissions IAM de la fonction sont minimales (une seule action, une seule ressource)
- [ ] Les secrets sont injectes via environment variables chiffrees (pas hardcodes)

## Anti-patterns
### Connexion DB dans le handler
**Ce qu'on voit :** `exports.handler = async (event) => { const db = new Client(process.env.DB_URL); await db.connect(); ... }`.
**Pourquoi c'est dangereux :** chaque invocation cree une nouvelle connexion. Les cold starts passent de 100ms a 3s. Le pool de connexions DB sature.
**Faire plutôt :** `const db = new Client(process.env.DB_URL); exports.handler = async (event) => { ... }` — la connexion est initialisee au boot du container Lambda, reutilisee entre les invocations.

### Timeout trop long
**Ce qu'on voit :** timeout Lambda a 15 minutes (max AWS) pour une API qui attend une reponse HTTP.
**Pourquoi c'est dangereux :** l'appelant attend 15 minutes avant de recevoir un timeout. Les ressources sont bloquees. La facture explose (paye pour le temps d'attente).
**Faire plutôt :** timeout API Gateway ≤ 30s. Timeout Lambda ≤ ce que l'utilisateur peut attendre. Les traitements longs passent par Step Functions ou SQS + worker.

### Pas de DLQ
**Ce qu'on voit :** `exports.handler = async (event) => { throw new Error("oups"); }` — l'erreur est logguee et ignoree.
**Pourquoi c'est dangereux :** le message est perdu. Aucun retry. Aucune alerte. L'evenement disparait sans laisser de trace.
**Faire plutôt :** DLQ configuree sur la source d'evenements (SQS, EventBridge). Apres N retries, le message va dans la DLQ. Alerte sur DLQ non vide. Replay possible.

## Patterns
### Initialisation hors handler
**Quand :** toute fonction qui utilise une connexion (DB, Redis, HTTP client).
**Comment :** `const db = new PrismaClient()` dans le global scope. Le container Lambda n'initialise qu'une fois. Les invocations subsequentes reutilisent la connexion.

### Provisioned concurrency
**Quand :** les cold starts > 500ms sont inacceptables (API utilisateur).
**Comment :** provisionner N instances pre-chauffees. Cout fixe (payer pour avoir des instances pretes) mais pas de cold start pour les N premieres requetes.

### Step Functions
**Quand :** un workflow avec plusieurs etapes (validation → paiement → notification → suivi).
**Comment :** chaque etape est une Lambda. Step Functions orchestre les transitions, gere les retries, les timeouts, les branches conditionnelles. Visible, debogable, monitorable.
