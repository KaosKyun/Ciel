---
name: high-availability
description: "Haute Disponibilite — clustering, failover, multi-region, quorum, split-brain, replication, SLA 9s. A charger quand on concoit un systeme haute disponibilite."
---

# Haute Disponibilite

**Principe premier :** La haute disponibilite n'est pas "avoir des serveurs de backup" — c'est concevoir pour la defaillance comme cas nominal. Tout composant va tomber un jour. La question n'est pas "est-ce que ca va tomber ?" mais "quand ca tombe, est-ce que le systeme continue ?". Le SLA (99.9%, 99.99%, 99.999%) n'est pas un objectif de disponibilite — c'est un budget de panne. 99.9% = 8h46min d'indisponibilite par an. 99.99% = 52min. 99.999% = 5min. Chaque 9 supplementaire coute un ordre de grandeur en complexite et en argent. Le vrai defi de la HA n'est pas technique — c'est economique : jusqu'ou vas-tu pour 9 de plus ?

## Checklist
- [ ] Le SLA cible est defini (99.9%, 99.99%, 99.999%) et connu de l'equipe + budget de panne annuel calcule
- [ ] Le failover est automatise (pas de bascule manuelle a 3h du mat) — detection + basculement < SLA
- [ ] Chaque composant est deploye sur au moins 2 zones de disponibilite (ou 2 regions) — pas de SPOF
- [ ] Le quorum est configure correctement (3 ou 5 nœuds, jamais 2) pour eviter le split-brain
- [ ] La replication est monitorisee (lag en secondes) — alerter si lag > seuil
- [ ] Les tests de failover sont executes regulierement (trimestriel) — sans test, la HA est une croyance
- [ ] Le load balancer fait du health checking actif (endpoint applicatif, pas juste TCP connect)

## Anti-patterns
### Cluster a 2 nœuds
**Ce qu'on voit :** 2 serveurs en cluster. Le reseau entre eux coupe. Chacun pense que l'autre est mort et devient primaire → deux primaires → corruption de donnees.
**Pourquoi c'est dangereux :** avec 2 nœuds, aucun quorum n'est possible (majorite = 2/2). En cas de partition reseau, chaque nœud a 50% de chances — pas de majorite. Le split-brain est inevitable. C'est la configuration la plus dangereuse.
**Faire plutot :** minimum 3 nœuds pour un cluster. La majorite est 2/3 → un seul cote de la partition peut avoir le quorum. Pour les systemes a 2 nœuds, utiliser un témoin externe (witness, quorum disk) qui donne la majorite a UN des deux.

### HA = juste dupliquer les serveurs
**Ce qu'on voit :** 2 serveurs d'application derriere un load balancer. "On est HA." La base de donnees est un seul RDS sans Multi-AZ.
**Pourquoi c'est dangereux :** la HA est aussi forte que ton maillon le plus faible. Serveurs app HA + DB single point of failure = la DB tombe, tout tombe. Les utilisateurs voient "error 500", pas "la DB est down". La HA est une propriete du systeme entier, pas d'un composant.
**Faire plutot :** analyser le chemin critique complet. Load balancer (redondant), serveurs app (≥2, multi-AZ), DB (multi-AZ ou cluster), cache (cluster Redis), file d'attente (cluster). Chaque composant doit survivre a la perte d'un nœud. Le test de resilience verifie le systeme entier.

### Pas de test de failover
**Ce qu'on voit :** Multi-AZ configure. Le failover est "automatique". Personne ne l'a jamais declenche volontairement.
**Pourquoi c'est dangereux :** le failover automatique est un systeme complexe : detection de panne, election d'un nouveau primaire, reconfiguration DNS/proxy, reconnection des clients. Chaque etape peut echouer. La premiere fois que le failover est teste ne doit pas etre le jour de la panne reelle.
**Faire plutot :** Game Day trimestriel : on coupe le primaire et on observe le failover. Mesurer le temps de bascule. Verifier que les clients se reconnectent. Verifier que les donnees sont intactes. Documenter ce qui a mal tourne. Le failover non teste = pas de failover.

## Patterns
### Active-Passive avec health check
**Quand :** service avec etat (DB, file system).
**Comment :** un seul nœud actif (ecritures). Un ou plusieurs nœuds passifs (lecture seule ou standby). Health check continu sur l'actif. Si l'actif ne repond plus → promotion du standby le plus a jour via leader election (quorum). Les clients sont redirigés vers le nouveau primaire.

### Multi-AZ stateless
**Quand :** services sans etat (API, workers).
**Comment :** deployer N instances reparties sur ≥2 zones de disponibilite. Load balancer repartit le trafic. Si une AZ tombe, le load balancer envoie tout le trafic vers les autres AZ. Aucune intervention humaine. Le nombre d'instances doit absorber la perte d'une AZ entiere sans saturation.
