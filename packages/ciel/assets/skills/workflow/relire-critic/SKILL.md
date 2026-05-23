---
name: relire-critic
description: "Revue hostile post-écriture — 4 RISQUES (fonctionnel, import, data, conformité skills domaine), checklist qualité 8 items, verdict BLOCKING/IMPORTANT/MINOR. Usage interne par ciel-critic MODE=RELIRE."
internal: true
---

# Relire Critic — Revue hostile

**Principe premier :** Relire le code comme si quelqu'un d'autre l'avait écrit. Ton job est de trouver ce qui peut casser, pas de confirmer ce qui marche. L'isolation fait ta force — tu n'as pas vu l'implémentation, tu ne peux pas rationaliser les angles morts de l'auteur.

## Checklist
- [ ] 4 RISQUES émis (fonctionnel, import/API, data assumption, conformité skills domaine)
- [ ] Chaque RISQUE a file:line + résolution FIX/ACCEPT/DEFER
- [ ] Checklist qualité 8 items complétée avec preuves
- [ ] Verdict BLOCKING/IMPORTANT/MINOR émis
- [ ] Au moins 1 des 4 risques est actionnable (FIX, pas ACCEPT/DEFER)

## Les 4 RISQUES (distribution obligatoire)

1. **Fonctionnel** — Qu'est-ce qui casse pour l'utilisateur ? "This fails when..."
2. **Import / API surface** — Cet import existe-t-il ? Le contrat API est-il correct ?
3. **Data assumption** — Cette colonne DB / format / shape correspond-elle à la réalité ?
4. **Conformité skills domaine** — Vérifier 1 item de la checklist du skill domaine chargé. Si `database-design` est chargé → vérifier que les FK ont un index. Si `api-design` → vérifier la pagination.

## Résolution

Pour chaque RISQUE, choisir UNE :
- **FIX** : correction exacte — nommer le changement de code
- **ACCEPT** : pourquoi le risque est acceptable (TTL ? fenêtre < 1s ? cosmétique ?)
- **DEFER** : référence du ticket + raison hors-scope

0 FIX → suspect. Réexaminer.

## Checklist qualité (8 items)

| # | Item | Evidence |
|---|------|----------|
| 1 | Quality gates (complexité < 15, nesting < 4, fonctions < 50 lignes) | file:line |
| 2 | Tous les imports existent aux chemins spécifiés | file:line |
| 3 | Colonnes DB vérifiées dans le vrai schéma | file:line |
| 4 | Mocks de test sur le bon host:port | file:line |
| 5 | Tests indépendants de l'implémentation | file:line |
| 6 | Pas de duplication non-extraite | grep output |
| 7 | Linter clean (0 nouvelles violations) | command output |
| 8 | Un staff engineer approuverait sans changement | rationale |

Chaque item : preuve (file:line ou output) ou "N/A because X".

## Output format

```
## RISQUES
1. RISQUE: <X> parce que <Y> — IMPACT: <Z>
   → FIX/ACCEPT/DEFER: <resolution>
2. RISQUE: <X> parce que <Y> — IMPACT: <Z>
   → FIX/ACCEPT/DEFER: <resolution>
3. RISQUE: <X> parce que <Y> — IMPACT: <Z>
   → FIX/ACCEPT/DEFER: <resolution>
4. RISQUE: <X> parce que <Y> — IMPACT: <Z>
   → FIX/ACCEPT/DEFER: <resolution>

## CHECKLIST
- [✓/✗/N/A] <item> — <evidence>
...

## VERDICT
BLOCKING: <list or "none">
IMPORTANT: <list or "none">
MINOR: <list or "none">
```
