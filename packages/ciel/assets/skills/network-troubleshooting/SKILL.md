---
name: network-troubleshooting
description: "Network Troubleshooting — 'c'est le reseau' n'est pas un diagnostic. Debug par couche (dig/ping/mtr/ss/tcpdump/curl), modes de panne (MTU blackhole, TIME_WAIT, routage asymetrique), observabilite (flow logs, eBPF/Hubble, P95/P99). A charger quand on debug la connectivite."
---

# Network Troubleshooting

**Principe premier :** "C'est un probleme reseau" est l'enonce qui arrete l'investigation, pas qui la commence. Le reseau est un bouc emissaire facile parce qu'il est invisible — mais la plupart des problemes "reseau" sont une couche precise qui a rompu son contrat : un TTL DNS perime, un MTU blackhole, un pool de connexions epuise, un certificat expire. Debugger un reseau, c'est isoler methodiquement la couche fautive, une promesse a la fois, du bas vers le haut. Et "pas d'erreur dans les logs" n'est jamais une preuve que ca marche : il faut declencher le scenario et observer un signal positif.

## Checklist
- [ ] On teste UNE couche a la fois, de bas en haut, avec l'outil adapte — pas de "redemarre tout et prie"
- [ ] DNS verifie en premier : `dig` (resout ? quel TTL ? cache perime ?) — pas d'hypothese "le DNS est forcement bon"
- [ ] Joignabilite IP + MTU testees : `ping`, puis `ping -M do -s <taille>` pour debusquer un blackhole MTU — pas de blame "lenteur reseau" sans mesure
- [ ] Etat des sockets inspecte : `ss -tanp` (combien de connexions, TIME_WAIT, pool sature ?) — pas d'ignorance de l'epuisement de ports ephemeres
- [ ] Capture ciblee quand le reste echoue : `tcpdump` avec filtre (host/port) — pas de capture aveugle de gigaoctets
- [ ] TLS isole de HTTP : `openssl s_client` (handshake/cert) avant `curl -v` (reponse applicative) — pas de confusion couche transport/applicative
- [ ] Observabilite en place : flow logs (qui parle a qui) + latences en P95/P99 — pas de moyenne qui masque la queue

## Anti-patterns
### "C'est le reseau" (sans preuve)
**Ce qu'on voit :** chaque bug de connexion est blame sur "le reseau". Personne ne debug. Le probleme persiste des semaines.
**Pourquoi c'est dangereux :** l'invisibilite du reseau en fait un coupable commode. En realite c'est presque toujours une couche identifiable : timeout trop court, cache DNS, certificat expire, mauvais endpoint, pool sature. Dire "c'est le reseau" = arreter de chercher la vraie cause.
**Faire plutot :** isoler la couche. `dig` (DNS), `ping`/`traceroute` (IP/routage), `ss` (TCP), `openssl s_client` (TLS), `curl -v` (HTTP). Chaque couche se teste independamment ; le probleme se localise sur une seule.

### Le blackhole MTU diagnostique a l'aveugle
**Ce qu'on voit :** "les petites requetes passent, les grosses pendent" et on cherche cote application pendant des jours.
**Pourquoi c'est dangereux :** c'est la signature d'un blackhole PMTUD — un saut a MTU plus faible plus un ICMP "fragmentation needed" (Type 3 Code 4) filtre. Invisible si on ne connait pas le symptome ; ca touche surtout les tunnels VPN/overlay.
**Faire plutot :** reconnaitre le pattern "petit OK / gros KO". Tester `ping -M do -s 1472` puis reduire jusqu'a ce que ca passe = MTU reelle. Corriger par MSS clamping sur le tunnel, ou debloquer l'ICMP necessaire au PMTUD.

### Moyennes au lieu de percentiles
**Ce qu'on voit :** "la latence reseau est de 20ms en moyenne, tout va bien" — pendant que 5% des utilisateurs subissent 2s.
**Pourquoi c'est dangereux :** la moyenne noie la queue. Les retransmissions TCP, les timeouts de pool, les blackholes intermittents vivent dans le P95/P99, pas dans la moyenne. Un SLO se mesure sur la queue, pas sur le centre.
**Faire plutot :** raisonner en P95/P99 + RTT. Comparer la distribution avant/apres un changement. Une moyenne stable avec un P99 qui explose = un vrai probleme qu'on ne verrait jamais en moyenne.

## Patterns
### Bisection par couche
**Quand :** "A ne joint pas B", cause inconnue.
**Comment :** descendre/remonter la pile pour couper l'espace de recherche en deux. DNS resout-il l'IP attendue ? IP joignable (ping) ? Le chemin va-t-il ou il faut (mtr) ? Le port repond-il (`nc -vz host port`) ? TLS negocie ? HTTP repond ? Chaque "oui" elimine les couches du dessous. On s'arrete au premier "non".

### Chasse a l'epuisement de connexions
**Quand :** erreurs intermittentes sous charge, "connection refused/timeout" qui apparaissent au pic.
**Comment :** `ss -s` pour le total, chercher une montagne de `TIME_WAIT` (churn de connexions courtes) ou un pool applicatif a son maximum. Cause typique : pas de keep-alive, une connexion neuve par requete -> epuisement des ports ephemeres (1024-65535). Corriger par connexions long-vivantes (keep-alive, pooling), pas par bricolage de `tcp_tw_reuse`.

### Observabilite reseau avec flow logs + eBPF
**Quand :** comprendre les flux reels en prod (qui parle a qui, qui est rejete).
**Comment :** VPC flow logs pour les metadonnees L3/4 (source, dest, port, accept/reject — pas le payload). En Kubernetes, Cilium + Hubble capturent les flux en kernel (eBPF) avec les labels pod/namespace/identite, faible overhead. On corele les rejets de flow logs avec les regles de security group pour trouver le flux bloque sans tatonner.
