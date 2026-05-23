---
name: mobile
description: "Mobile — iOS/Android/React Native/Flutter, offline-first, batterie, store review, push notifications. A charger quand on travaille sur une app mobile."
triggers:
  path: "**/*.{swift,kt,java}"
---

# Mobile

## Checklist
- [ ] Offline-first : l'app fonctionne sans reseau (donnees en cache, actions en file d'attente)
- [ ] Les images sont lazy-loadees et resizees (pas de 4K sur un ecran 400px)
- [ ] Le background fetch est espace (pas de wake-up toutes les 30 secondes → batterie)
- [ ] Les permissions sont demandees au moment pertinent (pas tout au lancement)
- [ ] L'APK/IPA est < 50 Mo (ou App Bundle / slicing)
- [ ] Les push notifications sont geres : silent pour sync, visibles pour engagement
- [ ] Le clavier ne masque pas les inputs (keyboard avoidance)
- [ ] Les animations restent fluides (60 fps) — pas de travail lourd sur le main thread

## Anti-patterns
### Tout synchrone, tout le temps
**Ce qu'on voit :** chaque navigation d'ecran declenche un fetch reseau. Pas de cache local.
**Pourquoi c'est dangereux :** en mode avion, l'app est inutile. En tunnel, l'app freeze. L'utilisateur se plaint.
**Faire plutot :** cache local (SQLite, Room, Core Data). L'UI affiche le cache d'abord, puis met a jour avec le reseau. Les mutations sont mises en file d'attente et synchronisees quand le reseau revient.

### Background fetch agressif
**Ce qu'on voit :** `setInterval(fetchNewData, 30000)` — toutes les 30s, meme quand l'app est en background.
**Pourquoi c'est dangereux :** batterie vide en 2h. iOS kill l'app. Android la met en veille forcee.
**Faire plutot :** BGTaskScheduler (iOS) / WorkManager (Android). Espacer les fetches. Utiliser les silent push notifications pour les mises a jour urgentes.

### Pas de gestion d'etat reseau
**Ce qu'on voit :** pas de distinction entre "en chargement", "erreur reseau", "timeout".
**Pourquoi c'est dangereux :** l'utilisateur ne sait pas si l'app est lente, si le reseau est down, ou si le serveur est down.
**Faire plutot :** states explicites : `loading | loaded | error(reason) | offline`. UI adaptee a chaque etat.

## Patterns
### Offline-first queue
**Quand :** l'utilisateur doit pouvoir faire des actions sans reseau.
**Comment :** action → sauvegarder localement → mettre dans une queue. Quand le reseau est dispo → vider la queue. L'UI est instantanee. Si conflit serveur → resoudre et notifier.

### Image pipeline
**Quand :** l'app affiche des images (toujours).
**Comment :** CDN + redimensionnement serveur. Cache local avec TTL. Placeholder + progressive loading. Jamais l'image originale du serveur.

### Keyboard avoidance
**Quand :** tout formulaire avec un champ texte en bas de l'ecran.
**Comment :** `KeyboardAvoidingView` (React Native) ou `.ignoresSafeArea(.keyboard)` (SwiftUI). Le scroll ajuste automatiquement pour que le champ soit visible.
