# Ciel session progress — 2026-04-17

## Current status

v2.5.0 shipped and pushed to `origin/main` at commit `2da8ab2`. Stop hook confirmed firing — indicates user-scope `~/.claude/settings.json` merge is live and Ciel hooks are active session-wide.

## Completed this session (v2.4.0 → v2.5.0)

- **v2.4.0** — OpenCode real plugin context injection + platform-aware `/ciel-init`. TS plugin rewired to use `experimental.chat.system.transform` + `tool.execute.after` output.output mutation. `chat.params.system.push` no-op fixed. `/ciel-init` auto-detects Claude vs OpenCode.
- **v2.4.1** — 4 audit discipline fixes + command-skill description dedup.
- **v2.4.2** — Delete `/ciel` + `/ciel-improve` command files (Claude auto-routes `/name`→skill, removes duplicate skill-picker entries).
- **v2.4.3** — REWORK Fix 3 (depth-classifier mechanical signals for PR/CI), STRENGTHEN Fix 2 (broaden tool list to every file-mutation path), STRENGTHEN Fix 4 (generalize merge paths + mirror in pr-opener).
- **v2.4.4** — Hygiene pass: consolidate dispatch-gate block, promote mid-session re-routing into routing-table header, strip `(added vX.Y.Z)` meta-tags, visible `[CIEL N/5]` counter rule + OpenCode parity restored for `/ciel` + `/ciel-improve` via thin wrappers. AGENTS.md title now carries version.
- **v2.4.5** — `skill-freshness-auditor` + `/ciel-refresh`. Outside-world-driven audit of external references (URLs, library pins, research citations).
- **v2.4.6** — `/ciel-update` OpenCode-safe. Preserve `opencode.json` + `.claude/settings.json` across uninstall/reinstall. Non-destructive merge via Python.
- **v2.4.7** — `/ciel-update` bypasses raw.githubusercontent CDN cache (3-layer cache-bust).
- **v2.5.0** — Mechanical dispatch-gate counter (`pre-tool-count.sh` deny + `post-tool-count.sh` increment/reset-on-Task) + 5 audit-driven fixes (wrong-CWD warn in `/ciel-init` Step 0b, "Inline-OK ≠ pipeline-skip" clarification, `Self-authored rule drift` guard #38, user-scope `~/.claude/settings.json` merge).

## Failed approaches + why they failed

- **`chat.params.output.system.push` depth-hint injection** (v2.4.0 pre-fix) — silently no-op because `chat.params` has no `system` field in the published `@opencode-ai/plugin` types. Verified via `.d.ts` inspection. Correct hook: `experimental.chat.system.transform` (has `system: string[]`).
- **`console.log` for FAIRE/RELIRE reminders in OpenCode** (v2.4.0 pre-fix) — goes to terminal/plugin log, never into model context. Correct path: mutate `output.output` in `tool.execute.after` (tool result string the model reads).
- **PostToolUse `decision:"block"` for dispatch gate** (v2.5.0 initial plan) — @ciel-explorer caught it before write: PostToolUse block is a no-op (tool already ran). Forced the dual-hook design: PreToolUse `permissionDecision:"deny"` for the actual block, PostToolUse for counter increment only.
- **`/ciel-init` no-flag in a subdirectory-of-CWD** (audit violation #1) — writes `./Ciel/.claude/settings.json` when the running Claude Code session's CWD is one level higher. The file is never loaded. Fix in v2.5.0 Step 0b: CWD sanity warn suggesting `--user`.
- **Visible-counter rule as pure SKILL.md text** (v2.4.4 Fix 1 strengthening) — decays within 1-2 turns. Author wrote it, applied exactly once, then forgot across subsequent Standard work. v2.5.0 replaces with hook-based mechanical counter.

## Known limitations

- **OpenCode parity gap on dispatch-gate counter** — v2.5.0 `pre-tool-count.sh` + `post-tool-count.sh` are Claude-only (bash + stdin JSON). OpenCode's TS plugin doesn't yet have equivalent enforcement. Proposed for v2.5.1.
- **OpenCode `session.idle` handler absent** — Claude's Stop-hook-fires-meta-critiquer has no OpenCode analogue. OpenCode users get only inline meta-critiquer (when I remember to invoke it).
- **OpenCode `experimental.session.compacting` handler absent** — no session-progress write on compaction for OpenCode users.
- **`[CIEL N/5]` counter requires `session_id` in stdin** — if Claude Code's hook stdin schema changes the field name, the counter silently breaks. Mitigation: hooks include `CIEL_TRACE_ID` env fallback (from `session-start.sh`).
- **Counter file at `/tmp` — not Windows-safe** — the `.ps1` hooks use `$env:TEMP` but bash hooks hardcode `/tmp`. On Windows WSL this works; on pure Windows bash it breaks. Low priority — most users are Unix.

## Next steps (prioritized)

1. **v2.5.1 OpenCode counter port** (P1) — ~80 LoC TS added to `platforms/opencode/.opencode/plugins/ciel.ts`. Uses closure `Map<sessionId, count>` for state. `tool.execute.before` for deny, `tool.execute.after` for increment/reset. Wire `session.idle` to fire meta-critiquer via `output.system.push`. Wire `experimental.session.compacting` to write session-progress.
2. **v2.5.2 hygiene** (P2) — remove any remaining `(added vX.Y.Z)` tags that slipped in. Verify reference.md guard count stays accurate after future additions. Add a freshness-audit cadence doc to README.
3. **v2.6.0 Custom Ciel mode for OpenCode** (P3) — expose Ciel as a named OpenCode custom mode (alongside `build`/`plan`) with pre-configured per-tool permissions matching Ciel discipline.

## Session health

- 130+ total tool calls across the session
- 2 `Task()` dispatches (v2.4.3 improver+critic parallel, v2.5.0 explorer design review)
- Dispatch discipline was partial in v2.4.5 + v2.4.6 work — flagged in audit, fixed in v2.5.0 via "Inline-OK ≠ pipeline-skip" clarification + mechanical counter
- Stop hook now active (this session's final evidence) — v2.5.0 user-scope merge successful
