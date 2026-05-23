---
name: devsecops
description: "DevSecOps — securite dans le pipeline CI/CD, SAST, DAST, dependency scanning, secret scanning. A charger quand on integre la securite dans le pipeline."
triggers:
  path: "**/devsecops*,**/sast*,**/dast*,**/dependency-check*,**/snyk*,**/trivy*"
---

# DevSecOps

## Checklist
- [ ] SAST (Static Analysis Security Testing) dans la CI — bloque sur vulnerabilite critique
- [ ] DAST (Dynamic Analysis Security Testing) sur l'environnement de staging
- [ ] Scan des dependances (Snyk, Dependabot, Renovate) automatise et bloque sur CVE haute
- [ ] Secret scanning (tokens, cles, mots de passe) dans le code et l'historique git
- [ ] Les images container sont scannees (Trivy, Docker Scout, Grype)
- [ ] Les IaC (Terraform, K8s) sont analyses (Checkov, tfsec, Kubesec)
- [ ] Les politiques de securite sont definies (OPA, Kyverno) appliquees a chaud

## Anti-patterns
### Securite a la fin
**Ce qu'on voit :** le scan de securite est fait 2 jours avant la mise en production. 50 vulnerabilites critiques.
**Pourquoi c'est dangereux :** la release est bloquee. L'equipe est en crise. Les corrections sont faites dans la panique.
**Faire plutot :** securite dans la CI des le premier commit. Chaque PR est analysee. Les vulnerabilites sont corrigees dans le sprint, pas a la fin.

### Scan sans blocage
**Ce qu'on voit :** Trivy/Dependabot trouve des CVE mais le pipeline continue. Les alertes sont ignorees.
**Pourquoi c'est dangereux :** les vulnerabilites s'accumulent. Personne ne les regarde. Le scan devient du bruit.
**Faire plutot :** le pipeline BLOQUE sur vulnerabilite critique ou haute. Medium = avertissement. Low = ignore. SLAs : critique < 24h, haute < 72h.

### Secret dans le code
**Ce qu'on voit :** `const API_KEY = "sk-1234..."` commit dans le repo. Meme supprime, il est dans l'historique.
**Pourquoi c'est dangereux :** le secret est expose a tous les devs, dans l'historique git, potentiellement public. Rotation immediate necessaire.
**Faire plutot :** env vars, secret manager (AWS Secrets Manager, Vault), ou .env jamais commit. GitLeaks ou ggshield dans la CI pour detecter les secrets avant le commit.

## Patterns
### Shift left
**Quand :** toute organisation DevSecOps.
**Comment :** deplacer la securite le plus tot possible dans le cycle de developpement. SAST a la PR, secret scan au commit, dependency scan au build. Pas d'attente pour la securite.

### Security Champions
**Quand :** equipe sans expert securite dedie.
**Comment :** 1 membre par equipe forme a la securite. Revue de securite des PR. Pont entre l'equipe et l'equipe securite. Connaissance diffusee dans l'equipe.
