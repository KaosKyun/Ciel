---
name: desktop
description: "Desktop — Electron/Tauri/WPF/Qt, auto-update, code signing, distribution. A charger quand on travaille sur une app desktop."
---

# Desktop

## Checklist
- [ ] Auto-update fonctionnel et teste (ancienne version → nouvelle version)
- [ ] Code signing en place (Apple notarization + Windows Authenticode)
- [ ] L'app est empaquetee pour la distribution (dmg/deb/AppImage pour Linux, dmg pour macOS, msi/exe pour Windows)
- [ ] Les chemins de fichiers sont corrects sur toutes les plateformes (pas de `/` hardcode)
- [ ] La taille du binaire est raisonnable (< 100 Mo, pas 500 Mo pour un Chromium entier)
- [ ] Les permissions sont minimales (pas d'acces fichiers systeme sauf necessaire)

## Anti-patterns
### Electron pour tout
**Ce qu'on voit :** une app simple (timer, todo list) en Electron = 200 Mo pour un Chromium + Node.
**Pourquoi c'est dangereux :** l'app est lourde, lente, consomme de la RAM. Les utilisateurs preferent une alternative native.
**Faire plutot :** Tauri pour le petit perimetre (moteur natif + Rust, < 10 Mo). Electron seulement si l'app est complexe et tire parti de l'ecosysteme web.

### Pas d'auto-update
**Ce qu'on voit :** l'utilisateur doit telecharger manuellement la nouvelle version sur le site web.
**Pourquoi c'est dangereux :** 90% des utilisateurs restent sur l'ancienne version. Les bugs de sécu ne sont jamais patchees.
**Faire plutot :** auto-update via GitHub Releases ou serveur dedie. Verifier au lancement + telechargement en background + installation au prochain redemarrage.

### Code signing absent
**Ce qu'on voit :** Windows SmartScreen bloque l'app. macOS Gatekeeper empeche l'ouverture. L'utilisateur voit "Editeur inconnu".
**Pourquoi c'est dangereux :** taux d'abandon > 50%. Les utilisateurs pensent que l'app est un virus.
**Faire plutot :** certificat code signing. Apple notarization (obligatoire pour macOS). Windows Authenticode. Ca coute ~$100/an, ca rapporte la confiance.

## Patterns
### Tauri pour petit perimetre
**Quand :** app native legere avec UI web. Pas besoin de Node.js dans le runtime.
**Comment :** backend Rust + frontend HTML/CSS/JS. Le moteur natif est le WebView du systeme (pas Chromium embarque). Binaire < 10 Mo.

### Auto-update via GitHub Releases
**Quand :** distribution hors stores (pas Mac App Store / Microsoft Store).
**Comment :** electron-updater ou tauri-updater. Verifie `latest.yml` sur GitHub Releases. Telecharge le delta ou le full. Installe au prochain lancement.
