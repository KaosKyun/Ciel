---
name: chaos
description: "Chaos Engineering — injection de pannes, Game Day, Chaos Monkey, experimentation, hypotheses de resilience. A charger quand on teste la resilience d'un systeme."
---

# Chaos Engineering

**Principe premier :** Le chaos engineering n'est pas "casser des choses en production pour voir ce qui se passe" — c'est une discipline scientifique appliquee aux systemes distribues. Tu formules une hypothese de resilience ("si le service B tombe, le fallback degrade le mode"), tu injectes la panne de maniere controlee, et tu compares le comportement observe a l'hypothese. La valeur n'est pas dans le chaos — elle est dans la decouverte des comportements emergents que personne n'avait prevus. Un systeme sans chaos engineering n'est pas stable — il est non teste. La stabilite reelle se mesure en production, pas en staging.

## Checklist
- [ ] Une hypothese de resilience est formulee avant chaque experience (pas "on va eteindre cette DB et voir")
- [ ] Le blast radius est controle : un petit pourcentage de trafic, un seul AZ/service
- [ ] L'experience a un arret d'urgence (kill switch) actionnable en < 10 secondes
- [ ] Les metriques sont en place AVANT l'experience (baseline + deviation en temps reel)
- [ ] Le Game Day est planifie avec un scenario et un runbook
- [ ] Les decouvertes sont documentees et transforment le systeme (pas "c'etait interessant, on fera mieux")

## Anti-patterns
### Chaos en production sans filet
**Ce qu'on voit :** "on va tester en production vendredi soir." Pas d'hypothese, pas de kill switch, pas de monitoring.
**Pourquoi c'est dangereux :** le chaos sans controle n'est pas une experience — c'est un incident provoque. Sans hypothese, tu ne sais pas si le comportement est normal ou anormal. Sans kill switch, tu ne peux pas arreter l'hemorragie.
**Faire plutot :** commencer en staging avec des pannes simples (kill un process, saturer un disque). Monter en puissance progressivement. En production : commencer par 1% de trafic, puis 5%, puis 10%. Toujours avec un kill switch.

### Chaos = Chaos Monkey uniquement
**Ce qu'on voit :** l'equipe installe Chaos Monkey, kill des instances au hasard, et considere que le chaos engineering est fait.
**Pourquoi c'est dangereux :** Chaos Monkey teste UNE chose : que ton application survit a la mort d'une instance. Ca ne teste pas la latence reseau, la corruption de donnees, la saturation disque, les pannes DNS, les timeouts de circuit breaker. Le chaos engineering est une discipline large — Chaos Monkey en est un tout petit sous-ensemble.
**Faire plutot :** varier les injections : latence reseau, perte de paquets, defaillance DNS, saturation CPU/disque, coupure de dependance, corruption de reponse, expiration de certificat. Chaque type de panne revele une classe de vulnerabilites differente.

### Pas de suivi des decouvertes
**Ce qu'on voit :** le Game Day est fun. Les decouvertes sont notees sur un post-it. Rien n'est corrige.
**Pourquoi c'est dangereux :** le chaos engineering sans correction est du theatre. Les memes vulnerabilites survivent au Game Day suivant. L'equipe apprend mais le systeme n'apprend pas.
**Faire plutot :** chaque decouverte = un ticket. Prioriser les corrections avant le prochain Game Day. Re-tester les memes pannes pour verifier que la correction fonctionne. Le chaos engineering est une boucle : injecter → mesurer → corriger → re-tester.

## Patterns
### Game Day
**Quand :** equipe qui n'a jamais teste son systeme en conditions de panne.
**Comment :** 2h-4h planifiees. 1 scenario defini a l'avance ("la DB primaire est inaccessible"). Roles : un orchestrateur, un observateur, un intervenant. Monitoring temps reel. Debrief immediat apres : qu'est-ce qui a casse ? qu'est-ce qui a tenu ? qu'est-ce qu'on corrige ?

### Steady-state hypothesis
**Quand :** toute experience de chaos.
**Comment :** definir l'etat normal AVANT l'injection ("P95 latence < 500ms, taux d'erreur < 1%, pas d'alerte critique"). Injecter la panne. Comparer a l'etat normal. Si l'ecart est inattendu → vulnerabilite. Cette methode donne une definition objective de "le systeme a tenu".
