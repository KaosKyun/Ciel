---
name: networking
description: "Networking — DNS, TLS/SSL, HTTP/2/3, VPC, firewall, load balancing. A charger quand on configure des connexions reseau ou qu'on debug des problemes de connectivite."
---

# Networking

## Checklist
- [ ] DNS est configure avec TTL raisonnable (300s pour APEX, 60s pour failover)
- [ ] TLS >= 1.2 partout (pas de TLS 1.0/1.1, pas de SSL)
- [ ] Les certificats sont auto-renouveles (LetsEncrypt, cert-manager)
- [ ] Timeouts explicites sur toutes les connexions (connect, read, request)
- [ ] Les sous-reseaux sont segmentes (DMZ, backend, data)
- [ ] Les firewalls sont restrictifs (deny by default, allow list)
- [ ] Les charges sont reparties (load balancer ou DNS round-robin)

## Anti-patterns
### Timeout infini
**Ce qu'on voit :** `http.get(url)` sans timeout. L'app attend indefiniment la reponse.
**Pourquoi c'est dangereux :** si le service distant est down, l'app accumule des threads bloques. Pool epuise, plus aucune requete ne passe.
**Faire plutot :** `http.get(url, {timeout: 5000})`. Toujours un timeout, jamais infini. Timeout connect < timeout read < timeout request.

### Tout dans le meme sous-reseau
**Ce qu'on voit :** l'API, la DB, Redis, et le bastion sont dans le meme VPC sans segmentation.
**Pourquoi c'est dangereux :** si le bastion est compromis, l'attaquant a un acces direct a la DB. Pas de defense en profondeur.
**Faire plutot :** sous-reseaux separes. Public subnet (load balancer), application subnet (API), data subnet (DB, Redis). Security groups restrictifs entre chaque couche.

### Pas de monitoring reseau
**Ce qu'on voit :** le trafic reseau n'est pas surveille. Les pannes reseau sont detectees par les clients.
**Pourquoi c'est dangereux :** un DDoS peut passer inapercu jusqu'a ce que le service s'arrete.
**Faire plutot :** monitoring des flux (bande passante, erreurs TCP, latence). Alertes sur les anomalies (hausse soudaine de trafic, erreurs TLS).

## Patterns
### Defence in depth
**Quand :** toute architecture reseau.
**Comment :** plusieurs couches de securite. Load balancer (couche 4/7) -> WAF (couche 7) -> API -> DB. Chaque couche filtre et protege la suivante.

### TLS termination
**Quand :** load balancer ou reverse proxy.
**Comment :** le load balancer gere le TLS (certificat, dechiffrement). Le trafic interne (LB -> API) est en HTTP dans le VPC. Le load balancer a un certificat public valide.
