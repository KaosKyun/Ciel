---
name: savoir-compiler
description: Compile raw memory episodes into structured wiki pages. Karpathy-inspired knowledge compilation layer between raw memories (.ciel/memory/) and schema rules (ciel-overlay.md, .claude/rules/). Transforms dormant episodes into actionable, cross-referenced knowledge.
category: meta
---

# Savoir-Compiler — Ciel Second Brain (inspire de Karpathy LLM Wiki)

## What this covers

Ciel a deja deux couches de connaissance :
- **raw** = `.ciel/memory/episodes/` — souvenirs immuables captures par tache
- **schema** = `ciel-overlay.md` + `.claude/rules/` + `CLAUDE.md` — regles actives

Ce qui manque : la **couche wiki** — une compilation structuree et cross-referencee entre les episodes bruts et les regles. C'est le role du savoir-compiler.

```
.ciel/
  memory/           → raw (immuable — capture par MEMOIRE)
    episodes/       ← souvenirs dates, jamais modifies
    concepts/       ← patterns promus (memoire-consolidator)
    guards/         ← regles de vigilance
  wiki/             → compile (LLM-authored — ce skill)
    INDEX.md        ← index navigable avec compiled_at
    patterns/       ← patterns distilles depuis les episodes
    decisions/      ← decisions architecturales
    pitfalls/       ← erreurs frequentes compilees
```

Principe Karpathy : *"You never write the wiki yourself — the LLM writes and maintains all of it."* Le compilateur lit les episodes raw et produit des pages wiki structurees. L'humain ne les ecrit jamais.

## When to run

**Automatique :** a l'etape COMPILER du pipeline (apres MEMOIRE), si >= 5 episodes n'ont pas de page wiki correspondante.

**Manuel :** `/ciel-compile` — invoque ce skill directement.

**Check rapide :** comparer le nombre d'episodes dans `memory/episodes/` avec le `last_compiled_count` dans `wiki/INDEX.md`. Si delta >= 5 → compiler.

## Six operations

Toujours dans cet ordre. Ne jamais sauter CROSS-REF ou LINT.

### 1. INGEST — Scanner les episodes non compiles

```bash
ls .ciel/memory/episodes/*.md | wc -l
cat .ciel/wiki/INDEX.md 2>/dev/null || echo "no index yet"
```

Identifier les episodes qui n'ont pas encore de page wiki. Un episode est "compile" s'il apparait dans le champ `source_episodes` d'une page wiki ou dans `compiled_episodes` de INDEX.md.

### 2. COMPILE — Distiller en pages wiki

Lire les episodes non compiles. Les grouper par domaine (intent commun, path_pattern commun). Pour chaque groupe de >= 2 episodes, creer une page wiki.

**Quand creer une page dediee (>= 2 episodes) vs note dans une page existante (1 episode) :**
- >= 2 episodes partagent le meme intent → nouvelle page dans `patterns/`
- 1 episode isole → l'ajouter en note dans la page existante la plus proche, ou creer une entree dans `pitfalls/`
- Episode de type "decision architecturale" → toujours dans `decisions/`, meme seul

**Format de page wiki :**

```markdown
---
domain: hooks
compiled_at: 2026-05-24T10:00:00Z
source_episodes: [mem_xyz, mem_abc]
related_rules: [.claude/rules/security.md]
related_wiki: [patterns/bash-hook-patterns.md]
---
# Hooks — Patterns compiles

## Regle 1: PreToolUse hooks → stderr, jamais stdout
**Source:** mem_xyz (15 triggers), mem_abc
**Pourquoi:** stdout JSON corrompt la communication Claude Code
**Canonique:** hooks/pre-tool-write.sh:72
**Contexte:** Chaque hook qui communique avec Claude DOIT utiliser >&2

## Regle 2: Dispatch gate = marker file + PreToolUse check
**Source:** mem_5e5de7 (15 triggers)
**Pourquoi:** Le dispatch gate n'est pas enforce par le LLM mais par hook bash
**Canonique:** hooks/check-dispatch-gate.sh
```

Frontmatter obligatoire : `domain`, `compiled_at`, `source_episodes`. Optionnel : `related_rules`, `related_wiki`.

### 3. CROSS-REF — Ajouter des [[wikilinks]]

Pour chaque page wiki creee ou modifiee :
- Linker vers les episodes sources (dans `source_episodes`)
- Linker vers les regles liees (`related_rules`)
- Linker vers les autres pages wiki (`related_wiki`) quand le domaine se chevauche
- Mettre a jour les pages wiki existantes qui devraient referencer la nouvelle page

