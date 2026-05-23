---
name: backup-recovery
description: "Backup & Recovery — RPO, RTO, sauvegarde, restore, retention, plan de reprise, test de restore. A charger quand on configure les sauvegardes."
triggers:
  path: "**/backup*,**/restore*,**/disaster*,**/drp*,**/wal*,**/dump*,**/pg_dump*"
---

# Backup & Recovery

## Checklist
- [ ] RPO (Recovery Point Objective) et RTO (Recovery Time Objective) sont definis
- [ ] Les sauvegardes sont automatisees (pas de backup manuel le vendredi soir)
- [ ] La retention est definie et appliquee (quotidien 30j, hebdo 6 mois, mensuel 1 an)
- [ ] Les sauvegardes sont stockees dans une region differente de la production
- [ ] Le chiffrement des sauvegardes est actif (AES-256, KMS)
- [ ] Le test de restore est fait regulierement (au moins 1x/mois)
- [ ] Le plan de reprise (DRP) est documente et connu de l'equipe
- [ ] L'alerte est configuree si une sauvegarde echoue

## Anti-patterns
### Backup jamais teste
**Ce qu'on voit :** les sauvegardes tournent tous les jours depuis 2 ans. Personne n'a jamais tente de restore.
**Pourquoi c'est dangereux :** le jour du sinistre, le fichier est corrompu, le format est incompatible, les permissions sont erronees. 2 ans de fausse confiance.
**Faire plutot :** test de restore automatise tous les mois. Restauration sur un environnement isole. Verification de l'integrite des donnees. Le backup n'existe que si le restore marche.

### RPO non defini
**Ce qu'on voit :** sauvegarde complete tous les soirs a 23h. Mais la DB contient des transactions critiques en continu.
**Pourquoi c'est dangereux :** si la panne survient a 22h59, on perd 24h de donnees. Le RPO est de 24h sans que personne l'ait decide.
**Faire plutot :** RPO explicite : 1h pour les donnees critiques (WAL archiving, PITR), 24h pour les donnees non critiques (backup quotidien). Le RPO determine la strategie.

### Pas de plan de reprise
**Ce qu'on voit :** "si le serveur plante, on rebuild a la main". Pas de procedure documentee.
**Pourquoi c'est dangereux :** le jour J, la panique. On oublie une etape. Le restore echoue. Le downtime est multiplie par 10.
**Faire plutot :** DRP documente. Etapes : 1. Provisionner nouveau serveur. 2. Installer les dependances. 3. Restaurer le backup. 4. Verifier l'integrite. 5. Basculer le DNS. Teste annuellement.

## Patterns
### 3-2-1 Rule
**Quand :** toute donnee critique.
**Comment :** 3 copies des donnees, 2 supports differents (SSD + cloud), 1 copie hors site (autre region). Exemple : production + backup local + backup cloud region B.

### PITR (Point In Time Recovery)
**Quand :** base de donnees avec transactions critiques.
**Comment :** WAL archiving (PostgreSQL), binlog (MySQL). Permet de restaurer a n'importe quelle seconde. RPO < 1 min. Combine avec backup quotidien.
