---
name: backup-recovery
description: "Backup & Recovery — RPO/RTO, PITR, disaster recovery, multi-region, test de restore. A charger quand on configure les sauvegardes."
---

# Backup & Recovery

**Principe premier :** Une sauvegarde n'est pas une copie de donnees — c'est une police d'assurance, et comme toute assurance, tu ne sais pas si elle marche tant que tu n'as pas fait de sinistre. La question n'est pas "est-ce qu'on a des backups ?" (oui, tout le monde en a) — c'est "a quelle date etait le dernier test de restore ?" Un backup jamais teste n'est pas un backup, c'est un vœu pieux. Les deux metriques qui definissent ta strategie sont le RPO (Recovery Point Objective : combien de donnees tu acceptes de perdre, en temps) et le RTO (Recovery Time Objective : combien de temps pour restaurer le service). Tout le reste — outils, frequence, retention — decoule de ces deux nombres.

## Checklist
- [ ] RPO (perte de donnees max acceptable) et RTO (temps de restore max acceptable) sont definis et documentes
- [ ] Les backups sont automatises — pas de "je fais un pg_dump le vendredi soir"
- [ ] Le restore est teste regulierement (minimum trimestriel) — sans test, pas de backup
- [ ] Les backups sont stockes dans une region/separee differente de la production (pas dans le meme datacenter)
- [ ] La retention est definie : journaux 30j, mensuels 12 mois, annuels 7 ans (selon conformite)
- [ ] Les backups sont chiffres au repos et en transit — une fuite de backup = fuite de toutes les donnees
- [ ] Le processus de restore est documente et testable par n'importe quel membre de l'equipe

## Anti-patterns
### Backup = dump periodique
**Ce qu'on voit :** `pg_dump` tous les jours a 3h du matin. "On a une sauvegarde." RPO = 24h. Restore = manuel, non teste.
**Pourquoi c'est dangereux :** un pg_dump quotidien = tu perds jusqu'a 24h de donnees. Le restore prend des heures (charger un dump complet). Pas de PITR (point-in-time recovery) — si la corruption est arrivee a 14h, tu ne peux pas restaurer a 13h59, seulement a 3h du matin.
**Faire plutot :** WAL archiving continu (PostgreSQL) ou binlog (MySQL) → PITR possible a la seconde pres. Backups complets hebdomadaires + incrementaux quotidiens ou continus. Restore PITR teste automatiquement.

### Backup dans la meme region
**Ce qu'on voit :** backups dans le meme S3 bucket, meme region, meme compte. "C'est plus simple a gerer."
**Pourquoi c'est dangereux :** la region tombe (panne AWS, coupure electrique, catastrophe naturelle) → tous les backups sont inaccessibles. Un attaquant compromet le compte → il supprime tout, backups inclus. Le backup co-localise n'est pas un backup — c'est une copie.
**Faire plutot :** backups cross-region minimum. Idealement cross-cloud pour les donnees critiques. Les backups sont dans un compte separe avec acces minimal. Immutable backups (Object Lock, WORM) : meme l'admin ne peut pas supprimer avant la retention.

### "Le restore a marche en staging il y a 6 mois"
**Ce qu'on voit :** le test de restore a ete fait une fois, lors de la mise en place. Depuis, le schema a change, les volumes ont triple, l'equipe a tourne.
**Pourquoi c'est dangereux :** un restore est un processus complexe : restaurer la DB, verifier l'integrite, re-configurer les connexions, re-chauffer les caches, valider les donnees. Chaque changement dans le schema, les dependances, ou l'infrastructure peut casser le restore. Un restore qui echoue le jour du sinistre = pas de restore du tout.
**Faire plutot :** restore automatise hebdomadaire dans un environnement isole. Tests d'integrite automatiques apres restore. L'alerte part si le restore echoue. Le test de restore fait partie de la sante operationnelle, comme un health check.

## Patterns
### Strategie 3-2-1
**Quand :** toute strategie de backup.
**Comment :** 3 copies des donnees, sur 2 types de media differents, dont 1 copie hors site (offsite). Exemple : backup local (rapide a restaurer) + backup cloud (region A) + backup cloud (region B, immuable). Une panne ou corruption sur un seul media ne detruit pas tout.

### Point-in-time recovery (PITR)
**Quand :** base de donnees relationnelle (PostgreSQL, MySQL, SQL Server).
**Comment :** WAL archiving continu vers un stockage objet. Backup complet hebdomadaire. Restore : charger le dernier backup complet → appliquer les WAL jusqu'au timestamp desire. RPO effectif = secondes (le delai de replication du WAL), pas heures.
