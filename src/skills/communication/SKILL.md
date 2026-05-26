---
name: communication
description: "Communication Technique — documentation, diagrammes C4, RFC, post-mortem, presentation, spec writing. A charger quand on communique sur un sujet technique."
---

# Communication Technique

**Principe premier :** La communication technique n'est pas "ecrire ce qu'on sait" — c'est faire comprendre ce que l'autre a besoin de savoir. Le plus grand piege de la communication d'expert : la malediction du savoir. Tu sais tellement bien ton sujet que tu ne peux plus imaginer ce que c'est de ne pas le savoir. Resultat : tu sautes des etapes, utilises du jargon, assumes des prerequis — et ton interlocuteur est perdu. La regle d'or : si tu ne peux pas expliquer ton design a un dev qui vient d'arriver, ton design n'est pas pret. Pas parce que le dev est novice — parce que la clarte est un test de comprehension. Si c'est flou dans ta tete, c'est flou sur le papier.

## Checklist
- [ ] La documentation est dans le repo, versionnee avec le code — pas dans Confluence/Notion qui se perime
- [ ] Les decisions techniques sont communiquees avec le POURQUOI (contexte, alternatives) — pas juste la solution
- [ ] Les diagrammes utilisent un standard reconnu (C4, UML sequence, Mermaid) — pas un outil proprietaire
- [ ] Les specs sont ecrites avant le code, lues par l'equipe, et amendees — pas "le code est la spec"
- [ ] Les post-mortems sont blameless : ce qui s'est passe, pourquoi, comment eviter que ca se reproduise
- [ ] La communication est adaptee au public : C4 level 1 pour stakeholders, level 3 pour devs
- [ ] Les PR descriptions expliquent le contexte et les trade-offs — pas juste "fixes bug"

## Anti-patterns
### Documentation dans un outil separe
**Ce qu'on voit :** specs dans Confluence, designs dans Notion, decisions dans Trello, code dans GitHub. Rien n'est a jour. Personne ne trouve rien.
**Pourquoi c'est dangereux :** la documentation eloignee du code est de la documentation morte. Elle n'est pas versionnee avec le code qu'elle decrit. Elle n'est pas revue en PR. Elle pourrit independamment. Le nouveau dev lit la spec Confluence de 2023 et code un feature deja deprecie.
**Faire plutot :** documentation dans le repo, en markdown, a cote du code qu'elle documente. `docs/architecture.md`, `docs/adrs/`, `services/orders/README.md`. La doc se review en PR comme le code. Si le code change, la doc change dans le meme commit.

### Diagramme = oeuvre d'art
**Ce qu'on voit :** 3 jours passes a faire un diagramme UML parfait dans un outil proprietaire. Le diagramme est beau. Le code change 2 semaines plus tard. Le diagramme n'est plus a jour et ne peut pas etre modifie (outil perdu, licence expiree).
**Pourquoi c'est dangereux :** un diagramme est un outil de communication, pas un livrable. Passer 3 jours sur un diagramme qui sera obsolet dans 2 semaines est du gaspillage. L'outil proprietaire cree un barrier a la modification → le diagramme pourrit.
**Faire plutot :** diagrammes en texte (Mermaid, PlantUML, Graphviz). Versionnes dans le repo. Render automatiquement dans la CI. Assez bons pour communiquer, pas parfaits. Si le diagramme prend plus d'1h, c'est qu'il est trop detaille.

### Post-mortem = blame game
**Ce qu'on voit :** incident → "qui a deploye ca ?" → recherche de coupable → le dev qui a deploye est blame. Prochaine fois, personne n'osera deployer.
**Pourquoi c'est dangereux :** chercher un coupable garantit que les incidents futurs seront caches, pas corriges. Les gens ne signalent pas les quasi-incidents. La peur remplace l'apprentissage. L'organisation devient fragile parce qu'elle ne corrige pas ses processus.
**Faire plutot :** post-mortem blameless. L'incident est cause par le SYSTEME, pas par l'individu. "Qu'est-ce qui dans notre processus a permis cette erreur ?" Action concrete sur le processus pour que ca ne se reproduise pas. L'auteur du deploiement participe au post-mortem sans crainte.

## Patterns
### C4 Model
**Quand :** expliquer l'architecture a differents publics.
**Comment :** 4 niveaux. Level 1 (Context) : le systeme dans son environnement — pour les stakeholders. Level 2 (Containers) : les briques majeures (app, DB, file system) — pour l'equipe tech elargie. Level 3 (Components) : l'interieur de chaque container — pour les devs. Level 4 (Code) : diagramme de classes — seulement si necessaire. Toujours commencer par le niveau 1, toujours avoir un titre et une legende.

### Spec writing
**Quand :** feature de > 1 semaine.
**Comment :** ecrire la spec AVANT de coder. Sections : Problema (quoi et pourquoi), Solution proposee (comment), Alternatives considerees, Impact (migration, cout, risques), Plan de test. Review d'equipe avant implementation. La spec peut etre courte (1-2 pages) — le but est l'alignement, pas la perfection.
