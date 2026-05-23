---
name: supply-chain
description: "Supply Chain Security — dépendances comme surface d'attaque, lockfile integrity, SBOM, SLSA provenance, signed commits. À charger quand on sécurise la chaîne d'approvisionnement."
---

# Supply Chain Security

**Principe premier :** Chaque dépendance est une backdoor potentielle. La sécurité de la supply chain ne consiste pas à auditer chaque package — c'est impossible. Elle consiste à réduire la surface d'attaque (moins de dépendances), garantir la reproductibilité (lockfiles, pinning), et créer de la traçabilité (SBOM, provenance). Le jour où une CVE sort (et elle sortira), tu dois pouvoir répondre en < 1h à la question : "quels services utilisent ce package ?"

## Checklist
- [ ] Les dépendances sont épinglées (version exacte ou lockfile commité) — build reproductible
- [ ] Le nombre de dépendances est surveillé comme une métrique de risque — chaque ajout est justifié
- [ ] SBOM généré à chaque build (SPDX ou CycloneDX) et requêtable en cas d'incident
- [ ] SLSA niveau 2 minimum : build isolé, provenance attestée, artefacts signés
- [ ] Les dépendances non maintenues sont identifiées et remplacées proactivement
- [ ] Les signatures de commits et tags sont vérifiées — pas de "verified" sur un seul commit sur 100

## Anti-patterns
### Dépendance non épinglée
**Ce qu'on voit :** `"express": "^4.18.0"` dans package.json, pas de lockfile dans le repo. Chaque `npm install` peut installer une version différente.
**Pourquoi c'est dangereux :** un build non reproductible est un build non auditable. Si un attaquant compromet une version mineure de express, ton build l'installe silencieusement. Le hash de ton artefact change sans que tu saches pourquoi.
**Faire plutôt :** lockfile commité dans le repo. `npm ci` (pas `npm install`) dans la CI. Version exacte pinnée pour les dépendances critiques. Le lockfile est ta déclaration de ce qui tourne en production — traite-le comme tel.

### Dépendance comme choix gratuit
**Ce qu'on voit :** `npm install left-pad` pour une fonction de 11 lignes. `npm install is-odd` pour `n % 2 === 1`. 1500 dépendances au total.
**Pourquoi c'est dangereux :** chaque dépendance est un vecteur d'attaque et une dette de maintenance. `event-stream` (2018) a été compromis pour voler des bitcoins. `ua-parser-js` (2021) a été infecté par un malware. Plus tu as de dépendances, plus ta surface d'attaque est grande.
**Faire plutôt :** évaluer chaque dépendance avant de l'ajouter : est-ce que ça fait plus de 50 lignes de logique non-triviale ? Est-ce maintenu (dernier commit < 6 mois) ? Combien de maintainers ? Préférer la stdlib ou copier 10 lignes (attribuées) plutôt qu'une dépendance pour une fonction triviale.

### SBOM inutilisable en incident
**Ce qu'on voit :** un SBOM est généré, stocké dans un artefact de build que personne ne sait requêter. Le jour J, retrouver les services affectés prend 4h.
**Pourquoi c'est dangereux :** un SBOM qui n'est pas utilisable en incident est du théâtre de sécurité. Log4Shell a montré que les équipes qui avaient un SBOM requêtable ont patché en heures. Les autres en semaines.
**Faire plutôt :** SBOM versionné, stocké dans un registre central requêtable. Test d'audit trimestriel : "Simule une CVE sur le package X. Chronomètre le temps pour lister tous les services affectés." Si > 10 min, le processus est cassé.

## Patterns
### SBOM comme produit
**Quand :** toute application en production.
**Comment :** génération automatisée via Syft/Trivy dans la CI. Format SPDX ou CycloneDX. Stockage dans un registre (Dependency-Track, OWASP). API pour requêter "quels services utilisent log4j ?" en une requête. Le SBOM est un livrable, pas un sous-produit.

### SLSA provenance
**Quand :** consommateurs qui ont besoin de vérifier l'origine de l'artefact.
**Comment :** SLSA niveau 2 : build isolé (pas d'accès au réseau arbitraire), provenance signée (attestation du build system). Le consommateur vérifie la signature avant d'utiliser l'artefact. Le but : empêcher qu'un build compromis produise un artefact qui a l'air légitime.
