---
name: network-security
description: "Network Security — aucune confiance implicite liee a l'emplacement reseau. Zero Trust (NIST SP 800-207), mTLS/SPIFFE, micro-segmentation, firewall stateful vs stateless, Security Groups vs NACL, DDoS, TLS minimum. A charger quand on securise les flux reseau."
---

# Network Security

**Principe premier :** Le perimetre est mort. "Etre sur le reseau interne" n'est plus une preuve de confiance — c'est exactement ce qu'un attaquant obtient en premier. La securite reseau moderne (NIST SP 800-207, Zero Trust) part d'un postulat inverse : le reseau est hostile par defaut, chaque flux est authentifie et autorise par session, et l'emplacement (interne/externe) ne confere aucun privilege. La segmentation n'est pas du confort operationnel, c'est un controle de securite : elle limite le rayon d'explosion. Un bon reseau rend 80% des attaques impossibles avant qu'elles n'atteignent l'application.

## Checklist
- [ ] Deny-all par defaut, ouverture explicite par flux documente (port, source, raison) — pas de "tout ouvert pour ne pas etre bloque"
- [ ] Aucune confiance basee sur l'emplacement reseau : chaque appel inter-service est authentifie (mTLS, JWT, SPIFFE) — pas de "reseau interne de confiance"
- [ ] Micro-segmentation : un segment par charge/tier, deny entre segments sauf flux autorise — pas de mouvement lateral libre
- [ ] Security Groups (stateful) comme controle primaire ; NACL (stateless) en defense en profondeur — on connait la difference avant de debug le trafic de retour
- [ ] TLS 1.3 partout (interne ET externe) ; TLS 1.2 toujours avec AEAD uniquement (AES-GCM/ChaCha20) ; TLS 1.0/1.1 desactives (RFC 8996) — pas de suites CBC/RC4
- [ ] Protection DDoS multi-couche : anycast + scrubbing en L3/4, rate limiting comportemental en L7 — pas de seuil statique seul
- [ ] Identites de service a courte duree de vie (SVID/cert tournants) — pas de cle API statique longue duree en dur

## Anti-patterns
### Le reseau interne "de confiance"
**Ce qu'on voit :** une fois dans le VPC/LAN, les services se parlent sans authentification. "On est derriere le firewall."
**Pourquoi c'est dangereux :** le firewall protege le perimetre, pas l'interieur. Une seule machine compromise (phishing, dependance vulnerable, SSRF) donne acces a tout ce qui fait confiance "au reseau". C'est le scenario de 90% des breches a fort impact : l'attaquant entre par un point faible puis se deplace lateralement sans resistance.
**Faire plutot :** Zero Trust. Chaque flux authentifie (mTLS entre services), autorise par politique dynamique, par session. Les services ne se font pas plus confiance entre eux qu'a Internet. Telemetrie maximale pour detecter l'anormal.

### Firewall comme apres-coup
**Ce qu'on voit :** le firewall est configure "quand tout marche", donc jamais ; tous les ports ouverts "pour debloquer". Les regles n'ont pas de commentaire.
**Pourquoi c'est dangereux :** un port oublie sur une appli vulnerable = porte d'entree. Le firewall INTERNE (entre tiers) est aussi important que l'externe. Des regles sans raison documentee deviennent intouchables ("on n'ose plus rien fermer").
**Faire plutot :** deny-all par defaut, ouverture par flux documente avec commentaire (quel service, pourquoi ce port). Revue trimestrielle. Distinguer stateful (Security Group : autorise le retour automatiquement) de stateless (NACL : penser a ouvrir la plage ephemere 1024-65535 dans les deux sens).

### Seuils DDoS statiques
**Ce qu'on voit :** "on bloque au-dela de X req/s". Une rafale courte de 2-3 min passe sous le radar et sature le service avant le declenchement.
**Pourquoi c'est dangereux :** les attaques 2025-2026 sont concues pour finir avant qu'un seuil statique ne reagisse. Et un seuil trop bas bloque les pics legitimes (lancement, promo).
**Faire plutot :** detection comportementale/automatique (deviation par rapport au profil normal), anycast pour diluer le volumetrique, scrubbing/RTBH en L3-4, rate limiting adaptatif en L7 sur du trafic "valide en apparence".

## Patterns
### Zero Trust (NIST SP 800-207)
**Quand :** services distribues, multi-cloud, teletravail — c'est-a-dire presque partout.
**Comment :** les 7 principes (paraphrase de SP 800-207) : tout est ressource ; toute communication securisee quel que soit l'emplacement ; acces par session ; acces par politique dynamique ; integrite/posture de tous les actifs surveillee ; auth/autz dynamiques et strictement appliquees AVANT acces ; telemetrie maximale pour ameliorer la posture. Pas d'implicite, jamais.

### Identite de service avec SPIFFE/SPIRE
**Quand :** mTLS service-a-service a travers K8s, VMs, multi-cloud.
**Comment :** SPIFFE definit l'identite (un SPIFFE ID), SPIRE l'implemente : il atteste la charge et emet des SVID (cert X.509 ou JWT) a courte duree de vie. Remplace les cles API statiques par une identite cryptographique tournante. mTLS mutuel : chaque pair prouve son identite, aucun secret partage de longue duree.

### Defense en profondeur reseau
**Quand :** architecture multi-services exposee.
**Comment :** WAF/CDN (L7) -> Load Balancer + terminaison TLS -> NACL/firewall de subnet -> Security Group par service. Chaque couche suppose que la precedente a echoue et ne lui fait pas confiance. Aucune couche unique n'est le seul rempart.
