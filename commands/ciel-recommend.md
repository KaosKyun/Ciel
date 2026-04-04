# /ciel-recommend — Discover & Install Recommended Skills/Plugins

*Discovers community and official Claude Code plugins recommended for your project's stack.*

Usage: `/ciel-recommend` — reads `ciel-overlay.md` for stack context.

---

## What it does

1. Reads your stack from `ciel-overlay.md` (or detects from project files if no overlay)
2. Searches the live plugin ecosystem for each detected technology:
   - Official marketplace (`claude-plugins-official`)
   - Community repos: `ccplugins/awesome-claude-code-plugins`, `ComposioHQ/awesome-claude-plugins`, `quemsah/awesome-claude-plugins`
3. Filters by relevance, maintenance, and install count
4. Presents recommendations with install commands
5. Skips anything already installed

---

## Step 1 — Detect stack

Read `ciel-overlay.md` → extract `## Domain Skills` and `## Stack` sections.
If no overlay → scan project root for `package.json`, `build.gradle.kts`, `go.mod`, `Cargo.toml`, `requirements.txt`.

## Step 2 — Search per technology (WebSearch for each)

For each detected technology, run:
- WebSearch: `site:github.com/ccplugins/awesome-claude-code-plugins [technology]`
- WebSearch: `site:github.com/ComposioHQ/awesome-claude-plugins [technology]`
- WebSearch: `Claude Code plugin [technology] recommended 2025 2026`

**Known high-value plugins by category** (verify still current via WebSearch):

| Stack signal | Plugins to investigate |
|---|---|
| TypeScript / React | `typescript-lsp@claude-plugins-official`, `frontend-design` |
| Kotlin / JVM | `kotlin-lsp@claude-plugins-official`, `backend-architect` |
| PostgreSQL / DB | `supabase@claude-plugins-official`, `database-mastery` |
| Testing (any) | `test-writer-fixer`, `pr-review-toolkit@claude-plugins-official` |
| Auth / Security | `security-guidance@claude-plugins-official` |
| GitHub workflow | `commit-commands@claude-plugins-official`, `github@claude-plugins-official` |
| API design | `api-architecture`, `backend-architect` |
| Any project | `code-review@claude-plugins-official`, `hookify@claude-plugins-official` |

## Step 3 — Filter & rank

For each result found:
- `□` Active maintenance? (last commit < 6 months)
- `□` Has install instructions? (`/plugin install` or `claude plugin install github:...`)
- `□` Overlaps with already-installed skills? (if yes → skip, note it)
- `□` Adds something not covered by current Domain Skills?

## Step 4 — Present recommendations

Format per plugin:
```
## [Plugin name]
Purpose: [what it does in 1 line]
Install: /plugin install name@marketplace
      OR: claude plugin install github:user/repo
Source: [URL]
Why: [specific reason it fits your stack]
```

If a plugin is already covered by a local skill → note it:
```
→ Already covered by: [local-skill-name] — skip or complement
```

## Step 5 — Post-install

After installing any plugin:
1. Run `/reload-plugins` to activate without restart
2. Add it to `ciel-overlay.md` under `## Domain Skills`
3. It will then be auto-invoked by Ciel's Domain skill boost at RECHERCHE

---

## Notes

- **Official marketplace** is pre-configured — no setup needed: `/plugin install name@claude-plugins-official`
- **GitHub plugins**: `claude plugin install github:owner/repo` (public repos only)
- **Community repos**: browse `github.com/ccplugins/awesome-claude-code-plugins` for curated lists
- **LSP plugins** (`typescript-lsp`, `kotlin-lsp`) give real-time diagnostics after every file edit — highly recommended for any typed language project
