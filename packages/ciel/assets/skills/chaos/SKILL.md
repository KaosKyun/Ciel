---
name: chaos
description: "Chaos Engineering — fault injection, Game Day, Chaos Monkey, experimentation, resiliency testing. A charger quand on fait du chaos engineering."
---

# Chaos Engineering

## Checklist
- [ ] Une hypothese de resilience est formulee avant chaque experience
- [ ] L'experience a un perimetre limite (blast radius controle)
- [ ] Un rollback automatique est prepare si les metriques degradent
- [ ] Les metriques RED (Rate, Errors, Duration) sont surveillees en temps reel
- [ ] L'impact est mesure et documente (pas juste "ca a marche")
- [ ] Les lecons sont transformees en tickets d'action
- [ ] La frequence est reguliere (mensuelle ou trimestrielle)

## Anti-patterns
### Chaos sans filet
**Ce qu'on voit :** `chaos kill pod` en production sans monitoring, sans rollback, sans alerte.
**Pourquoi c'est dangereux :** si le systeme ne tient pas, l'incident est reel. Les clients sont impactes. L'equipe panique.
**Faire plutot :** commencer en staging. Monitoring en place. Blast radius limite (1 pod, 1 region, 1% du trafic). Rollback automatique si < 99% de succes.

### Chaos sans hypothese
**Ce qu'on voit :** "on tue des pods au hasard pour voir". Aucune hypothese formulee.
**Pourquoi c'est dangereux :** on ne sait pas ce qu'on teste. Les resultats sont ininterpretables. Aucun apprentissage.
**Faire plutot :** "Si le pod API-1 est tue, le load balancer redirige le trafic vers API-2 en < 5s sans erreur 5xx." Hypothese claire, mesurable.

### Jamais de Game Day
**Ce qu'on voit :** le chaos engineering n'est jamais planifie. C'est toujours reactif.
**Pourquoi c'est dangereux :** les failles ne sont decouvertes qu'en production, pendant un vrai incident. Stress maximal.
**Faire plutot :** Game Day planifie chaque mois. Scenarios types : panne DB, crash pod, latence reseau, certificat expire. L'equipe s'entraine.

## Patterns
### Blast radius progressive
**Quand :** toute experience de chaos.
**Comment :** commencer petit (1 pod, 1 utilisateur) → grossir progressivement (1 service, 1 region). Verification des metriques a chaque etape. Arreter en cas d'anomalie.

### Game Day regulier
**Quand :** equipe platforme ou SRE.
**Comment :** 1 Game Day par mois. Scenarios : panne DB, cache down, certificat expire, DDoS partiel. L'equipe pratique. Les runbooks sont mis a jour.
