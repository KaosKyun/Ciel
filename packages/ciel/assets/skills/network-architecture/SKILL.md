---
name: network-architecture
description: "Network Architecture — le plan d'adressage est un contrat irreversible. Topologies, segmentation, subnetting/CIDR, spine-leaf, hub-and-spoke vs transit gateway, connectivite hybride. A charger quand on concoit la structure d'un reseau ou un schema d'adressage."
---

# Network Architecture

**Principe premier :** Un reseau se concoit avant le premier paquet, pas pendant l'incident. Le plan d'adressage (CIDR) est la decision la plus irreversible de toute l'infra : deux VPC qui se chevauchent ne pourront JAMAIS etre peeres, et re-adresser un reseau en production est un projet de plusieurs mois. La topologie (qui parle a qui) determine ta surface d'attaque, ton cout d'egress, et ta capacite a scaler. Concevoir un reseau, c'est figer des frontieres : segments, zones de confiance, points de jonction. Ces frontieres sont faciles a poser sur un schema vierge et atroces a deplacer plus tard.

## Checklist
- [ ] Plan d'adressage documente AVANT le premier deploiement : blocs non-chevauchants, marge de croissance (un /16 par region, des /24 par subnet) — pas d'allocation ad hoc
- [ ] Plages RFC 1918 reparties par usage : `10/8` pour les VPC, on laisse `172.16/12` libre pour Docker/K8s (collisions d'overlay) — pas de `192.168.0.0/24` partout
- [ ] Segmentation par zone de confiance : public / app / data, chaque tier dans son subnet — pas de "flat network" ou tout est joignable
- [ ] Subnets prives pour tout ce qui n'a pas besoin d'IP publique ; sortie via NAT/proxy — pas d'IP publique par defaut
- [ ] Au-dela de ~3 VPC : hub-and-spoke via Transit Gateway / Azure vWAN, pas un maillage de peerings — pas de mesh N(N-1)/2
- [ ] Connectivite hybride dimensionnee : VPN IPsec pour le rapide/variable, Direct Connect/ExpressRoute pour la latence constante — pas de VPN pour du trafic critique haut debit
- [ ] Chaque frontiere reseau a un proprietaire et une raison documentee — pas de subnet orphelin

## Anti-patterns
### Le reseau plat (flat network)
**Ce qu'on voit :** un seul grand subnet, tout le monde peut joindre tout le monde. "On segmentera plus tard."
**Pourquoi c'est dangereux :** aucune barriere au mouvement lateral — une machine compromise = tout le reseau compromis. La segmentation retroactive casse des flux qu'on ne connait plus. Le "plus tard" n'arrive jamais avant l'incident.
**Faire plutot :** segmenter des le depart par tier (public/app/data) et par environnement. Le trafic inter-segment passe par un point de controle explicite (firewall, security group). Deny par defaut entre segments.

### CIDR qui se chevauchent
**Ce qu'on voit :** chaque equipe cree son VPC en `10.0.0.0/16`. Le jour ou il faut les connecter, c'est impossible.
**Pourquoi c'est dangereux :** deux reseaux avec des plages identiques ne peuvent pas etre routes l'un vers l'autre (le routage devient ambigu). Le peering, le TGW, le VPN site-to-site refusent les CIDR chevauchants. C'est irreversible sans re-adressage complet.
**Faire plutot :** une IPAM centrale (meme un simple tableau) qui alloue des blocs non-chevauchants. Reserver de grandes plages par region/compte, decouper en sous-blocs. Penser 5 ans en avant : l'espace d'adressage est gratuit, le re-adressage est hors de prix.

### Le maillage de peerings
**Ce qu'on voit :** 8 VPC relies par peering point-a-point. 28 connexions a gerer, et le peering n'est pas transitif (A-B + B-C ne donne pas A-C).
**Pourquoi c'est dangereux :** explosion combinatoire N(N-1)/2, routes a maintenir manuellement, aucune visibilite centrale. Ajouter un VPC = reconfigurer tous les autres.
**Faire plutot :** Transit Gateway (AWS) / Virtual WAN (Azure) en etoile des ~3 VPC. N attachements au lieu de N(N-1)/2, routage transitif, HA regionale native, point central pour le VPN et Direct Connect. Le TGW vit dans un compte "Network Services" partage.

## Patterns
### Spine-leaf (Clos) pour le datacenter
**Quand :** datacenter ou fabric ou >70% du trafic est est-ouest (serveur a serveur).
**Comment :** deux niveaux, chaque leaf connecte a chaque spine, ECMP — tous les liens actifs, pas de Spanning Tree qui bloque la moitie de la bande passante. Latence previsible (toujours 2 sauts entre deux serveurs), scaling horizontal par ajout de spines. Le 3-tier core/agg/access avec STP est legacy : il sature en nord-sud et gaspille les liens redondants.

### Hub-and-spoke avec services partages
**Quand :** multi-VPC/multi-compte, besoin de mutualiser egress, DNS, inspection.
**Comment :** un VPC/hub central porte les services communs (NAT, resolveurs DNS, firewall d'inspection, endpoints), les spokes (app) y routent leur trafic via le TGW. Centralise le controle et le cout, isole les charges applicatives. Les spokes ne se parlent qu'a travers le hub si la politique l'exige.

### Connectivite hybride en double chemin
**Quand :** liaison on-premise <-> cloud pour de la prod.
**Comment :** Direct Connect/ExpressRoute (circuit dedie, latence et debit constants, egress moins cher) comme chemin primaire, VPN IPsec sur Internet comme secours chiffre. BGP arbitre le basculement. On ne met jamais un seul chemin sur une liaison critique.