Les wikilinks utilisent le chemin relatif depuis `.ciel/wiki/` : `[patterns/hooks.md](patterns/hooks.md)`

### 4. LINT — Detecter les problemes

Verifications automatiques :
- **Contradictions :** deux pages wiki affirment des choses opposees ? → signaler dans le output report
- **Orphelins :** une page wiki n'est referencee par aucune autre page ni INDEX.md ? → ajouter a INDEX.md
- **Doublons :** deux pages couvrent le meme sujet (tags identiques a >= 80%) ? → proposer merge
- **Sources mortes :** un episode source a ete marque `stale: true` ? → mettre a jour la page wiki

### 5. PROPOSE — Suggérer des mises à jour du schema

Quand une page wiki contient >= 3 episodes source et >= 10 triggers cumules, c'est un candidat pour promouvoir en regle. Emettre une suggestion dans le output report :

```
PROPOSE: promouvoir "patterns/hooks.md" → .claude/rules/hooks.md
  Raison: 5 episodes, 42 triggers cumules. Pattern stabilise.
  Action: AskUserQuestion → si oui, creer la regle et linker depuis wiki.
```

Ne jamais modifier le schema sans AskUserQuestion. Le compilateur propose, l'utilisateur dispose.

### 6. INDEX — Mettre à jour wiki/INDEX.md

Toujours en dernier. INDEX.md est la porte d'entree du wiki :

```markdown
# Ciel Wiki — Index

Derniere compilation: 2026-05-24T10:00:00Z
Episodes compiles: 23/28
Dernier episode vu: episodes/2026-05-24-xxx.md

## Patterns (3 pages)
- [Hooks](patterns/hooks.md) — 5 episodes, 42 triggers
- [Pipeline](patterns/pipeline.md) — 3 episodes, 18 triggers
- [Settings](patterns/settings.md) — 2 episodes, 8 triggers

## Decisions (1 page)
- [ADR-0001: Cued-recall vs free-recall](decisions/cued-recall-design.md)

## Pitfalls (2 pages)
- [Bash stdout dans les hooks](pitfalls/bash-stdout-hooks.md)
- [Version drift multi-fichiers](pitfalls/version-drift.md)
```

Mettre a jour `last_compiled_count` et la date.

## Anti-patterns

| Anti-pattern | Pourquoi |
|---|---|
| Modifier les episodes raw | Les episodes sont immuables. Le wiki est derive, pas substitut. |
| Auto-promote vers schema | Les regles doivent etre validees par l'humain. PROPOSE, n'impose pas. |
| Creer une page pour 1 episode | Sauf decisions architecturales, une page wiki consolide >= 2 episodes. |
| Skipper CROSS-REF | Sans wikilinks, le wiki est aussi mort que les episodes raw. |
| Compiler sans LINT | Des contradictions non detectees = corruptions silencieuses du savoir. |
| Recopier le contenu des episodes | Compiler = synthetiser, pas agreger. Une page wiki est plus courte que la somme de ses sources. |

## Output report

Apres chaque compilation, emettre un resume:

```
[savoir-compiler] 2026-05-24T10:00:00Z
INGEST:  5 nouveaux episodes depuis derniere compilation
COMPILE: 2 pages creees (patterns/hooks.md, patterns/pipeline.md)
         1 page mise a jour (pitfalls/bash-stdout-hooks.md)
CROSS-REF: 4 wikilinks ajoutes, 2 pages existantes mises a jour
LINT:    0 contradiction, 1 orphelin resolu
PROPOSE: 1 promotion suggeree (hooks → rules)
INDEX:   wiki/INDEX.md mis a jour (5 pages, 23/28 episodes compiles)
```

## Token budget

- INGEST (ls + cat INDEX.md) : ~100 tokens
- Lecture episodes : ~500 tokens/episode, max 10 episodes (= 5000 tokens)
- Ecriture wiki : ~2000 tokens/page, max 3 nouvelles pages par run (= 6000 tokens)
- INDEX update : ~500 tokens

Budget total par run : ~12K tokens. Raisonnable pour une tache Standard.

## Related

- `memoire` — capture les episodes raw que ce skill compile
- `memoire-consolidator` — maintenance des episodes (promote/merge/stale), complementaire
- `meta-critiquer` — reflection post-tache qui peut declencher la compilation
- `commands/ciel-compile.md` — invocation manuelle
