---
name: desktop
description: "Desktop — Electron/Tauri/WPF/Qt, auto-update, code signing, distribution, OS integration. A charger quand on developpe une application desktop."
---

# Desktop

**Principe premier :** Une application desktop n'est pas un site web dans une fenetre — c'est un citoyen de l'OS. L'utilisateur attend des raccourcis clavier, un menu contextuel, des notifications systeme, un comportement au focus/blur, une integration avec le fichier systeme. Si ton app ne respecte pas les conventions de l'OS, l'utilisateur la percoit comme "pas finie" meme si elle fonctionne. Le deuxieme defi est la distribution : contrairement au web ou tu deployes sur un serveur, chaque utilisateur a une copie de ton binaire. Si tu ne peux pas le mettre a jour automatiquement, la version buggee reste en circulation indefiniment.

## Checklist
- [ ] Auto-update fonctionnel et teste (ancienne version → nouvelle version, rollback si echec)
- [ ] Code signing en place (Apple notarization + Windows Authenticode) — pas de "telecharger depuis parametres"
- [ ] L'app respecte les conventions de l'OS : menu natif, raccourcis clavier, drag & drop, notifications
- [ ] Le bundle est minimal : pas de dependances inutiles, pas de fichiers de dev dans le package final
- [ ] Les chemins de fichiers utilisent les API OS (appData, documents, temp) — pas de chemins hardcodes Unix/Windows
- [ ] L'app gere le cycle de vie : focus/blur, sleep/wake, quit/relancer, ouverture de fichier par l'OS
- [ ] Les permissions sont demandees au moment de l'usage, pas au lancement (caméra, mic, fichiers)

## Anti-patterns
### Electron = 500MB pour "Hello World"
**Ce qu'on voit :** une app Electron qui pese 200MB, utilise 500MB de RAM pour afficher un formulaire. "C'est plus facile a developper."
**Pourquoi c'est dangereux :** l'utilisateur compare avec les apps natives (Slack = electron, VS Code = electron... mais eux ont des equipes d'optimisation dediees). Une app Electron non optimisee est percue comme "lente" et de trop. Les utilisateurs desinstallent.
**Faire plutot :** si l'app est simple → Tauri (backend Rust, frontend web, binaire < 5MB). Si Electron : tree-shaking, lazy loading, pas de `nodeIntegration`, pas de `remote` module. Mesurer la RAM et le temps de demarrage a chaque release.

### Pas d'auto-update
**Ce qu'on voit :** l'utilisateur telecharge l'app sur le site web. Version 1.0. Nouvelle version 1.1 → email aux utilisateurs "telechargez la nouvelle version".
**Pourquoi c'est dangereux :** 90% des utilisateurs ne mettront jamais a jour manuellement. Les bugs de la v1.0 restent en circulation pendant des annees. Le support recoit des tickets sur des bugs deja corriges. La fragmentation des versions est un cauchemar.
**Faire plutot :** auto-update integre des le jour 1 (electron-updater, Sparkle pour Mac, Squirrel pour Windows). L'app verifie au demarrage et telecharge en arriere-plan. Mise a jour silencieuse pour les patchs, notification pour les features.

### Ignorer les conventions OS
**Ce qu'on voit :** CTRL+C ne copie pas. CMD+Q ne quitte pas. Le menu est custom et ne ressemble a rien. Les dialogues de fichier sont du HTML custom.
**Pourquoi c'est dangereux :** les utilisateurs ont des annees de memoire musculaire. Chaque violation de convention = friction cognitive. L'utilisateur ne se dit pas "cette app a un design original" — il se dit "cette app est buggee" et retourne a l'alternative native.
**Faire plutot :** utiliser les composants natifs quand ils existent (menu, file dialog, notifications). Les raccourcis clavier standard doivent fonctionner. Tester sur Mac et Windows — les conventions sont differentes.

## Patterns
### Distribution multi-plateforme
**Quand :** app qui cible Windows + Mac + Linux.
**Comment :** CI qui build les 3 plateformes en parallele. Code signing specifique par plateforme (Mac : notarization via `gon`/`electron-notarize`, Windows : Authenticode via Azure Key Vault). Auto-update specifique par plateforme (Sparkle pour Mac, Squirrel.Windows pour Windows, AppImage pour Linux).

### Minimiser la surface d'attaque Electron
**Quand :** toute app Electron.
**Comment :** `contextIsolation: true`, `nodeIntegration: false`, `sandbox: true`. IPC pour la communication main-renderer (pas de `remote`). Preload script minimal : exposer uniquement les API necessaires via `contextBridge`. La renderer process est non fiable — traiter chaque message comme du user input.
