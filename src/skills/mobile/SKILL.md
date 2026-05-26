---
name: mobile
description: "Mobile — iOS/Android/React Native/Flutter, offline-first, batterie, store review, push notifications. A charger quand on developpe une application mobile."
---

# Mobile

**Principe premier :** Le mobile n'est pas "un petit ecran" — c'est un environnement hostile. Reseau instable (tunnel → metro → edge → 3G), batterie limitee, stockage restreint, OS qui peut killer l'app a tout moment. Si ton app ne fonctionne pas dans un tunnel avec 1 barre de 3G et 10% de batterie, elle ne fonctionne pas. Le store (App Store, Play Store) est ton canal de distribution mais aussi ton gatekeeper — chaque release est une revue humaine qui peut etre rejetee. Le mobile recompense l'optimisme offline et le pessimisme reseau : suppose toujours que le reseau est lent, cher, et hostile.

## Checklist
- [ ] Offline-first : l'app fonctionne sans reseau — donnees en cache local, actions en file d'attente
- [ ] Les images sont lazy-loadees et resizees (pas de 4K telecharge sur un ecran 400px de large)
- [ ] La batterie est respectee : pas de polling every 5s, pas de wake lock permanent, pas de GPS continu
- [ ] Le state est preserve a travers les kills d'OS (serialisation automatique du state critique)
- [ ] Les crashs sont reportes (Crashlytics, Sentry) — pas de "ca crash sur le telephone de Julie"
- [ ] Les updates sont gerees : forced update si API incompatible, optional update sinon
- [ ] Le stockage local a un TTL et une limite de taille — pas de cache infini qui remplit le telephone

## Anti-patterns
### Mobile = site web en webview
**Ce qu'on voit :** une webview qui charge le site responsive. Publie sur les stores. "Ca marche sur mobile."
**Pourquoi c'est dangereux :** zero integration native. Pas de push notifications, pas de stockage offline, pas de gestures natives, pas de transition fluide. Les utilisateurs le sentent immediatement et desinstallent. Les stores peuvent rejeter si l'app n'apporte rien par rapport au site.
**Faire plutot :** si le contenu est statique → PWA (plus leger, pas besoin de store). Si besoin natif (push, camera, offline) → app native ou React Native/Flutter avec vrais composants natifs.

### Optimiste sur le reseau
**Ce qu'on voit :** l'app suppose que le reseau est disponible et rapide. Pas de cache, pas de queue offline, pas de gestion d'erreur reseau. L'app affiche un spinner blanc des que le reseau est lent.
**Pourquoi c'est dangereux :** le reseau mobile est le pire reseau de tous les clients. L'utilisateur est dans un ascenseur, un metro, une cave, une campagne. Si l'app ne fonctionne pas offline, elle est inutilisable 30% du temps. L'utilisateur ouvre l'app concurrente.
**Faire plutot :** cache local (SQLite, Realm, WatermelonDB). Sync en arriere-plan quand le reseau est disponible. UI qui montre les donnees en cache immediatement, puis rafraichit. Indicateur "donnees de X minutes" plutot qu'un spinner.

### Release = pari
**Ce qu'on voit :** soumission sur le store sans test de recette. Rejet pour violation de guideline. 3 jours de delai. Corrections en catastrophe.
**Pourquoi c'est dangereux :** le store review est un processus humain, lent, et imprevisible. Un rejet decale la release de 3-7 jours. Les utilisateurs attendent, les bugs critiques restent en production.
**Faire plutot :** pre-release checklist (guidelines store, screenshots, permissions documentees). TestFlight/Internal Testing pour valider le binaire avant soumission. Soumission en debut de semaine pour maximiser les chances de review rapide.

## Patterns
### Offline-first avec sync queue
**Quand :** app qui modifie des donnees (notes, taches, commandes).
**Comment :** ecriture locale immediate → queue de synchronisation → synchro background quand online. Resolution de conflits : last-write-wins pour donnees simples, merge pour donnees complexes. UI qui montre l'etat de synchro (sync, synced, error).

### Gradual rollout sur stores
**Quand :** release avec risque (refonte, nouvelle fonctionnalite).
**Comment :** Play Store : staged rollout (10% → 50% → 100% avec possibilite de halt). App Store : phased release sur 7 jours. Monitoring des crashs et des ratings par version. Rollback en arretant le rollout (pas besoin de nouvelle soumission).
