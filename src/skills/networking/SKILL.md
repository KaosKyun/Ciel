---
name: networking
description: "Networking — le reseau comme fondation invisible. DNS, TLS, HTTP/2/3, VPC, firewall, load balancing. A charger quand on configure des connexions ou debug la connectivite."
---

# Networking

**Principe premier :** Le reseau n'est pas "ce qui connecte les machines" — c'est la couche de securite zero. Avant que ton application ne recoive un octet, le reseau a deja pris 100 decisions : routage, filtrage, terminaison TLS, rate limiting. Un reseau bien configure rend 80% des attaques impossibles avant meme qu'elles n'atteignent l'application. Le probleme inverse : un reseau mal configure est invisible jusqu'a l'incident — "pourquoi le service B ne peut pas parler au service C en prod ?" La connectivite n'est jamais acquise — elle est configuree, testee, monitorisee.

## Checklist
- [ ] DNS est configure avec TTL raisonnable (300s pour APEX, 60s pour failover) — pas de TTL de 86400s
- [ ] TLS >= 1.2 partout, TLS 1.3 pour les services internes — pas de TLS 1.0/1.1, pas de SSL
- [ ] Les certificats sont auto-renouveles (LetsEncrypt, cert-manager, ACM) — pas d'expiration surprise
- [ ] Firewall : seuls les ports necessaires sont ouverts. SSH (22) restreint par IP source
- [ ] Les VPC/VNET sont isoles par environnement (dev/staging/prod) avec peering explicite
- [ ] HTTP/2 ou HTTP/3 active — multiplexing, header compression, 0-RTT
- [ ] Le load balancer a un health check actif (pas juste TCP connect — verifier le endpoint)

## Anti-patterns
### "C'est un probleme reseau"
**Ce qu'on voit :** chaque bug de connexion est blame sur "le reseau". Personne ne debug. Le probleme persiste 3 semaines.
**Pourquoi c'est dangereux :** le reseau est un bouc emissaire facile parce qu'il est invisible. En realite, la plupart des problemes "reseau" sont des problemes d'application : timeout trop court, DNS cache, certificat expire, mauvais endpoint. Dire "c'est le reseau" sans preuve = arreter de chercher.
**Faire plutot :** debug methodique : `dig` (DNS), `curl -v` (TLS + HTTP), `traceroute` (routage), `telnet host port` (connectivite brute). Chaque couche se teste independamment. Le probleme est toujours sur UNE couche specifique.

### Firewall = apres coup
**Ce qu'on voit :** le firewall est configure "quand tout marche" (jamais). Tous les ports sont ouverts "pour pas etre bloque".
**Pourquoi c'est dangereux :** le firewall est la premiere ligne de defense. Sans regles strictes, une application vulnerable sur un port oublie = acces non autorise. Le firewall interne (entre services) est aussi important que l'externe.
**Faire plutot :** deny-all par defaut. Ouvrir uniquement les flux documentes. Chaque regle a un commentaire (pourquoi ce port, pour quel service). Revue trimestrielle des regles.

### DNS comme apres-pensee
**Ce qu'on voit :** TTL = 86400 (24h). Changement de serveur → 24h de propagation. Les utilisateurs voient l'ancienne IP. Ou pire : `CNAME` court-circuite avec un `A` record parce que "c'est plus simple".
**Pourquoi c'est dangereux :** DNS est le premier maillon de toute connexion. Un TTL trop long empeche le failover rapide. Un mauvais enregistrement = outage total. Le DNS est la fondation — tout repose dessus.
**Faire plutot :** TTL courts pour les endpoints critiques (60-300s). Records A/AAAA pour la racine, CNAME pour les sous-domaines. Monitoring de resolution DNS depuis plusieurs points geographiques.

## Patterns
### Defense en profondeur reseau
**Quand :** architecture multi-services.
**Comment :** WAF/CDN (couche 1) → Load Balancer + TLS termination (couche 2) → Network ACL/VPC firewall (couche 3) → Security Group par service (couche 4). Chaque couche suppose que la precedente a echoue. Aucune couche ne fait confiance a la precedente.

### Zero Trust networking
**Quand :** services distribues, multi-cloud, ou travailleurs distants.
**Comment :** pas de "reseau interne de confiance". Chaque appel est authentifie (mTLS, JWT, SPIFFE). Le reseau est hostile par defaut — les services ne se font pas plus confiance entre eux qu'a Internet. C'est le principe inverse du "perimetre de securite".
