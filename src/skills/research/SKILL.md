---
name: research
description: "Recherche web — stratégies de recherche, évaluation des sources, documentation officielle, issues GitHub, pertinence et fraîcheur de l'information. À charger avant toute recherche d'information externe."
---

# Recherche Web

**Principe premier :** La qualité du code dépend de la qualité de l'information qui l'a inspiré. Une recherche bâclée produit du code basé sur des articles de blog obsolètes, des réponses StackOverflow sans contexte, ou pire — des hallucinations confondues avec des faits. La recherche est une compétence technique : savoir quoi chercher, où chercher, comment évaluer, et quand s'arrêter. Le but n'est pas de tout lire — c'est de trouver l'information la plus fiable et pertinente en un minimum de temps.

## Hiérarchie des sources (par ordre de confiance)
1. **Documentation officielle** — docs du framework/langage, spécifications, RFCs
2. **Code source** — le code est la documentation ultime, il ne ment jamais
3. **Changelogs / release notes** — pour les changements de comportement entre versions
4. **Issues GitHub officielles** — bugs connus, discussions de design, workarounds
5. **StackOverflow / forums** — uniquement si la réponse a > 10 votes et date de < 2 ans
6. **Articles de blog / Medium** — uniquement de la part de mainteneurs officiels ou experts reconnus
7. **LLM / connaissances internes** — dernier recours, toujours vérifier avec une source primaire

## Checklist
- [ ] La recherche part d'une source officielle (pas d'un blog ou d'une réponse StackOverflow)
- [ ] La version de la doc correspond à la version utilisée dans le projet (pas de doc v2 pour un projet en v1)
- [ ] Au moins deux sources indépendantes confirment une information critique (pas de single-source confirmation)
- [ ] Les issues GitHub sont vérifiées : open vs closed, date de dernière activité, lien à un PR de fix
- [ ] Pour un bug : l'issue a été reproduite par quelqu'un d'autre, pas juste signalée
- [ ] Pour une solution : le PR qui la contient est mergé et released, pas juste proposé
- [ ] La fraîcheur est évaluée : < 6 mois (excellent), < 2 ans (bon), > 2 ans (vérifier si toujours valide)

## Anti-patterns
### Première page Google = vérité
**Ce qu'on voit :** recherche Google, premier lien (souvent un blog), copie de la solution sans vérifier qui l'a écrite ni quand.
**Pourquoi c'est dangereux :** le SEO n'est pas un indicateur de qualité. Les articles de blog optimisés SEO sont souvent écrits par des juniors qui reproduisent ce qu'ils ont vu ailleurs (cargo cult). La solution peut être obsolète, incorrecte, ou dangereuse. Le pire : elle peut marcher dans le cas simple mais échouer silencieusement en production.
**Faire plutôt :** commencer par la documentation officielle. Le site de doc du framework a un search — l'utiliser. Si Google est nécessaire, ajouter `site:docs.official.com` ou `site:github.com/org/repo/issues`. Filtrer par date (< 1 an). Croiser avec une deuxième source avant d'adopter.

