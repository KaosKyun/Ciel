# Ciel Learnings

## Build commands
- `cd .opencode && npx tsc --noEmit` -- verifier que le plugin compile

## Project patterns
- [2026-04-26] The plugin ciel.ts uses Node.js synchronous APIs (readFileSync, existsSync, writeFileSync, mkdirSync) for simplicity. No async needed for startup operations.

## Failure modes
- [2026-04-26] MISTAKE: 1ers edits dans `.opencode/plugins/ciel.ts` et `.opencode/agents/ciel.md` n'ont pas persiste → RULE: toujours verifier apres edit avec `git diff` ou `stat` que le fichier a ete modifie. Si l'utilisateur re-installe (bash install.sh), les fichiers sources ecrasent les modifications.
- [2026-04-26] MISTAKE: install.sh local `cp src dst` echoue quand src==dst (identical files) → RULE: toujours utiliser `cp -n || true` dans les scripts d'install pour les cas locaux
- [2026-04-26] MISTAKE: `.claude/settings.json` JSON invalide → RULE: toujours valider le JSON apres modification avec `node -e "JSON.parse(...)"`
