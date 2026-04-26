# Ciel Learnings

## Build commands
- `cd .opencode && npx tsc --noEmit` -- verifier que le plugin compile

## Project patterns
- [2026-04-26] The plugin ciel.ts uses Node.js synchronous APIs (readFileSync, existsSync, writeFileSync, mkdirSync) for simplicity. No async needed for startup operations.
