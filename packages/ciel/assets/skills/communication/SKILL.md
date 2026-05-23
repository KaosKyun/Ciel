---
name: communication
description: "Communication Technique — documentation, diagrammes, RFC, post-mortem, presentation, vulgarisation. A charger quand on communique sur un sujet technique."
triggers:
  path: "**/*.doc.*,**/RFC*,**/rfc*,**/diagram*,**/c4*,**/plantuml*,**/mermaid*"
---

# Communication Technique

## Checklist
- [ ] La documentation est a jour et versionnee (dans le repo, pas sur Confluence perdu)
- [ ] Les decisions techniques sont communiquees avec le "why" (contexte, pas juste solution)
- [ ] Les diagrammes sont dans le code (Mermaid, PlantUML, Diagrams as Code)
- [ ] Les RFC sont utilisees pour les changements significatifs avant implementation
- [ ] Les post-mortems sont sans blame et avec actions concretes
- [ ] Le public-cible est identifie avant d'ecrire (dev, manager, client, junior)
- [ ] La vulgarisation est utilisee pour les concepts complexes (analogie, exemple)
- [ ] Les presentations techniques sont repetees et chronometrees avant le jour J

## Anti-patterns
### Documentation dans un outil ferme
**Ce qu'on voit :** toute la doc est dans Confluence/Notion. Personne ne peut modifier sans acces. Pas de versionning.
**Pourquoi c'est dangereux :** la doc n'est jamais a jour. Les nouveaux arrivants ne savent pas ou chercher. La doc n'est pas accessible dans le workflow (IDE, CI).
**Faire plutot :** documentation as code. README.md, ADR, wiki dans le repo. Versionnee. Accessible depuis l'IDE. Mise a jour dans la PR. `mkdocs` ou `docusaurus` pour le rendu.

### Pas de RFC pour les gros changements
**Ce qu'on voit :** le tech lead decide de migrer de MySQL a PostgreSQL. L'equipe le decouvre lors du sprint planning.
**Pourquoi c'est dangereux :** les impacts ne sont pas anticipes. L'equipe n'est pas alignee. Le changement prend 3x plus de temps que prevu.
**Faire plutot :** RFC (Request For Comments) pour les changements significatifs. Contexte, proposition, alternatives, impacts. Revue par l'equipe. Decision documentee.

### Diagrammes en image
**Ce qu'on voit :** l'architecture est documentee dans un fichier `architecture.png` dans le wiki.
**Pourquoi c'est dangereux :** l'image n'est pas modifiable facilement. Des que l'architecture change, le diagramme est obsolet. Personne ne veut refaire le dessin.
**Faire plutot :** diagrams as code : Mermaid, PlantUML, Draw.io dans le repo. Le diagramme est genere a partir du texte. Facile a modifier. Versionne.

## Patterns
### Documentation as Code
**Quand :** toute documentation technique.
**Comment :** docs dans le repo (Markdown, Asciidoc). ADR dans `docs/adrs/`. Architecture dans `/docs/diagrams/` (Mermaid/PlantUML). CI genere le rendu. La PR met a jour la doc.

### C4 Model
**Quand :** documentation d'architecture.
**Comment :** 4 niveaux : Context (vision systeme), Container (services), Component (composants internes), Code (classes/DB). Chaque niveau s'adresse a un public different. Diagrams as Code.
