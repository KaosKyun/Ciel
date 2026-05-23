---
name: serverless
description: "Serverless — fonctions comme unites de deploiement, cold starts, concurrency, API Gateway, Step Functions, cout a la requete. A charger quand on utilise des fonctions serverless."
---

# Serverless

**Principe premier :** Le serverless n'est pas "pas de serveur" — c'est "le serveur n'est pas ton probleme". Tu echange le controle contre la simplicite operationnelle. Le piege : tu ne controles plus le runtime, la memoire, le reseau, le systeme de fichiers. Chaque hypothese que tu fais sur l'execution ("le /tmp existe", "l'IP est stable", "le process survit entre deux requetes") est une source de bug. Le serverless recompense l'architecture stateless et punit le stateful. Le cout est a la requete — une fonction inefficace coute de l'argent a chaque appel, pas juste du CPU.

## Checklist
- [ ] Les fonctions sont stateless — pas de donnees persistees dans le filesystem local (/tmp est ephemere)
- [ ] Les connexions DB/Redis sont hors du handler (global scope, reutilisees entre invocations)
- [ ] Le timeout est configure explicitement (3s pour API, 30s max pour async) — pas de timeout infini
- [ ] La memoire est dimensionnee correctement (plus de RAM = plus de CPU, mais plus de cout)
- [ ] Les cold starts sont mesures (P50/P95) et optimises (bundling, provisioned concurrency si necessaire)
- [ ] API Gateway / load balancer a un health check independant de la fonction
- [ ] Les fonctions ont un dead letter queue pour les evenements non traites

## Anti-patterns
### Fonction monolithe
**Ce qu'on voit :** une seule Lambda/Cloud Function qui gere toutes les routes. 500MB de code, 3s de cold start. "C'est un microservice."
**Pourquoi c'est dangereux :** le cold start est proportionnel a la taille du code. Le deploiement est tout-ou-rien. Le debugging est un cauchemar. C'est un monolithe avec les inconvenients du serverless (cold starts, timeouts) sans les benefices (isolation, deploiement independant).
**Faire plutot :** une fonction par endpoint/operation. Chaque fonction est independante : son propre code, son propre deploiement, son propre timeout. Si une fonction est lente, les autres ne sont pas affectees.

### State cache dans le handler
**Ce qu'on voit :** `let connection; export const handler = async (event) => { if (!connection) connection = await createDbConnection(); ... }` — le test unitaire passe, la prod echoue aleatoirement.
**Pourquoi c'est dangereux :** la connection est reutilisee entre invocations mais pas entre cold starts. Le comportement depend de l'etat du container (warm/cold), ce qui est non deterministe. Pire : si la connection est stales (timeout serveur), elle echoue silencieusement.
**Faire plutot :** initialiser dans le global scope, AVANT le handler. Verifier la sante de la connexion a chaque invocation. Accepter que les cold starts arrivent et les monitoriser.

### Serverless pour tout
**Ce qu'on voit :** toute l'architecture est en serverless. Y compris un job qui tourne 24/7, un websocket qui reste ouvert 2h, une DB de 10 To.
**Pourquoi c'est dangereux :** le serverless est optimal pour les charges sporadiques et les pics. Pour une charge constante, le cout par requete est superieur a un serveur. Les timeouts (15 min Lambda, 60 min Cloud Functions) rendent certains workloads impossibles. Les websockets sur serverless = cout eleve et latence variable.
**Faire plutot :** serverless pour les API, les traitements asynchrones, les cron jobs. Serveur/container pour les charges constantes, les connexions longues, les traitements lourds. Hybride : ce n'est pas l'un ou l'autre.

## Patterns
### Global scope initialization
**Quand :** toute fonction qui utilise une connexion externe (DB, Redis, API client).
**Comment :** initialiser les clients hors du handler. Le runtime reutilise le container pour plusieurs invocations — le code hors handler n'est execute qu'au cold start. SDK clients, connexions, configuration : tout dans le global scope. Le handler ne fait que le metier.

### Step Functions pour l'orchestration
**Quand :** workflow multi-etapes (paiement → stock → email → facture).
**Comment :** chaque etape est une fonction separee. Step Functions gere les transitions, les retries, les timeouts, la compensation (Saga pattern). Le workflow est visible dans la console, chaque etape est monitorisee independamment.
