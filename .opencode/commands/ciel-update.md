---
description: "Check for newer Ciel release on GitHub and re-install via install.sh --update"
---

Update Ciel to the latest version.

Usage: `/ciel-update`

Run the update command:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh) --update
```

This re-installs Ciel while preserving user configs (ciel-overlay.md, opencode.json, .claude/settings.json).
