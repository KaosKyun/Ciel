---
name: oop-solid
description: "OOP et SOLID — programmation orientee objet, principes SOLID, heritage, composition, polymorphisme. A charger quand on travaille avec des classes ou de l'OOP."
---

# OOP & SOLID

## Checklist
- [ ] Chaque classe a une responsabilite unique (SRP) — pas de "classe fourre-tout"
- [ ] Les classes sont fermees a la modification, ouvertes a l'extension (OCP)
- [ ] Les sous-classes sont substituables a leurs classes parentes (LSP)
- [ ] Les interfaces sont segregees (ISP) — pas d'interface avec 20 methodes inutiles
- [ ] Les dependances sont injectees (DIP) — pas de `new` dans le constructeur
- [ ] La composition est preferee a l'heritage (favor composition over inheritance)
- [ ] Pas de getters/setters systeme (Tell, Don't Ask)

## Anti-patterns
### Dieu du systeme (God Object)
**Ce qu'on voit :** une classe `UserManager` de 2000 lignes qui gere tout (validation, persistence, email, auth, billing).
**Pourquoi c'est dangereux :** impossible a tester, impossible a maintenir, impossible a etendre. Un bug dans une methode impacte tout le systeme.
**Faire plutot :** SRP : `UserValidator`, `UserRepository`, `EmailService`, `AuthService`, `BillingService`. Chaque classe fait UNE chose.

### Heritage abusif
**Ce qu'on voit :** `class Admin extends User` → `class SuperAdmin extends Admin` → `class GuestUser extends User` — 6 niveaux d'heritage.
**Pourquoi c'est dangereux :** le couplage est fort. Changer la classe parente peut casser toutes les sous-classes. Le "diamond problem" guette.
**Faire plutot :** composition : `class Admin { constructor(user, permissions) {} }`. OU interfaces. L'heritage est pour le partage de comportement, pas de code.

### Setter partout
**Ce qu'on voit :** `user.setName("John"); user.setEmail("john@example.com"); user.setStatus("active")` — setters pour chaque champ.
**Pourquoi c'est dangereux :** l'objet peut etre dans un etat invalide. Pas d'encapsulation. Le compilateur ne peut pas garantir l'integrite.
**Faire plutot :** immutabilite. Les champs sont `readonly`/`final`. Construction via constructeur. Methodes qui retournent une nouvelle instance (pas de mutation).

## Patterns
### Dependency Injection
**Quand :** une classe a besoin de services externes (DB, API, logger).
**Comment :** les dependances sont passeees dans le constructeur (constructor injection). Le container DI (NestJS, Spring, Guice) cree les instances. La classe ne cree pas ses dependances.

### Value Object
**Quand :** un type primitif ne suffit pas (Email, Money, Address, PhoneNumber).
**Comment :** `class Email { constructor(readonly value: string) { this.validate(value); } private validate(email) { ... } }`. L'objet encapsule la validation et le comportement.
