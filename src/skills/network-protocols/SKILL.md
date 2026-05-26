---
name: network-protocols
description: "Network Protocols — chaque couche se debug independamment. OSI vs TCP/IP, TCP/UDP, HTTP/1-2-3 & QUIC, IPv4/IPv6, NAT, MTU/PMTUD, BGP/OSPF, DNS. A charger quand on raisonne sur le comportement reel des paquets, le routage ou les protocoles."
---

# Network Protocols

**Principe premier :** Le modele en couches n'est pas une abstraction academique — c'est l'outil de debug le plus puissant qui existe. Chaque couche fait une promesse a celle du dessus et suppose que celle du dessous tient la sienne. Quand "ca ne marche pas", la question n'est jamais "le reseau est casse" mais "quelle couche a rompu son contrat ?". DNS resout-il ? IP route-t-il ? TCP etablit-il ? TLS negocie-t-il ? HTTP repond-il ? On teste UNE couche a la fois, de bas en haut. Connaitre les protocoles, c'est savoir exactement quelle promesse interroger.

## Checklist
- [ ] On sait mapper OSI (7 couches) sur TCP/IP (4 couches) : Link=1-2, Internet/IP=3, Transport/TCP-UDP=4, App=5-7 — TLS est "entre 4 et 7", pas une couche OSI propre
- [ ] Choix TCP vs UDP justifie : TCP pour fiable/ordonne, UDP pour latence/diffusion (DNS, QUIC, voix) — pas "TCP partout par defaut" sans y penser
- [ ] HTTP/2 ou HTTP/3 active cote edge : multiplexing, et HTTP/3 (QUIC sur UDP) supprime le head-of-line blocking de TCP — pas que du HTTP/1.1
- [ ] Dual-stack IPv4 + IPv6 : IPv6 est a ~50% du trafic Google (2026), on ne le desactive PAS — pas de "disable IPv6" comme pretendu durcissement
- [ ] MTU coherente de bout en bout (1500 par defaut) ; jumbo (9000) seulement si CHAQUE saut le supporte — sinon blackhole intermittent
- [ ] MSS clamping en place sur les tunnels (VPN/overlay) pour eviter les blackholes PMTUD — pas d'ICMP "fragmentation needed" filtre aveuglement
- [ ] Records DNS corrects : A/AAAA pour les IP, jamais de CNAME a l'apex ni en cible de MX — pas de CNAME la ou la spec l'interdit

## Anti-patterns
### "TCP est fiable, donc pas besoin de timeout ni de retry"
**Ce qu'on voit :** du code reseau sans timeout, sans retry, sans idempotence. "TCP garantit la livraison."
**Pourquoi c'est dangereux :** TCP garantit l'ordre et la livraison SUR une connexion etablie — pas que la connexion s'etablit, pas que le pair est vivant, pas qu'une connexion half-open/blackholee sera detectee vite. Sans timeout, un appel pend indefiniment ; sans retry, une coupure transitoire devient une erreur utilisateur.
**Faire plutot :** timeouts explicites a chaque couche, retry avec backoff + jitter, idempotence pour rendre les retries surs. TCP keep-alive pour detecter les pairs morts. La fiabilite applicative se construit AU-DESSUS de TCP, pas a sa place.

### Desactiver IPv6 "pour simplifier"
**Ce qu'on voit :** `net.ipv6.conf.all.disable_ipv6=1` partout, presente comme du durcissement.
**Pourquoi c'est dangereux :** IPv6 atteint ~50% du trafic Google (2026) et est majoritaire dans plusieurs pays (France parmi les plus eleves, ~80%). Le desactiver casse Happy Eyeballs, ralentit les connexions, et masque une mauvaise config plutot que de la corriger. Ce n'est pas une mesure de securite, c'est une dette.
**Faire plutot :** dual-stack. Adresser et filtrer IPv6 comme IPv4 (les regles firewall doivent exister pour les deux familles — un oubli IPv6 est un trou). Tester la resolution AAAA.

### Jumbo frames "parce que c'est plus rapide"
**Ce qu'on voit :** MTU 9000 active sur quelques serveurs "pour le debit", sans verifier le chemin complet.
**Pourquoi c'est dangereux :** un seul saut a 1500 (ou un header d'overlay non compte) fait tomber les gros paquets quand ICMP "fragmentation needed" (Type 3 Code 4) est filtre = blackhole PMTUD. Symptome : les petits paquets passent, les gros pendent. Diagnostic infernal.
**Faire plutot :** jumbo seulement sur un fabric controle de bout en bout (stockage, cluster dedie). Sinon 1500. Sur les tunnels, faire du MSS clamping et activer le PMTUD packetization-layer (RFC 4821).

## Patterns
### Debug couche par couche
**Quand :** "le service B ne joint pas le service C".
**Comment :** de bas en haut, une promesse a la fois. `dig` (DNS resout ?) -> `ping`/`ping -M do -s` (IP joint ? MTU OK ?) -> `traceroute`/`mtr` (le routage va ou ?) -> `ss` (socket dans quel etat ?) -> `openssl s_client` (TLS negocie ?) -> `curl -v` (HTTP repond ?). Le probleme est toujours sur UNE couche identifiable.

### BGP dehors, OSPF dedans
**Quand :** reseau avec plusieurs sites/AS ou interconnexion Internet.
**Comment :** BGP (path-vector, inter-AS) est le protocole d'Internet : eBGP entre AS distincts, iBGP a l'interieur (full-mesh ou route reflectors). OSPF (link-state, intra-AS, reconvergence rapide) gere le routage interne d'un site. On superpose iBGP sur un underlay OSPF — chacun son role, ils coexistent.

### Resolution DNS : recursif vs autoritatif
**Quand :** comprendre une latence ou une staleness DNS.
**Comment :** le resolveur recursif fait la marche (root -> TLD -> autoritatif) et cache selon le TTL ; le serveur autoritatif detient les vrais records. Le TTL court (60-120s) ne se met QUE sur les records de failover actif ; les records stables gardent 300-3600s. Un TTL bas partout matraque les resolveurs et fragilise en cas de panne de l'autoritatif.
