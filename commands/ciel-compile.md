---
name: ciel-compile
description: Compile les episodes de memoire bruts en pages wiki structurees (Karpathy-inspired second brain)
---

# /ciel-compile

Compile les episodes de `.ciel/memory/episodes/` en pages wiki structurees dans `.ciel/wiki/`.

Utilise le skill `savoir-compiler` pour :
1. Scanner les episodes non compiles
2. Distiller en pages wiki organisees par domaine
3. Cross-referencer les pages entre elles
4. Detecter contradictions et doublons
5. Proposer des promotions vers `.claude/rules/`

**Quand l'utiliser :** quand >= 5 episodes se sont accumules sans compilation, ou apres une session riche en captures MEMOIRE.
