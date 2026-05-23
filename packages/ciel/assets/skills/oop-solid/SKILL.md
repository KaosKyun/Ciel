---
name: oop-solid
description: "OOP & SOLID — classes, objets, heritage, composition, encapsulation, principes SOLID comme garde-fous. A charger quand on travaille avec des classes."
---

# OOP & SOLID

**Principe premier :** SOLID n'est pas un dogme — c'est un systeme d'alerte precoce. Chaque principe ne te dit pas quoi faire, il te dit QUAND le design est en train de pourrir. Single Responsibility = ta classe a plus d'une raison de changer. Open/Closed = tu modifies du code existant au lieu d'etendre. Liskov = ta sous-classe ne peut pas remplacer la classe mere. Interface Segregation = tes clients dependent d'interfaces qu'ils n'utilisent pas. Dependency Inversion = tes modules de haut niveau dependent des bas niveau. Le but n'est pas un score SOLID parfait — c'est un code qui accepte le changement sans se briser. La composition est par defaut, l'heritage est l'exception.

## Checklist
- [ ] Chaque classe a une responsabilite unique (SRP) — decrire son job en une phrase sans "et"
- [ ] Les classes sont ouvertes a l'extension, fermees a la modification (OCP) — nouveau comportement = nouveau code, pas modification
- [ ] Les sous-classes sont substituables a leur classe mere (LSP) — pas de `if (obj instanceof SpecialCase)`
- [ ] Les interfaces sont minimales (ISP) — pas d'interface de 15 methodes dont 10 jettent `NotImplementedException`
- [ ] Les modules haut niveau ne dependent pas des bas niveau (DIP) — les deux dependent d'abstractions
- [ ] L'heritage est utilise pour "est-un", pas pour reutiliser du code — composition > heritage
- [ ] Le couplage est reduit : un changement dans une classe ne force pas une cascade de changements

## Anti-patterns
### SOLID comme religion
**Ce qu'on voit :** chaque classe est precedee de `interface IFoo`. Chaque `new` est remplace par une factory + DI container. 50 classes pour afficher "Hello World".
**Pourquoi c'est dangereux :** SOLID utilise en dogme produit l'inverse de son intention : code rigide, difficile a changer, difficile a comprendre. Une interface pour chaque classe = explosion du nombre de fichiers. DI partout = perdu dans les couches d'indirection.
**Faire plutot :** appliquer SOLID la ou le changement est PROBABLE. Un composant stable peut violer SOLID — c'est acceptable. Introduire une abstraction quand un deuxieme cas concret apparait (pas avant). SOLID est un outil de diagnostic, pas un objectif de design.

### Heritage deep chain
**Ce qu'on voit :** `Animal → Mammal → Canine → Dog → Labrador → GoldenLabrador`. Chaque classe ajoute un comportement. Pour comprendre `GoldenLabrador`, il faut lire 6 classes.
**Pourquoi c'est dangereux :** l'heritage profond cree un couplage vertical. Changer `Animal` affecte toutes les 200 sous-classes. Impossible de comprendre une classe isolement. Le YAGNI frappe fort : la plupart des classes intermediaires ne sont jamais utilisees directement.
**Faire plutot :** limiter a 1-2 niveaux d'heritage maximum. Composer les comportements (Strategy, Decorator) plutot qu'heriter. Si une classe a plus de 2 ancetres concrets, repenser le design.

### Classe "Manager" / "Utils" / "Helper"
**Ce qu'on voit :** `UserManager` (3000 lignes), `DateUtils` (150 fonctions statiques), `StringHelper` (tout le monde ajoute des trucs).
**Pourquoi c'est dangereux :** les noms en -Manager, -Utils, -Helper sont des aveux d'echec de design. Ils ne disent rien sur ce que fait la classe. Ils attirent le code non relie comme un aimant. Une classe qui s'appelle `Manager` n'a pas de responsabilite — elle en a 50.
**Faire plutot :** nommer les classes par leur responsabilite reelle. `UserRepository`, `UserAuthenticator`, `UserNotificationSender`. Si une classe a plus de 10 methodes publiques, la splitter par responsabilite. Les "utils" sont un signe qu'un concept manque dans le domaine.

## Patterns
### Composition over inheritance
**Quand :** quasi tout le temps.
**Comment :** au lieu de `class Duck extends Bird extends Animal`, injecter les comportements : `class Duck { constructor(flyBehavior, quackBehavior, swimBehavior) }`. Chaque comportement est interchangeable. Testable independamment. Le duck peut changer de FlyBehavior au runtime.

### Dependency injection par constructeur
**Quand :** toute classe qui depend d'un service externe (DB, API, file system).
**Comment :** `constructor(db: Database, logger: Logger)` — les dependances sont explicites. Pas de `new Database()` dans la classe. Pas de singleton global (`Database.getInstance()`). Le test peut injecter un mock/adaptateur. La classe ne sait pas CREER ses dependances, elle les RECOIT.
