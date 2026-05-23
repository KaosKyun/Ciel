---
name: high-availability
description: "Haute Disponibilite — clustering, failover, multi-region, load balancing, replication, SLA. A charger quand on conçoit un systeme haute disponibilite."
triggers:
  path: "**/ha*,**/high-availability*,**/failover*,**/multi-region*,**/replication*,**/sla*"
---

# Haute Disponibilite

## Checklist
- [ ] Le SLA cible est defini (99.9%, 99.99%, 99.999%) et connu de l'equipe
- [ ] Le failover est automatise (pas de bascule manuelle a 3h du mat)
- [ ] L'application est multi-AZ (au moins 2 zones de disponibilite)
- [ ] La base de donnees est en replication (primary/standby ou multi-master)
- [ ] Le load balancing est configure (DNS round-robin, load balancer, anycast)
- [ ] Les points de defaillance uniques (SPOF) sont identifies et elimines
- [ ] Un "chaos" regulier (killing pods, failover test) valide la resilience
- [ ] Les sessions utilisateur sont persistees hors du pod (Redis, DB) — pas d'etat local

## Anti-patterns
### SPOF ignore
**Ce qu'on voit :** 1 serveur de base de donnees, 1 load balancer, 1 instance d'application. Tout est unique.
**Pourquoi c'est dangereux :** le load balancer tombe ? Tout le service est down. La DB crashe ? Tout le service est down. C'est une chaine de points de defaillance.
**Faire plutot :** chaque composant est au moins 2. Multi-AZ. Load balancer redondant. DB primary + standby. Pas de composant en singleton.

### Pas de test de failover
**Ce qu'on voit :** le standby DB est configure depuis 6 mois. Jamais teste. Le jour de la panne, le standby echoue a prendre le relais.
**Pourquoi c'est dangereux :** le failover non teste = le failover ne marche pas. C'est une fausse securite. L'equipe pense etre resilient mais ne l'est pas.
**Faire plutot :** test de failover automatise chaque mois. Kill la primary, verifier que le standby prend le relais. Mesurer le temps de bascule (RTO).

### Application stateful
**Ce qu'on voit :** les sessions utilisateur sont stockees en memoire locale du pod. Si le pod est tue, les sessions sont perdues.
**Pourquoi c'est dangereux :** si le pod est tue (scale down, rolling update, crash), les utilisateurs sont deconnectes. L'experience est degradee. Les donnees en memoire volatile sont perdues.
**Faire plutot :** sessions dans Redis ou la DB. Les pods sont stateless. Un pod peut etre tue et remplace sans perte de donnees utilisateur.

## Patterns
### Multi-AZ deployment
**Quand :** tout service avec SLA > 99.9%.
**Comment :** au moins 2 AZ. Load balancer devant. Auto-scaling group par AZ. La perte d'une AZ = 50% de capacite, pas d'arret total.

### Active/Passive failover
**Quand :** base de donnees ou service critique.
**Comment :** primary (actif) + standby (passif, replication). Monitoring du primary. Si heartbeat perdu : promotion du standby. DNS mis a jour. RTO < 60s.
