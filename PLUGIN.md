---
name: ciel
version: 1.0.0
description: Universal deep-reasoning workflow for LLM-assisted development. 5-layer enforcement: hooks + skill + isolated agents + metrics.
author: KaosKyun
min_claude_code_version: "1.0"
---

# Ciel

Universal deep-reasoning workflow plugin. Named after the Primordial Sage from *Tensei Shitara Slime Datta Ken* — the advisor who reasons at infinite speed before Rimuru acts.

## Components

- `skills/ciel/SKILL.md` — CRÉER/CRITIQUER workflow
- `agents/researcher.md` — RECHERCHE in isolated context
- `agents/explorer.md` — CODEBASE + FLUX in isolated context
- `agents/critic.md` — RELIRE + CRITIQUER in isolated context
- `hooks/pre-write-gate.sh` — Deterministic FLUX checkpoint before write
- `hooks/post-write-relire.sh` — Deterministic RELIRE injection after write
- `commands/ciel.md` — `/ciel` entry point
- `overlay-template.md` — Project-specific config template
- `CHANGELOG.md` — Version history + fix/revert metrics