### Solution StackOverflow sans contexte
**Ce qu'on voit :** copier-coller une réponse StackOverflow acceptée sans lire la question complète, les commentaires, ou les autres réponses.
**Pourquoi c'est dangereux :** la réponse acceptée n'est pas toujours la meilleure — c'est celle qui a résolu le problème de l'OP. Le contexte peut être différent (version différente, contrainte différente). Les commentaires contiennent souvent des corrections critiques ("this breaks in v3", "deprecated since...").
**Faire plutôt :** lire la question complète (même contexte ?), les 2-3 réponses les plus votées (pas juste l'acceptée), les commentaires sous chaque réponse (corrections, mises en garde), et vérifier la date. Une réponse de 2015 peut être dangereuse en 2026.

### Hallucination de documentation
**Ce qu'on voit :** le LLM affirme qu'une API existe avec certaines options. Pas de vérification. Le code est écrit avec une API inexistante.
**Pourquoi c'est dangereux :** les LLMs mélangent les versions, inventent des paramètres plausibles, et confondent les frameworks similaires (React 17 vs 19, Python 2 vs 3, Express vs Fastify). L'information inventée est souvent syntaxiquement correcte mais sémantiquement fausse — le compilateur ne la détecte pas.
**Faire plutôt :** toute API utilisée pour la première fois doit être vérifiée dans la doc officielle. Si le LLM dit `fetch(url, { retries: 3 })` — vérifier que `retries` existe vraiment dans l'API fetch. Ne jamais faire confiance à un nom de paramètre ou une signature de fonction sans vérification.

### Ignorer les issues fermées
**Ce qu'on voit :** on cherche un bug, on trouve une issue ouverte qui décrit le même problème. On s'arrête là. Mais l'issue fermée #1452 contenait la vraie solution, mergée il y a 3 semaines.
**Pourquoi c'est dangereux :** les issues fermées contiennent les solutions. Les issues ouvertes contiennent les problèmes. Chercher seulement les ouvertes = ignorer tout ce qui a déjà été résolu. Le bug que tu rencontres a peut-être déjà un fix dans la dernière release.
**Faire plutôt :** toujours chercher les issues fermées ET ouvertes. Une issue fermée avec un PR lié → lire le PR, vérifier dans quelle release il est inclus. Une issue fermée sans PR → lire pourquoi (wontfix ? duplicate ?). Les issues fermées récemment (< 1 mois) sont des mines d'or.

### Single-source confirmation
**Ce qu'on voit :** une information critique (auth, sécurité, migration) est confirmée par UNE seule source. Pas de vérification croisée.
**Pourquoi c'est dangereux :** une source peut se tromper. Si la seule source qui dit "cette migration est safe" est un commentaire GitHub de 2019 avec 2 pouces, c'est un pari, pas une vérification.
**Faire plutôt :** règle des deux sources pour toute information critique. La doc officielle + une issue GitHub. Ou le code source + les tests. Si les sources se contredisent → la doc officielle et le code source priment. Toujours documenter quelle source a confirmé quoi.

## Patterns
### Stratégie de recherche par couches
**Quand :** toute tâche qui demande des connaissances externes.
**Comment :** Couche 1 : doc officielle (site:docs.X.com). Couche 2 : issues GitHub (site:github.com/org/repo/issues). Couche 3 : StackOverflow si et seulement si les deux premières n'ont pas donné de réponse. Chaque couche plus large = confiance plus faible. Arrêter dès qu'une source fiable confirme.

### Vérification de version
**Quand :** toute lecture de documentation.
**Comment :** vérifier la version affichée en haut de la page de doc (souvent un dropdown). Comparer avec la version installée (`package.json`, `go.mod`, `Cargo.toml`). Si la doc est en v3 et le projet en v1 → chercher la doc v1 (URL avec `/v1/` ou switcher dans l'UI). Les breaking changes entre versions sont la cause #1 de "pourtant la doc dit que ça marche".

### Évaluation d'issue GitHub
**Quand :** on lit une issue GitHub pour décider d'une action.
**Comment :** Checker : (1) statut (open/closed), (2) date de dernière activité (récent = actif), (3) nombre de participants (plusieurs personnes = problème réel), (4) PRs liés (un PR merged = solution disponible), (5) milestones (incluse dans une release ?). Une issue avec 50 commentaires, fermée, avec un PR merged dans la release v2.3 → solution confirmée. Une issue avec 2 commentaires, ouverte depuis 2 ans → probablement pas prioritaire.

### Croisement de sources
**Quand :** information critique (sécurité, breaking change, deprecation).
**Comment :** trouver au moins deux sources indépendantes. Exemples de paires valides : doc officielle + changelog, code source + test, issue GitHub + PR mergé. Une paire invalide : deux articles de blog qui citent la même source. Noter les sources dans un commentaire du code ou du PR pour que le prochain développeur sache pourquoi cette décision a été prise.
