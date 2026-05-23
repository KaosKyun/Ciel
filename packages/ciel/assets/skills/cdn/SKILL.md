---
name: cdn
description: "CDN & Edge — cache geographique, TTL strategies, origin shield, edge computing, cache invalidation. A charger quand on configure un CDN ou optimise la livraison de contenu."
---

# CDN & Edge

**Principe premier :** Un CDN n'est pas un "cache rapide" — c'est un reseau de distribution qui rapproche les donnees de l'utilisateur. La latence n'est pas une question de bande passante, c'est une question de distance (lumiere dans la fibre = ~5ms pour 1000km). Un CDN reduit la distance en placant les donnees dans 200+ points de presence. Mais un CDN est aussi un cache — et tout cache peut servir des donnees stale. La question centrale n'est pas "est-ce que le CDN est rapide ?" mais "quelle fraicheur est acceptable pour quel contenu ?"

## Checklist
- [ ] Les assets statiques sont servis via CDN (pas depuis le serveur d'origine) avec Cache-Control explicite
- [ ] Les headers de cache sont differencies par type de contenu : immutable pour versionne, revalidation pour dynamique
- [ ] L'origin shield est configure — pas de 50 POPs qui frappent l'origine simultanement
- [ ] L'invalidation est ciblee (chemins specifiques, pas `/*`) et monitorisee
- [ ] Le TTL est defini selon la fraicheur acceptable : html 5min, assets versionnes 1 an
- [ ] Les tokens/query strings prives ne cassent pas le cache (strip, normalize, ou ignore)
- [ ] Le CDN est devant l'application entiere, pas juste les assets (DDoS protection, SSL termination)

## Anti-patterns
### Tout en `max-age=0, no-cache`
**Ce qu'on voit :** l'equipe a ete brulee par du contenu stale. Solution : tout revalider a chaque requete.
**Pourquoi c'est dangereux :** chaque requete frappe l'origine. Le CDN devient un proxy transparent inutile (cout + latence sans benefice). Le serveur d'origine encaisse 100% du trafic. Le CDN coute de l'argent pour rien.
**Faire plutot :** differencier par type de contenu. Assets versionnes → `max-age=31536000, immutable`. Pages HTML → `max-age=300, stale-while-revalidate=600`. API responses → `max-age=0, private` (pas de cache CDN pour les donnees privees).

### Cache invalidation = `/*`
**Ce qu'on voit :** un deployement → invalidation de tout le cache (`/*`). 50000 requetes simultanees vers l'origine.
**Pourquoi c'est dangereux :** l'invalidation complete cree un "cache stampede" sur l'origine. Le serveur d'origine n'est pas dimensionne pour le trafic total. Chaque deployement = risque d'outage.
**Faire plutot :** invalider uniquement les chemins modifies. Utiliser des noms de fichiers versionnes (`main.a3f2b1c.js`) → jamais besoin d'invalider. Pour les SPA : invalider `index.html` seulement, le reste est immutable.

### CDN = juste pour les images
**Ce qu'on voit :** seuls les assets statiques sont sur le CDN. L'API et les pages HTML passent directement au serveur.
**Pourquoi c'est dangereux :** le CDN offre la terminaison SSL, la protection DDoS, le WAF, l'optimisation d'images, le edge computing. Le mettre uniquement devant `/static/` gaspille sa capacite principale : absorber le trafic malveillant avant qu'il n'atteigne l'origine.
**Faire plutot :** CDN devant tout le domaine. L'origine est cachee derriere le CDN, pas exposee publiquement. Les regles de cache decident ce qui est servi depuis le edge vs l'origine.

## Patterns
### Cache hierarchies (origin shield)
**Quand :** trafic global avec beaucoup de POPs (200+).
**Comment :** un POP regional intermediaire (origin shield) consolide les requetes vers l'origine. Au lieu de 200 POPs qui frappent l'origine sur un cache miss, seul l'origin shield la contacte. Reduction de la charge origine de 100-200x.

### Stale-while-revalidate
**Quand :** contenu qui peut etre legerement stales (pages HTML, reponses API publiques).
**Comment :** `Cache-Control: max-age=300, stale-while-revalidate=600`. Le CDN sert le contenu stales jusqu'a 15 minutes pendant qu'il revalide en arriere-plan. L'utilisateur ne voit jamais la latence de revalidation. Ideal pour les pages qui changent peu.
