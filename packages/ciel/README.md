# @neikyun/ciel

Ciel — Deep-reasoning pipeline for LLM-assisted development.  
Pipeline: DOCS → QUOI → ASK → AVEC QUOI → DIVERGE → RECHERCHE → SÉCURITÉ → CODEBASE → ÉVALUER → ASK2 → FAIRE → ADR → RELIRE → PROUVER → MÉMOIRE → META.

## Installation

```bash
npm install @neikyun/ciel
```

### OpenCode

Add to `opencode.json`:

```json
{
  "plugin": ["@neikyun/ciel"]
}
```

Then run:

```bash
npx ciel init -y
```

### Claude Code

```bash
npx ciel init -y
```

### Multi-platform

`npx ciel` detects OpenCode and Claude Code automatically and installs for both.

## CLI

```bash
npx ciel init          # Install Ciel
npx ciel update        # Reinstall / update
npx ciel uninstall     # Remove Ciel
npx ciel check         # Check for updates
```

## Features

- **Depth classification** — Trivial / Standard / Critical / Spike
- **16-step pipeline** — From DOCS to META, never skip steps
- **FAIRE gates** — Test-first, alternatives, idiomatic, quality, removal, boy-scout
- **RELIRE** — Hostile self-review with 3 RISQUES methodology
- **Multi-platform** — OpenCode plugin + Claude Code hooks
- **Self-hosting** — Ciel uses its own plugin

## Links

- GitHub: https://github.com/KaosKyun/Ciel
- Issues: https://github.com/KaosKyun/Ciel/issues

## License

MIT
