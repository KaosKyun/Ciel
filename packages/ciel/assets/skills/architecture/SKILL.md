---
name: architecture
description: "Architecture Logicielle — monolithe modulaire, microservices, hexagonale (ports/adapters), clean architecture. A charger quand on definit la structure d'un projet ou qu'on refactorise."
---

# Architecture Logicielle

## Checklist
- [ ] Le choix d'architecture est justifie par le contexte, pas par la mode
- [ ] Les dependances pointent vers le domaine (pas l'inverse)
- [ ] Les couches sont separees : domaine → application → infrastructure → presentation
- [ ] Chaque composant a une responsabilite unique et claire
- [ ] Les interfaces entre modules sont explicites (contrats, pas couplage implicite)
- [ ] Le diagramme C4 (Context → Containers → Components) existe
- [ ] Demarrer simple (monolithe modulaire) — migrer vers microservices seulement si besoin prouve

## Anti-patterns
### Microservices premature
**Ce qu'on voit :** 12 services pour une app avec 3 utilisateurs. Un changement simple touche 4 repos.
**Pourquoi c'est dangereux :** cout de coordination enorme, complexite reseau, debugging impossible. Amazon Prime Video est revenu de microservices a monolithe en 2023.
**Faire plutot :** monolithe modulaire avec domaines bien separes. Extraire un service UNIQUEMENT quand le besoin est prouve (scale independant, equipe dediee, release cycle different).

### Architecture en couches sans discipline
**Ce qu'on voit :** le controller appelle directement la DB. La couche service est vide. Les regles metier sont dans les models.
**Pourquoi c'est dangereux :** le domaine est dilue partout. Changer la DB oblige a toucher 50 fichiers.
**Faire plutot :** ports/adapters (hexagonale). Le domaine definit les interfaces (ports). L'infra les implemente (adapters).

### Big Ball of Mud sous un joli nom
**Ce qu'on voit :** un dossier `utils/` de 40 fichiers, des imports circulaires, des `SharedStuff` partout.

**Pourquoi c'est dangereux :** aucune frontiere reelle. Tout depend de tout. Impossible de tester isolement.
**Faire plutot :** nommer les modules par capacite metier (billing, shipping, auth), pas par couche technique (controllers, services, utils).

## Patterns
### Ports & Adapters (Hexagonale)
**Quand :** le domaine metier doit survivre aux changements d'infrastructure.
**Comment :** le domaine definit des interfaces (ports). Les adapters (DB, HTTP, message queue) implementent ces interfaces. Le domaine ne depend de rien d'externe.

### Monolithe modulaire
**Quand :** debut de projet, equipe < 20, pas de besoin de scale independant.
**Comment :** modules par domaine (billing/, shipping/, auth/). Chaque module a son propre schema DB. Communication inter-module par interfaces explicites, pas par import direct.

### Strangler Fig
**Quand :** migration progressive d'un legacy vers une nouvelle architecture.
**Comment :** nouvelle fonctionnalite → nouveau systeme. Ancienne fonctionnalite → progressivement reecrite et basculee. L'ancien systeme est "etrangle" morceau par morceau.
