# Ciel Parking Lot -- Decouvertes fortuites

- [2026-05-25] DISCOVERY: Les projets installés avec une ancienne version de Ciel gardent le hook `user-prompt-submit.sh` obsolète qui dit "Load domain skills via paths: matching files" au lieu de faire la phase detection. Résultat : les skills ne sont jamais invoqués. Pas de mécanisme de sync auto — il faut regénérer le hook manuellement ou ajouter un check de version dans le session-start hook.
