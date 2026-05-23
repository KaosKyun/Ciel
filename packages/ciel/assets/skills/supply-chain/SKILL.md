---
name: supply-chain
description: "Supply Chain Security — dependances, SBOM, signature, provenance, attestation, deprecation. A charger quand on securise la chaine d'approvisionnement logicielle."
---

# Supply Chain Security

## Checklist
- [ ] Les dependances sont epinglees (version exacte, pas de `^` ou `~`)
- [ ] Les checksums des packages sont verifies (lockfile, integrity hash, SRI)
- [ ] L'outil de scan des dependances est actif (Snyk, Dependabot, Renovate, Trivy)
- [ ] Les signatures des commits et des tags sont verifiees (GPG, Sigstore)
- [ ] Un SBOM (Software Bill of Materials) est genere a chaque build
- [ ] Les deprecations sont suivies et planifiees (pas de package non maintenu depuis 2 ans)
- [ ] Les registres de packages sont en lecture seule pour les consommateurs (pas de `npm publish` accidentel)

## Anti-patterns
### Dependances sans verrou
**Ce qu'on voit :** `package.json` avec `"express": "^4.18.0"`, pas de `package-lock.json` dans le repo.
**Pourquoi c'est dangereux :** chaque `npm install` peut donner une version differente. Une mise a jour mineure peut introduire un bug ou une vulnerabilite. Le build n'est pas reproductible.
**Faire plutot :** commit du lockfile. `npm ci` (pas `npm install`) dans la CI. Version exacte pinnee si possible.

### Package abandonne
**Ce qu'on voit :** `left-pad` ou toute dependance non maintenue utilisee en production.
**Pourquoi c'est dangereux :** pas de correctif de securite. Une CVE zero-day ne sera jamais patchee. Le package peut disparaitre du registre.
**Faire plutot :** Renovate ou Dependabot pour detecter les packages non maintenus. Audit regulier. Remplacer les packages abandonnes. Mesurer la "health" des dependances.

### Trop de dependances
**Ce qu'on voit :** un projet Node.js avec 1500 dependances directes + transitives.
**Pourquoi c'est dangereux :** chaque dependance est un point d'entree potentiel. La surface d'attaque est enorme. `event-stream` (copay) et `ua-parser-js` (malware) sont des exemples.
**Faire plutot :** limiter les dependances. Preferer la stdlib. Auditer regulierement. Evaluer le cout securite de chaque nouvelle dependance.

## Patterns
### SBOM automatise
**Quand :** toute application en production.
**Comment :** generer un SBOM (SPDX ou CycloneDX) a chaque build. Avec Trivy ou Syft. Stocker dans un registre. Verifier les CVE connues avant le deploiement.

### Verify provenance (SLSA)
**Quand :** build et deploy automatises.
**Comment :** SLSA Level 2+ : build isole, provenance signee. Les attestations sont generees par le build system. Le consommateur verifie la provenance avant d'utiliser l'artefact.
