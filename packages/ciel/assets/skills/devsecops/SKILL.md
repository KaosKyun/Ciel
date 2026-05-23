---
name: devsecops
description: "DevSecOps — shift-left security, supply chain integrity, SLSA, attestation, SBOM, CVE triage. À charger quand on intègre la sécurité dans le SDLC."
---

# DevSecOps

**Principe premier :** La sécurité n'est pas une étape dans le pipeline — c'est une propriété émergente du système de développement. Le vrai objectif n'est pas "trouver des vulnérabilités" mais "réduire le temps entre l'introduction d'une vulnérabilité et sa détection". Plus ce délai est court, moins la vulnérabilité a de valeur pour un attaquant. Shift-left n'est pas un slogan : chaque heure gagnée réduit la fenêtre d'exposition.

## Checklist
- [ ] SAST bloque sur les vulnérabilités critiques — le pipeline ne passe pas, point
- [ ] Les dépendances sont scannées automatiquement (Snyk/Renovate) avec politique de blocage claire (critique = block, haute = warn + SLA 72h, medium/low = log)
- [ ] Secret scanning au commit (pre-commit hook) ET dans l'historique (push hook, scheduled scan)
- [ ] Les images container sont signées (Sigstore/Cosign) et scannées (Trivy/Grype) — signature ET scan, pas l'un sans l'autre
- [ ] SLSA niveau 2 minimum : provenance attestée, build reproductible, artefacts signés
- [ ] SBOM généré à chaque build (SPDX ou CycloneDX) — consommable par les clients
- [ ] Les IaC et policies sont scannés (Checkov, OPA/Kyverno) — pas juste le code applicatif
- [ ] Les SLA de correction sont mesurés et visibles (critique < 24h, haute < 72h, medium < 30j)

## Anti-patterns
### Sécurité à la fin
**Ce qu'on voit :** SAST lancé une semaine avant la release. 50 CVEs critiques. Release bloquée.
**Pourquoi c'est dangereux :** plus une vulnérabilité est trouvée tard, plus elle coûte cher à corriger — c'est exponentiel. Une CVE trouvée au commit coûte 10 min, trouvée en staging coûte 2h, trouvée en prod coûte 2 jours + incident. Le coût n'est pas le scan — c'est le délai.
**Faire plutôt :** sécurité à chaque commit. SAST dans la CI de la PR. Dependency scan automatique hebdomadaire. Le but : détecter dans les minutes, pas dans les semaines.

### Scanner sans bloquer
**Ce qu'on voit :** Trivy/Dependabot trouvent des CVE, le pipeline reste vert. Les alertes s'accumulent dans une inbox que personne ne lit.
**Pourquoi c'est dangereux :** un scan qui ne bloque pas n'existe pas. Il produit du bruit, et le bruit tue la vigilance. En 6 mois, l'équipe a appris que "rouge" ne veut rien dire — c'est le pire état possible pour un système de sécurité.
**Faire plutôt :** politique de blocage stricte et explicite. Critique = pipeline rouge, merge impossible. Haute = avertissement visible + ticket automatique + SLA. Le seuil monte avec le temps (on commence à medium, puis on resserre).

### SBOM comme case à cocher
**Ce qu'on voit :** un SBOM est généré "parce qu'il faut" mais personne ne le lit, ne le vérifie, ni ne l'utilise en cas d'incident.
**Pourquoi c'est dangereux :** un SBOM non testé est pire que pas de SBOM — il donne une fausse confiance. Le jour où Log4Shell 2.0 sort, tu ne sais pas quels services sont affectés en < 1h. Le SBOM doit être utilisable en incident.
**Faire plutôt :** SBOM versionné avec le build, stocké dans un registre requêtable. Test d'audit trimestriel : "Simule une CVE sur le package X. En combien de temps identifies-tu tous les services affectés ?" Si > 10 min, le SBOM n'est pas opérationnel.

## Patterns
### Shift-left par étapes
**Quand :** organiser la sécurité sans tout casser.
**Comment :** 3 niveaux de maturité. Niveau 1 : secret scan au push, lint de sécurité en CI. Niveau 2 : SAST + dependency scan bloquants, OIDC. Niveau 3 : SLSA build attestation, SBOM signé, policy-as-code en déploiement. On monte d'un niveau par trimestre — pas tout d'un coup.

### Security Champions
**Quand :** équipe sans security engineer dédié.
**Comment :** 1 dev par équipe formé à la sécurité (OWASP, threat modeling, revue de dépendances). Ce n'est pas un rôle full-time — c'est un point de contact. Le champion fait la review de sécurité des PRs de son équipe, escalade à l'équipe sécurité centrale pour les cas complexes. La connaissance se diffuse — en 1 an, toute l'équipe monte en compétence.
