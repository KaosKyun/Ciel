---
name: reactive
description: "Programmation Reactive — observables, streams, RxJS, backpressure, event sourcing, flux de donnees. A charger quand on utilise un paradigme reactif ou des streams."
---

# Programmation Reactive

**Principe premier :** La programmation reactive n'est pas "utiliser RxJS" — c'est traiter les donnees comme un flux continu plutot que comme des valeurs ponctuelles. Dans un modele imperatif, tu demandes la valeur (`let x = getValue()`). Dans un modele reactif, tu t'abonnes au changement (`stream.subscribe(x => ...)`). La difference fondamentale : le code reactif se declare une fois et reagit a N evenements, le code imperatif repond a chaque evenement individuellement. Le piege : la complexite explose avec le nombre de streams. Sans gestion de la backpressure (producteur plus rapide que le consommateur) et du cycle de vie (unsubscribe), les streams deviennent une source de fuites memoire et de bugs subtils.

## Checklist
- [ ] Les streams sont unsubscribed proprement (`takeUntil`, `async pipe`, `DisposeBag`) — zero fuite memoire
- [ ] La backpressure est geree : le consommateur controle le debit (`buffer`, `throttle`, `sample`, `request(n)`)
- [ ] Les operateurs sont composees en pipeline lisible — pas de callback hell reactive
- [ ] Les erreurs sont propagees dans le stream — pas de `try/catch` autour de `.subscribe()`
- [ ] Les streams partages sont multicastes (`share`, `shareReplay`) — pas de side effect par souscripteur
- [ ] Les valeurs initiales sont definies (`BehaviorSubject`, `startsWith`) — pas de "le stream emet dans 5 secondes"
- [ ] Le debounce/throttle est utilise pour les evenements frequents (input utilisateur, scroll) — pas de traitement par frappe

## Anti-patterns
### Nested subscribes
**Ce qu'on voit :** `stream1.subscribe(x => { stream2.subscribe(y => { stream3.subscribe(z => { doSomething(x,y,z) }) }) })`. Trois niveaux de souscriptions imbriquees.
**Pourquoi c'est dangereux :** c'est le callback hell version reactive. Chaque subscribe est un effet de bord. Impossible de unsubcribe proprement. La gestion d'erreur est cassee. Si `stream1` emet pendant que `stream2` n'a pas fini → race condition. Le code est illisible et indetachable.
**Faire plutot :** `combineLatest([stream1, stream2, stream3]).pipe(takeUntil(destroy$)).subscribe(([x,y,z]) => doSomething(x,y,z))`. Un seul subscribe. Flat/compose, never nest.

### Pas de gestion de backpressure
**Ce qu'on voit :** un stream de clics souris a 1000 events/s. Le consommateur traite chaque event (appel API). La file d'attente memoire explose.
**Pourquoi c'est dangereux :** le producteur et le consommateur ont des vitesses differentes. Sans backpressure, le consommateur est inonde. Memoire → ∞. L'app freeze. Le comportement est non deterministe (depend de la charge).
**Faire plutot :** `sampleTime(200)` (prendre un event toutes les 200ms), `debounceTime(300)` (attendre 300ms de silence), `throttleTime(500)` (max 1 emission toutes les 500ms). Le consommateur controle le debit, pas le producteur.

### RxJS partout
**Ce qu'on voit :** tout est un observable. `Observable.of(42)`, `Observable.from([1,2,3])`. Même les valeurs synchrones passent par des streams.
**Pourquoi c'est dangereux :** la programmation reactive ajoute de la complexite cognitive et un surcout de performance. Pour des donnees synchrones (un tableau, une variable), un observable est un marteau-piqueur pour ouvrir une noix. Le code devient plus dur a lire sans benefice.
**Faire plutot :** utiliser les observables la ou l'asynchronisme et le temps sont intrinseques : evenements utilisateur, websockets, reponses serveur, timers. Pour le synchrone, les structures de donnees normales suffisent.

## Patterns
### takeUntil pour le cleanup
**Quand :** tout abonnement qui a une duree de vie < l'application (composant Angular, ecran React).
**Comment :** `destroy$ = new Subject<void>()`. Tous les pipelines se terminent par `.pipe(takeUntil(this.destroy$))`. Dans `ngOnDestroy` / `useEffect` cleanup : `this.destroy$.next(); this.destroy$.complete()`. Tous les abonnements sont nettoyes en une ligne.

### Event bus central
**Quand :** communication entre composants non relies (pas de parent-enfant).
**Comment :** un `Subject` ou `EventEmitter` partage. Les producteurs emettent, les consommateurs souscrivent. Chaque message est un type specifique (pas de `any`). Le bus est mockable en test. Alternative a Redux pour les cas simples ou la communication est le seul besoin.
