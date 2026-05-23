---
name: cdn
description: "CDN & Edge — CloudFront/CloudFlare/Fastly, cache policies, edge computing, origin shield. A charger quand on configure un CDN ou qu'on optimise la livraison de contenu."
---

# CDN & Edge

## Checklist
- [ ] Les assets statiques sont servis via CDN (pas directement depuis le serveur d'origine)
- [ ] Les headers Cache-Control sont correctement configures (`public, max-age=31536000, immutable`)
- [ ] Les filenames sont hashes (cache busting : `style.a1b2c3.css`)
- [ ] Le CDN est configure pour servir depuis la region la plus proche de l'utilisateur (edge locations)
- [ ] L'origin shield est active (le CDN ne tape pas directement l'origine pour chaque miss)
- [ ] Le purge de cache est automatise (deploiement -> purge des cles stale)
- [ ] Les certificates TLS sont valides et configures sur le CDN

## Anti-patterns
### Pas de cache-control
**Ce qu'on voit :** les assets statiques sont servis sans header `Cache-Control`.
**Pourquoi c'est dangereux :** le navigateur et le CDN telechargent les fichiers a chaque requete. Temps de chargement 3x plus long. Cout bande passante multiplie par 10.
**Faire plutot :** `Cache-Control: public, max-age=31536000, immutable` pour les fichiers avec hash dans le nom. `Cache-Control: public, max-age=0, must-revalidate` pour le HTML.

### Cache des pages dynamiques sans prevoir l'invalidation
**Ce qu'on voit :** une page HTML mise en cache au CDN sans mecanisme d'invalidation. La page mise a jour n'est pas servie.
**Pourquoi c'est dangereux :** les utilisateurs voient une page perimee depuis des heures. L'equipe vide le cache manuellement a chaque deploiement.
**Faire plutot :** cache court (max-age=60) pour les pages souvent modifiees. Invalidation automatique via API CDN au deploiement. Cache long seulement pour les assets immutables.

### Pas d'origin shield
**Ce qu'on voit :** 100 edge locations qui tapent directement l'origine pour un miss de cache.
**Pourquoi c'est dangereux :** l'origine recoit 100 requetes simultanees au lieu d'une seule. Cache stampede sur le serveur d'origine.
**Faire plutot :** origin shield. Un edge central (shield) fait le miss vers l'origine. Les autres edges servent depuis le shield.

## Patterns
### Cache busting
**Quand :** deploiement de nouveaux assets.
**Comment :** nommer les fichiers avec un hash du contenu : `style.a1b2c3.css`. Cache-Control immutable. Quand le contenu change, le nom change -> nouvelle requete, nouveau cache.

### Origin shield
**Quand :** CDN avec beaucoup d'edge locations.
**Comment :** un point de presence central (shield) est le seul qui tape l'origine. Les autres edges tapent le shield. Reduit la charge sur l'origine.
