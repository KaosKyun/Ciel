---
name: servers
description: "Servers — reverse proxy comme défense périmétrique, TLS termination, process management, OS hardening. À charger quand on configure des serveurs."
---

# Servers

**Principe premier :** Un serveur n'est pas la machine où tourne l'app — c'est la première ligne de défense. Ne jamais exposer une application directement. Toujours un reverse proxy devant qui gère TLS, rate limiting, buffering. L'application ne doit voir que du trafic propre et autorisé. Le serveur doit survivre à un reboot, un crash applicatif, et un pic de trafic sans intervention humaine.

## Checklist
- [ ] Reverse proxy devant l'application (Nginx/Caddy/Traefik) — jamais d'exposition directe
- [ ] TLS 1.3 avec certificats auto-renouvelés (LetsEncrypt/cert-manager)
- [ ] Process manager avec restart automatique (systemd) — pas de `node server.js &`
- [ ] Health check endpoint utilisé par le load balancer (liveness ≠ readiness)
- [ ] Firewall : seuls les ports 443 et 80 (redirect) sont ouverts, SSH restreint
- [ ] Log rotation configurée avec retention max — pas de disque plein par les logs

## Anti-patterns
### Application directement exposée
**Ce qu'on voit :** `app.listen(443)` — l'app écoute directement sur le port public. Pas de proxy.
**Pourquoi c'est dangereux :** pas de buffering → un client lent bloque un worker. Pas de rate limiting → pas de protection DDoS basique. Pas de cache statique → chaque requête touche l'app. Le reverse proxy est une couche de défense gratuite.
**Faire plutôt :** Nginx/Caddy en frontal. Il gère TLS, compression, cache statique, rate limiting. L'app écoute sur localhost:3000 et ne voit que du trafic filtré.

### Redémarrage manuel
**Ce qu'on voit :** `node server.js` lancé dans un screen/tmux. Crash → app down jusqu'à intervention humaine.
**Pourquoi c'est dangereux :** tout process crashe un jour. OOM, segfault, exception non catchée. Sans restart automatique, chaque crash = outage non borné. À 3h du matin, personne ne relance.
**Faire plutôt :** systemd avec `Restart=always` et `RestartSec=5`. Le process manager relance en secondes.

### Logs sans rotation
**Ce qu'on voit :** `app.log` qui grossit depuis 6 mois. 50 Go. Le disque se remplit.
**Pourquoi c'est dangereux :** disque plein = tout tombe. L'app ne peut plus écrire, la DB s'arrête. L'outage par manque d'espace disque est le plus évitable de tous.
**Faire plutôt :** logrotate avec retention 30 jours. Alerte si espace disque < 20%. Les logs sont streamés vers un système centralisé, pas stockés localement.

## Patterns
### Reverse proxy
**Quand :** toute application web en production.
**Comment :** Nginx/Caddy en frontal. TLS termination, compression, cache statique, rate limiting. L'applicatif derrière sur localhost uniquement.

### Health check
**Quand :** load balancer ou orchestrateur devant l'app.
**Comment :** `GET /health` → `{"status":"ok","uptime":3600,"db":"connected"}`. Vérifié toutes les 10s. 3 échecs → retirer l'instance du pool.
