---
name: reactive
description: "Programmation Reactive — RxJS, observables, streams, event sourcing, backpressure, reactive forms. A charger quand on utilise un paradigme reactif."
triggers:
  path: "**/*.reactive*,**/rxjs*,**/observable*,**/subject*,**/event-sourcing*"
---

# Programmation Reactive

## Checklist
- [ ] Les streams sont unsubscribed (pas de fuite memoire, gestion du cycle de vie)
- [ ] La backpressure est geree (pas de producteur plus rapide que le consommateur)
- [ ] Les erreurs dans les streams sont capturees (catchError, retry, fallback)
- [ ] Les side effects sont dans des `tap` ou `effect` — pas dans les operators de transformation
- [ ] Les observables sont cold par defaut (hot seulement si justifie)
- [ ] Les schedulers sont utilises pour le threading (observeOn, subscribeOn)
- [ ] Les tests des streams sont deterministes (marble testing ou equivalent)

## Anti-patterns
### Subscription infini
**Ce qu'on voit :** `dataService.getData().subscribe(data => updateUI(data))` — jamais unsubscribe.
**Pourquoi c'est dangereux :** si le composant est detruit, la subscription continue. La callback est appelee avec des donnees pour un composant mort. Fuite memoire.
**Faire plutot :** unsubscribe automatique (AsyncPipe, takeUntil, takeWhile). `ngUnsubscribe$` qui complete en ngOnDestroy. Ou `toSignal`/`toResource` dans Angular.

### Streams imbrique
**Ce qu'on voit :** `obs1.subscribe(v1 => { obs2(v1).subscribe(v2 => { obs3(v2).subscribe(v3 => { ... }) }) })` — callback hell reactif.
**Pourquoi c'est dangereux :** les subscriptions s'accumulent. Les streams ne sont pas composables. Le debugging est impossible.
**Faire plutot :** higher-order operators : `switchMap`, `mergeMap`, `concatMap`, `exhaustMap`. Le stream reste plat et compose.

### Subject expose en public
**Ce qu'on voit :** `class Service { subject = new Subject<User>() }` — le composant peut appeler `next()` sur le subject.
**Pourquoi c'est dangereux :** n'importe qui peut emettre des fausses valeurs dans le stream. Pas d'encapsulation. Les invariants ne sont pas proteges.
**Faire plutot :** `class Service { private subject = new Subject<User>(); public readonly data$ = this.subject.asObservable(); }`. Le subject est prive, l'observable est publique.

## Patterns
### Gestion automatique des subscriptions
**Quand :** composant/controlleur qui souscrit a plusieurs streams.
**Comment :** AsyncPipe (Angular), `takeUntil(this.destroy$)` automatique, ou base component qui unsubscribe. La regle : "si on subscribe, on doit unsbuscribe."

### State management reactif
**Quand :** etat applicatif gere de maniere reactive.
**Comment :** store = `BehaviorSubject<State>`. Les composants souscrivent a des selectors. Les actions modifient le state via des reducers. Flux unidirectionnel : Action → Reducer → Store → View.
