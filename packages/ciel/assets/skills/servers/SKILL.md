---
name: servers
description: "Servers — Nginx/Caddy/reverse proxy, TLS termination, process management (systemd/PM2), health checks, OS hardening. A charger quand on configure des serveurs."
triggers:
  path: "**/nginx*,**/Caddyfile,**/pm2*,**/systemd*"
---

# Servers

## Checklist
- [ ] Un reverse proxy est devant l'application (Nginx, Caddy, Traefik)
- [ ] TLS est configure (certificat LetsEncrypt ou similaire, avec renouvellement automatique)
- [ ] Le process manager redemarre automatiquement en cas de crash (systemd, PM2)
- [ ] Health check endpoint est defini et utilise par le load balancer
- [ ] Les ports non utilises sont fermes (firewall, iptables)
- [ ] Les logs sont rotates (logrotate, retention max 30 jours)
- [ ] Le serveur est durci : SSH key only, pas de root login, fail2ban
- [ ] Le monitoring du serveur est en place (CPU, RAM, disque, network)

## Anti-patterns
### App exposée directement
**Ce qu'on voit :** l'application Node/Go/Python ecoute directement sur les ports 80/443.
**Pourquoi c'est dangereux :** pas de TLS termination centralisee, pas de rate limiting, pas de buffering, pas de cache. L'app est exposee a tout.
**Faire plutôt :** Nginx en reverse proxy devant l'app. Nginx gere TLS, static files, rate limiting, buffering. L'app ne voit que du trafic interne.

### Pas de redemarrage automatique
**Ce qu'on voit :** le process est lance avec `node server.js` ou `./myapp` directement.
**Pourquoi c'est dangereux :** un crash (OOM, segfault, exception non catchée) = l'app reste down jusqu'a intervention humaine.
**Faire plutôt :** systemd ou PM2. `systemctl enable myapp`, `PM2 startup`. En cas de crash, redemarrage automatique en < 1s.

### Pas de rotation de logs
**Ce qu'on voit :** l'application loggue dans un fichier qui grossit indefiniment.
**Pourquoi c'est dangereux :** a 50 Go, le disque est plein. Le serveur s'arrete. Tout le service est down pour une question de logs.
**Faire plutôt :** logrotate configure. Logs comprimes apres rotation. Retention 30 jours max. Alerte si espace disque < 20%.

## Patterns
### Reverse proxy pattern
**Quand :** toute application web en production.
**Comment :** Nginx ou Caddy en frontal. Gere TLS, compression, cache statique, rate limiting, buffering. L'applicatif derriere sur localhost.

### Health check endpoint
**Quand :** load balancer ou orchestrateur (K8s, Nomad) devant l'app.
**Comment :** `GET /health` → `{"status":"ok","uptime":3600,"db":"connected"}`. Le load balancer verifie toutes les X secondes. Si 3 echecs consecutifs, l'instance est retiree du pool.
