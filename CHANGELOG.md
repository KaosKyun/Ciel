# Ciel — Changelog

## v2.7.1 — 2026-04-17 — PowerShell install script syntax fix

### Fixed

- **install.ps1 line 131**: Changed `for ($a in @(...))` to `foreach ($a in @(...))` — fixes `Invoke-Expression: Unexpected token 'in'` error when running `irm ... | iex` installation on PowerShell.

---

## v2.7.0 — 2026-04-17 — Stop-hook `release-gate` — mechanical release discipline

**Context** — v2.6.0 rattrapage answered the immediate backlog (20+ `feat:` commits since v2.0 with zero tags). v2.7.0 prevents recurrence by adding the mechanical enforcement layer, following the same philosophy as v2.5.0's `pre-tool-count.sh` dispatch-gate counter: rules that must hold across many turns need hook-side enforcement, not SKILL.md text.

### Added — release-gate chained into `hooks/stop.sh`

When the user's Claude Code session ends AND the user's repo is on its default branch (`main`/`master`) AND **3 or more** unreleased conventional commits (`feat:` / `feat(scope):` / `feat!:` / `fix:` / `fix(scope):` / `fix!:`) exist past the last `git describe --tags --abbrev=0`, the Stop hook prepends a `CIEL RELEASE-GATE` reminder to the existing meta-critiquer `decision:"block"` reason — a single block event combines both instructions, preserving the `stop_hook_active` loop guard.

Threshold rationale: 1-2 pending commits is normal work-in-progress; 3+ is when release-discipline drift becomes real. Tuned against v2.x history.

Reminder content — enumerated actions aligned with pipeline steps 16-17: (1) bump VERSION per conventional-commit scope (feat=minor, fix=patch, `feat!`/`fix!`=major), (2) append CHANGELOG.md entry, (3) `git tag -a v<N.N.N>`, (4) `gh release create v<N.N.N> --generate-notes`. Points to `changelog-updater` + `release-publisher` skills.

Snooze escape hatch: `touch .ciel-release-snooze` at repo root disables the gate for 60 minutes (mirrors `session-start.sh`'s `find -mmin +1440` throttle idiom). Auto-expires — no forgot-to-delete footgun.

PowerShell parity: `hooks/stop.ps1` updated with equivalent `Check-ReleaseGate` function. Same semantics, same thresholds, same snooze file.

### Added — `scripts/test-stop-hook.sh` smoke test

8 assertion cases covering: 3+ pending fires, fresh snooze silences, old snooze re-fires, feature-branch skips, `stop_hook_active=true` silent-exits, 2-pending below-threshold skips, non-git CWD silent, zero-tag repo fires on commits-from-HEAD. Run: `bash scripts/test-stop-hook.sh` — exits 0 on all-pass.

No existing hook-eval pattern exists in `evals/datasets/` — that harness is scoped to skill output, not hook stdout JSON. Smoke test sits under `scripts/` until a hook-eval runner is designed (deferred).

### Changed — `skills/ciel/reference.md`

Failure-mode table header `38 failure modes` → `39 failure modes`. New row **Release discipline drift** — documents the v2.0→v2.5.1 pattern and points to `hooks/stop.sh` v2.7.0 as the mechanical guard.

### Known non-goals

- **OpenCode parity deferred** to v2.8.0. `session.idle` handler shape is still `.d.ts`-unverified per v2.5.1 CHANGELOG — shipping release-gate in the OpenCode TS plugin without verification would repeat the deferral pattern. `scripts/build-platforms.sh` unchanged in this release; `LIMIT_opencode_plugin` stays at 12288.
- **No hook-eval dataset**. The existing `evals/` runner matches grep patterns against model output, not hook stdout JSON. A hook-eval runner is its own design — v2.8.0 target alongside the OpenCode parity work.
- **No GPG signing**. v2.6.0 tag was annotated, not signed (GPG absent on release host). Future releases can use Sigstore `gitsign` (keyless OIDC) once a CI pipeline ships via `cicd-pipeline-designer`.

### Test plan (executed before ship)

- [x] `bash scripts/test-stop-hook.sh` → 11 pass, 0 fail
- [x] Case 1: 3 feat/fix past v0.1.0 on main → `HAS_RG=yes HAS_META=yes`
- [x] Case 2: fresh `.ciel-release-snooze` → `HAS_RG=no HAS_META=yes`
- [x] Case 3: 60+min old snooze → `HAS_RG=yes`
- [x] Case 4: feature branch → `HAS_RG=no`
- [x] Case 5: `stop_hook_active=true` → silent exit
- [x] Case 6: 2 pending (below threshold) → `HAS_RG=no`
- [x] Case 7: non-git CWD → `HAS_RG=no HAS_META=yes`
- [x] Case 8: zero tags + 3 commits → `HAS_RG=yes` (falls back to `HEAD` range)

---

## v2.6.0 — 2026-04-17 — GitHub workflow + CI/CD skills + install.ps1 parity

**Context** — Release discipline drift caught by user observation: v2.0 → v2.5.1 shipped 20+ `feat:` commits with zero git tags and zero GitHub releases. `release-publisher` + `changelog-updater` skills exist in orchestrator pipeline steps 16-17 but were never triggered because no one created the version-bump commit. v2.6.0 is the rattrapage: one release PR covering three commits on `main` that post-date the v2.5.1 CHANGELOG entry.

### Added — 6 new skills (commit 37ec823, PR #16)

- **`pr-merger`** — safe `gh pr merge --auto` with branch-protection awareness, draft→ready flip, strategy (squash/rebase/merge) from repo config. Gated by `prouver-verifier` VERDICT=DONE.
- **`pr-review-responder`** — GraphQL review-thread list, classify accept/reject/clarify, apply fixes, resolve threads, re-request review. Invoked on `CHANGES_REQUESTED`.
- **`ci-watcher`** — `gh run watch` streaming, flaky classification (≥15% main fail rate → auto `gh run rerun --failed`), real failure → `debug-reasoning-rca` handoff.
- **`branch-cleaner`** — `git branch --merged` local delete, `git fetch --prune` stale refs, opt-in `git push origin --delete` per-branch.
- **`release-publisher`** — signed tag (`git tag -s`) + `gh release create --generate-notes` + Sigstore attestations + pre-release auto-detect (`-rc` / `-beta` / `-alpha` suffix).
- **`cicd-pipeline-designer`** — greenfield CI/CD generator for Node/Go/Python/Kotlin/Rust with OIDC, build matrix, caching, test pyramid, deployment strategies, monorepo, SLSA L3. Ships with 614-line `reference.md`.

### Changed — `skills/ciel/SKILL.md` orchestrator pipeline

Standard pipeline extended with steps 11-17 (ci-watcher → pr-review-responder → pr-merger → issue-closer → branch-cleaner → changelog-updater → release-publisher). Intent routing table gained 6 new rows (`merge PR`, `respond to review`, `watch CI`, `clean up branches`, `publish release`, plus CI/CD workflow rows). Inline-OK skills list extended with all workflow utility skills.

### Fixed — `scripts/install.ps1` parity (commit 1ed1d34)

PowerShell installer caught up with `install.sh` v2.4.0 feature set — `--update` flag, `ciel-update` support, preserve-list for user-customized files, semver guard against CDN-stale downgrade loop.

### Chore — `.gitignore` (commit d29f691)

Added `.claude/session-progress.md` — project-scope session state should not be version-controlled.

### Known non-goals

- `release-publisher` was documented but never *tested* end-to-end on this repo until now. v2.6.0 is its first real invocation — the tag + release creation step validates the skill on the production repo.
- No CI workflow exists in `.github/workflows/` yet — `ci-watcher` skill is ready but has nothing to watch. A future release will add `cicd-pipeline-designer` output (lint + shellcheck for hooks + skill-frontmatter validator).
- Automation of the release trigger itself is deferred to **v2.7.0** (Stop-hook `release-gate` that nags when `feat:`/`fix:` commits exist past the last-tagged VERSION).

---

## v2.5.1 — 2026-04-17 — OpenCode dispatch-gate counter port + README refresh

**Context** — v2.5.0 shipped the mechanical dispatch-gate counter as shell hooks (Claude Code only). User asked whether everything differs between Claude and OpenCode, and flagged that README still described v2.0.0 architecture. v2.5.1 closes the biggest parity gap and refreshes the README.

### Changed — `scripts/build-platforms.sh` `emit_opencode_plugin` (dispatch-gate counter port)

TS-plugin port of the Claude `pre-tool-count.sh` + `post-tool-count.sh` pair. Design validated by `@ciel-explorer` before write — the explorer flagged three risks (throw-to-reject unverified, `session.idle` shape unverified, `experimental.session.compacting` shape unverified). Scope tightened to ship only the counter this release; the other two handlers DEFERRED pending `.d.ts` verification.

Added to the plugin closure state (alongside existing `writtenFiles` / `remindedFiles` / `relireSticky` / `lastDepthHint`):

- `const dispatchCounter = new Map<string, number>()` — per-session count.
- `const INLINE_GATHER_TOOLS = new Set(["bash", "read", "grep", "glob"])` — match set.
- `const getSessionKey(input)` — best-effort reader with fallback to `"__default"` bucket (input shape for `tool.execute.*` is partially documented; `sessionID` / `session_id` / `sessionId` all attempted).

Added handlers:

- **`tool.execute.before`** — on `bash|read|grep|glob` with count ≥ 5: defense-in-depth rejection. (a) `console.error` the HARD-STOP message (terminal visibility), (b) mutate `output.args` to `{ __ciel_hardstop__: msg }` so the tool call fails at the arg-validation layer if the runtime swallows throws, (c) `throw new Error(msg)` assumed-semantic throw-to-reject. At least one of these three channels will halt the call on any reasonable runtime.
- **`tool.execute.after`** — extended with an early branch before the existing `write|edit` logic. On `task` → `dispatchCounter.delete(sid)` (dispatch refreshes budget). On `bash|read|grep|glob` → increment counter. Existing `write|edit` FAIRE/RELIRE logic untouched below.

Explorer notes preserved in code comments — future release can verify the `.d.ts` and tighten semantics.

### Deferred — OpenCode parity gaps NOT in this release

- **`session.idle` meta-critiquer**: Claude fires `meta-critiquer` on Stop; OpenCode equivalent needs `session.idle` handler. Shape unverified — explorer proposed two-step flag + `experimental.chat.system.transform` consume pattern. Target: v2.6.0.
- **`experimental.session.compacting` progress write**: Claude's `pre-compact.sh` writes `.claude/session-progress.md`. OpenCode equivalent would need the compacting hook. Shape unverified; side-channel `fs.promises.writeFile` always works but output-mutation is treated read-only. Target: v2.6.0.

### Changed — `scripts/build-platforms.sh` `LIMIT_opencode_plugin`

Bumped 8192 → 12288. The counter port added ~1.5KB (handlers + state + comments). Plugin loads once per session — ~4KB headroom is not a per-turn cost.

### Changed — `README.md`

Full refresh for the v2.0 → v2.5.1 evolution. Fixed:

- Skill count: 33 → ~50 (workflow 20 + research 6 + domain 10 + utility 8 + meta 5 + orchestrator 1).
- Command list: 6 → 7 slash commands (`/ciel-audit`, `/ciel-init`, `/ciel-refresh` added; `/ciel` + `/ciel-improve` removed as command files per v2.4.2 — Claude Code auto-routes `/<name>` → same-named skill; OpenCode gets thin wrappers). Note added.
- Hook list: 7 → 9 events (added `PreToolUse` / `PostToolUse` counter entries). Clarified that the counter hook is the only one that blocks.
- Platform table: removed stale "AGENTS.md ≤ 30KB Medium" — OpenCode now uses native primitives (TS plugin + subagents + commands).
- Install flow: added note that `/ciel-init --user` + restart is required for hooks to fire. Without it, silent no-op.
- Self-update: updated paths (network one-liner + plugin path + repo clone), mentioned v2.4.7 cache-bust + v2.4.6 preserve-list.
- Self-improvement section: added `/ciel-refresh` (outside-world-driven) on orthogonal axis to `/ciel-improve` (transcript-driven).
- Hooks table: removed "Hooks never block writes" line (no longer true as of v2.5.0).
- Research basis: added CriticBench 2024 reference (motivates fresh-fork dispatch).

### Regenerated

`platforms/opencode/.opencode/plugins/ciel.ts` — now 9638 bytes (was ~6.1KB). `platforms/opencode/AGENTS.md` — title bumped to v2.5.1.

### Known non-goals

- `.d.ts` verification — still only asserted via code comments, not a file check-in. Pre-v2.6.0 work item: add a `bun install @opencode-ai/plugin && cp node_modules/.../index.d.ts tests/fixtures/` step so design decisions have a canonical reference.
- Counter-throw verification — relies on `console.error` + args mutation + throw (three channels). A regen-test on real OpenCode would confirm at least one channel halts; not yet automated.

---

## v2.5.0 — 2026-04-17 — Mechanical dispatch-gate counter + audit-driven fixes

**Context** — `/ciel-audit` on the v2.4.7 session surfaced 4 violations:

1. **Hooks inactive for entire session** (critical) — `/ciel-init` (no flag) wrote `./Ciel/.claude/settings.json` in a repo subdirectory, but the running Claude Code session's CWD was the PARENT of the repo. The file was never loaded. No Ciel signatures (`CIEL depth hint:`, `CIEL <filepath>`, META-CRITIQUER) appeared in 130+ tool calls.
2. **Dispatch discipline partial violation** (medium) — 2 Standard tasks (v2.4.5, v2.4.6) went inline through FAIRE without dispatching `@ciel-researcher` / `@ciel-explorer`. The audit traced this to ambiguity between `SKILL.md:42-57` (Standard mandates parallel dispatch) and `SKILL.md:251-266` (Inline-OK list includes `skill-creator`).
3. **Self-authored rule drift** (medium, meta-failure) — the `[CIEL N/5]` visible counter rule I authored in v2.4.4 was applied exactly once, then forgotten across v2.4.5, v2.4.6, v2.4.7 work. Pure SKILL.md text depending on self-counting decays within 1-2 turns.
4. **`meta-critiquer` never invoked as a skill** (low) — inlined concept, skill itself bypassed. Fixes itself after violation #1 is resolved (Stop hook auto-fires meta-critiquer).

v2.5.0 applies all 5 audit fixes as one release.

### Added — `hooks/pre-tool-count.sh` + `hooks/post-tool-count.sh` (+ `.ps1` parity)

Mechanical dispatch-gate counter — the missing piece that makes the `[CIEL N/5]` rule actually enforceable. Verified design by `@ciel-explorer` review against existing hooks + Claude Code schema:

- **`pre-tool-count.sh`** — fires on `PreToolUse` matcher `Bash|Read|Grep|Glob`. Reads counter at `/tmp/ciel-counter-$session_id`. Under 5 → injects `[CIEL COUNTER: N/5]` via top-level `systemMessage` (visible to model). At 5+ → emits `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"[CIEL HARD-STOP] ..."}}` — the only schema-valid hard-block on PreToolUse.
- **`post-tool-count.sh`** — fires on `PostToolUse` matcher `Bash|Read|Grep|Glob|Task`. On `Task` → deletes the counter file (budget refreshes post-dispatch). On any other matched tool → increments counter by 1.
- Missing counter file is treated as N=0 (implicit reset on new sessions — no explicit cleanup hook needed).
- `@ciel-explorer` audit verdict (before write): YELLOW — flagged that PostToolUse `decision:"block"` is a NO-OP (tool has already run), forcing the dual-hook design. Now green.
- PowerShell parity via `pre-tool-count.ps1` + `post-tool-count.ps1` (same logic, `$env:TEMP` for tmp path).

### Changed — `settings.json` template

Added the new `PreToolUse` + `PostToolUse` entries alongside the existing `Write|Edit` matcher (two entries per event — Claude Code supports multiple matchers per event array).

### Changed — `commands/ciel-init.md`

- **Step 0b — Wrong-CWD sanity check (new)** — fixes audit violation #1. Before writing the project-scope file, emit `[CIEL-INIT WARN]` if the resolved target directory differs from the running Claude Code session's CWD (suggests `--user` as the safer fallback).
- **Step C2 canonical hooks block** — now includes the new `pre-tool-count.sh` + `post-tool-count.sh` registrations with the correct matchers.

### Changed — `skills/ciel/SKILL.md` (Inline-OK ≠ pipeline-skip)

Fixes audit violation #2. Added a paragraph right before the anti-pattern block clarifying that inline-OK status applies to a specific skill invocation — not the surrounding pipeline. Standard tasks that use `skill-creator` / `ciel-improve` / `skill-variant-evaluator` inline still owe: `quoi-framer` → `@ciel-explorer` scope-overlap check → FAIRE → `@ciel-critic` RELIRE (if ≥3 files) → `meta-critiquer`.

### Changed — `skills/ciel/reference.md`

- Header count bumped from `37 failure modes` → `38 failure modes`.
- New row: **Self-authored rule drift** — captures the meta-failure surfaced by audit violation #3. Mitigation: mechanical enforcement required for any rule that must hold across >5 turns. Points to v2.5.0 `pre-tool-count.sh` / `post-tool-count.sh` as the canonical implementation of this principle.

### Merged — `~/.claude/settings.json` (user-scope, this session)

As part of the audit-fix delivery, merged the full 9-event Ciel hook block (7 existing + 2 new) into `~/.claude/settings.json`, preserving the user's existing `skipAutoPermissionPrompt` and `permissions` keys non-destructively. Backup written to `~/.claude/settings.json.bak-<timestamp>`. After the user restarts Claude Code, hooks are active globally (all sessions, regardless of CWD).

### Verification procedure

After install + Claude Code restart:

1. Any Standard+ prompt → system-reminder contains `[CIEL depth hint:]`.
2. Issue 4 inline Bash/Read/Grep calls → 4th call surfaces `[CIEL COUNTER: 5/5]`.
3. Issue a 5th inline call → denied with `[CIEL HARD-STOP]` reason.
4. Dispatch any `Task(...)` → counter resets; inline calls resume.
5. End the session → Stop hook fires meta-critiquer.

### Regenerated

`platforms/opencode/.opencode/plugins/ciel.ts` — version string bumped to v2.5.0.
`platforms/opencode/AGENTS.md` — title bumped to v2.5.0.

### Note for OpenCode users

The dispatch-gate counter is **Claude Code only** for v2.5.0. OpenCode's plugin model (TypeScript hooks) can implement an equivalent via `tool.execute.before` mutating `output.args` to deny, but: (a) OpenCode's deny semantics may differ, (b) state would live in TS plugin closure rather than a file. A future release will port the counter to the OpenCode TS plugin; until then OpenCode users get only the visible-counter discipline rule (self-police).

---

## v2.4.7 — 2026-04-17 — `/ciel-update` bypasses raw.githubusercontent CDN cache

**Context** — User pushed v2.4.6, immediately ran `/ciel-update`, got served a stale v2.4.5 from `raw.githubusercontent.com`. The CDN fronting that URL has a ~5-minute TTL; any `/ciel-update` fired in that window re-installs the previous version silently.

`_check_update` (VERSION compare) already cache-busts. `_do_update`'s re-fetch of `install.sh` itself did not.

### Changed — `scripts/install.sh` `_do_update`

The re-fetch curl now mirrors the `_check_update` pattern:

```bash
curl -fsSL \
  -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' \
  "https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh?t=$(date +%s)"
```

Three layers of cache-bust (query param that some proxies honor, Cache-Control header that most CDNs honor, Pragma header for older HTTP/1.0 intermediaries). Fresh blob returned even within minutes of a push.

### Workaround if you're on v2.4.6 or earlier and want to update now

One of:

```bash
# Option A — run from local repo clone (zero network, direct bits)
bash /path/to/Ciel/scripts/install.sh -y

# Option B — cache-bust manually from the command line
bash <(curl -fsSL -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' \
  "https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh?t=$(date +%s)") -y
```

After running v2.4.7 once, all future `/ciel-update` invocations are cache-bust-safe.

---

## v2.4.6 — 2026-04-17 — `/ciel-update` OpenCode-safe (no more config wipe)

**Context** — User asked whether `/ciel-update` works on OpenCode. It technically did (the installer detects `opencode` in PATH and calls `install_opencode()`), but with two real bugs:

1. **User's `opencode.json` was deleted and replaced with the fresh template on every update.** Custom `model`, `provider`, `mcp`, `keybinds`, `permission`, and any other top-level keys were lost. The uninstall `preserve_re` whitelist covered only `.mcp.json` and `ciel-overlay.md` — `opencode.json` was tracked in the manifest and therefore removed.
2. **Command text was Claude-centric.** `commands/ciel-update.md` pointed at `~/.claude/plugins/ciel/scripts/install.sh`, a path that does not exist for OpenCode-only users. No fallback was shown for the `curl | bash` one-liner or the repo-clone path.

v2.4.6 fixes both.

### Changed — `scripts/install.sh` `_do_uninstall` preserve list

Added three paths to the uninstall whitelist alongside `.mcp.json` and `ciel-overlay.md`:

- `opencode.json` + `opencode.json.bak-*` — OpenCode config (model/provider/mcp/permission/keybinds). Re-install now merges non-destructively instead of overwriting.
- `.claude/settings.json` + `.claude/settings.json.bak-*` — project-scope Claude config written by `/ciel-init`. Contains absolute per-machine `$CIEL_DIR` hook paths; blowing it away on update would force a re-run of `/ciel-init` every time.

Consolidated regex: `(\.mcp\.json(\.backup-|$)|ciel-overlay\.md$|opencode\.json(\.bak-|$)|\.claude/settings\.json(\.bak-|$))`.

### Changed — `scripts/install.sh` `install_opencode()` merge path

When `opencode.json` already exists at the target path (always true after v2.4.6 because it's now preserved across uninstall), the installer runs a Python-based non-destructive merge — the same pattern as `/ciel-init` OpenCode branch:

- Ensures `"$schema": "https://opencode.ai/config.json"` is present.
- Ensures `"instructions"` is an array containing `"AGENTS.md"` (adds without dropping existing entries).
- Ensures `"plugin"` is an array containing `"./.opencode/plugins/ciel.ts"` (adds without dropping existing entries).
- Preserves every other top-level key exactly as-is.
- Writes a `opencode.json.bak-<timestamp>` before the merge.

Fallback path: if `python3` is not available, the installer warns and leaves `opencode.json` untouched (asks the user to merge manually). This is the same graceful-degradation pattern as `_install_mcp`.

### Changed — `commands/ciel-update.md`

Full rewrite for multi-platform clarity:

- Three invocation paths documented: plugin-install path, repo-clone path, network one-liner (the latter is the answer for OpenCode-only users and fresh machines).
- Expanded `What's preserved` section covers all 4 whitelisted files with explanations.
- New `OpenCode specifics` section enumerates exactly which `.opencode/` files get touched vs preserved.
- New `Troubleshooting` section covers the 4 most common failure modes (no manifest, network block, local-ahead-of-remote, plugin-not-found-after-update-needs-restart).
- Frontmatter description updated to mention all whitelisted files, not just `.mcp.json` and `ciel-overlay.md`.

### Regenerated

`platforms/opencode/.opencode/commands/ciel-update.md` — picks up the new multi-platform body automatically via the `build_opencode` loop over source `commands/*.md`.

### Verification (manual, recommended after applying)

1. Before update: `cat opencode.json` (note your custom keys).
2. Run `/ciel-update` or `bash scripts/install.sh --update`.
3. After update: `cat opencode.json` → every custom key still present; `plugin` array contains `./.opencode/plugins/ciel.ts`; `instructions` array contains `AGENTS.md`.
4. Check `ls opencode.json.bak-*` — backup exists from the merge phase.

---

## v2.4.5 — 2026-04-17 — `skill-freshness-auditor` + `/ciel-refresh`

**Context** — User feedback: Ciel's self-improvement subsystem only catches what Ciel *experienced* (via `/ciel-improve` on session transcripts). It does not catch what *changed outside* — a library pin that became two majors outdated, a docs URL that 404s, a research paper that was superseded. Skills silently age against external reality until a failure finally triggers them. This release adds the missing outside-world-driven audit pass.

### Added — `skills/meta/skill-freshness-auditor/SKILL.md`

New meta-skill that scans every `SKILL.md` and `reference.md` under `$CIEL_DIR/skills/`, extracts three categories of external references, and checks each for freshness:

| Category | Check | Severity triggers |
|---|---|---|
| URLs | `WebFetch` → 200 OK + Last-Modified | 404 = HIGH, redirect elsewhere = MEDIUM, >18mo = MEDIUM |
| Library + version pins | `WebSearch` for latest stable | 1+ major behind = MEDIUM, removed-from-registry = HIGH |
| Research citations | `WebSearch` for a named superseder | Newer named version exists = LOW-MEDIUM |

Produces a `freshness patch-set` one entry per stale ref (same approval-gated format as `ciel-improve`). Logs to `.freshness-log.jsonl` so repeated runs cache-hit and skip recently-checked refs. Max 5 patches per run (same cap as `ciel-improve`). Never autonomous rewrite.

**Complements, does not replace**:
- `ciel-improve` = transcript-driven (inside signal).
- `skills-first-design-auditor` = structure-driven (frontmatter, length, form).
- `skill-freshness-auditor` = currency-driven (content vs external reality). Orthogonal axis.

### Added — `commands/ciel-refresh.md`

Slash trigger for `skill-freshness-auditor`. Usage: `/ciel-refresh [scope] [--force]`. Scope defaults to `all`; can narrow to `workflow|research|domain|utility|meta|ciel` or `skill=<name>`. `--force` bypasses the 18-month URL cache.

Auto-routed via `skills/ciel/SKILL.md` intent routing — prompts like "are skills outdated?", "check library versions in skills", "refresh skills" trigger dispatch to `@ciel-improver` running `skill-freshness-auditor`.

### Changed — `skills/ciel/SKILL.md`

- Intent routing table: new row for `skill-freshness-auditor` → `@ciel-improver` via `/ciel-refresh`.
- Self-improvement section: new `/ciel-refresh` line, with explicit contrast to `/ciel-improve` (transcript-driven vs outside-world-driven).

### Regenerated

`platforms/opencode/.opencode/commands/ciel-refresh.md` — loop in `build_opencode` picks up new command source automatically. OpenCode users get `/ciel-refresh` without extra work.

### Cost notes

- Per-skill scan: ~1-3K tokens (depends on how many refs + how many WebFetch/WebSearch each triggers).
- Full scan (~50 skills): 100-300K tokens on first run, much cheaper after (cache hits dominate).
- Projected cost displayed before the network phase — abortable.

### Recommended cadence

- Monthly routine.
- Before any major release bump (so the release ships without stale pins).
- After an observed upstream major release (Anthropic API, Claude Code, OpenCode, Playwright, etc.).

---

## v2.4.4 — 2026-04-17 — Hygiene + visible dispatch counter

**Context** — After v2.4.3 landed the semantic fixes, the @ciel-improver report flagged two form-level issues: duplication of the dispatch-gate block (budget rule stated twice, once at line 152, once at 154, plus a 3rd in reference.md's guard), and the mid-session routing rule sitting below the routing table as a post-script readers often miss. Also: `(added vX.Y.Z)` meta-tags were leaking from the skill body (they belong in `CHANGELOG.md`, not in the source-of-truth skill files — they age into archaeology). This release cleans all three, plus introduces a visible-counter discipline rule to address the v2.4.3 "not-addressed" item on Fix 1 (DISPATCH GATE mechanical counter).

### Changed — `skills/ciel/SKILL.md`

- **Intent routing section** — re-scan directive hoisted to a bold one-liner right above the table: "Scan (a) at invocation against prompt text, AND (b) on every file-mutation tool call against target path." The long tool-list prose that was sitting 25 lines below the table is now one line above it. Concrete examples kept.
- **Dispatch-gate block** — consolidated. The "Budget: max 5 … whichever comes first" line merges into the `[DISPATCH GATE]` emit instruction. No more two separate paragraphs saying the same budget.
- **Visible counter rule (new)** — on any Standard+ task, every inline `Bash`/`Read`/`Grep`/`Glob` tool call's `description` field must be prefixed with `[CIEL N/5]`. Example: `description="[CIEL 3/5] gh pr checks 1014"`. The counter appears in the tool-call history so the model on its next turn can see the count without maintaining a separate running log. A hook-based mechanical counter (PostToolUse on `Bash|Read|Grep` injecting a systemMessage with the real count, HARD-STOP at N=5) is planned for v2.5.0 — needs settings.json template changes + /ciel-init update.
- **Meta-tag strip** — removed the `(added v2.4.1 after PR-review audit)` annotation from the DISPATCH GATE paragraph. Discipline rules stand on their own; the why-it-was-added history belongs in this CHANGELOG.

### Changed — `skills/workflow/depth-classifier/SKILL.md`

- Stripped `(added v2.4.3 per 2026-04-17 audit — previously mis-classified as Trivial)` and `(added v2.4.3)` meta-tags from the PR-review signals block and the floor rule. Content unchanged.

### Changed — `skills/utility/pr-opener/SKILL.md`

- Stripped `(v2.4.3, mirror of ciel/SKILL.md line 54)` meta-tag from the merge-precondition guardrail. Replaced with a stable cross-reference "mirror of `skills/ciel/SKILL.md`" (no line number, since those shift).

### Verified

- `reference.md` line 87 claims "37 failure modes" — actual table row count is 37. ✅ Coherent, no change needed.

### Changed — OpenCode parity restored for `/ciel` and `/ciel-improve`

v2.4.2 deleted `commands/ciel.md` and `commands/ciel-improve.md` because Claude Code auto-routes `/<name>` → skill of the same name. OpenCode's slash-router behavior is not confirmed to do the same, so on OpenCode those two slash triggers would fail as "unknown command". `build-platforms.sh` now emits two OpenCode-only thin wrappers in `platforms/opencode/.opencode/commands/`:

- `ciel.md` (523 bytes) — invokes the `ciel` skill via the Skill tool with `$ARGUMENTS`.
- `ciel-improve.md` (534 bytes) — invokes the `ciel-improve` skill the same way.

The Claude side stays without these files (no duplicate entry in the skill picker — that was the v2.4.2 fix). OpenCode users get the full 8-command set: `ciel`, `ciel-improve`, `ciel-audit`, `ciel-create-skill`, `ciel-eval`, `ciel-init`, `ciel-recommend`, `ciel-update`.

New helper: `scripts/build-platforms.sh emit_opencode_skill_wrapper` — used for both files. Future same-name collisions can reuse it.

### Changed — `platforms/opencode/AGENTS.md` header now carries the version

`CIEL_VERSION` is injected into the title line: `# AGENTS.md — Ciel deep-reasoning workflow (OpenCode, v${VERSION})`. OpenCode users can verify the installed version at a glance without opening `opencode.json` or running `bash install.sh --check-update`. `emit_opencode_agents_md` refactored to echo the title first (variable-interpolated) and append the body via a literal heredoc (preserves backticks).

### Regenerated

`platforms/opencode/` — `AGENTS.md` (with version), `.opencode/plugins/ciel.ts` (version string), 2 new thin-wrapper command files.

### Known deferred to v2.5.0

- Hook-based mechanical counter for the dispatch gate (requires a new `hooks/post-tool-count.sh`, a settings.json matcher `Bash|Read|Grep`, per-session state file, and a `/ciel-init` update to wire all three).

---

## v2.4.3 — 2026-04-17 — Deepen v2.4.1 audit fixes (REWORK + STRENGTHEN)

**Context** — Two agents (`@ciel-improver` + `@ciel-critic`) re-audited v2.4.1's discipline fixes. Verdict: Fix 3 was **cosmetic** (flagged REWORK by critic), Fixes 2 and 4 were correct but **underspecified** (STRENGTHEN). Root cause of all three weaknesses: rules stated only in `ciel/SKILL.md` do not propagate to downstream skills that enforce them (depth-classifier, pr-opener, etc.) — the "single-site enforcement" meta-failure. v2.4.3 patches the enforcement sites themselves, not just the orchestrator table.

### Changed — `skills/workflow/depth-classifier/SKILL.md` (REWORK of v2.4.1 Fix 3)

Added two Standard-floor signals so PR-review-with-CI-fix can no longer be mis-classified as Trivial:

- **CI/CD file paths** — `.github/workflows/*.yml`, `.gitlab-ci.yml`, `.circleci/`, `Dockerfile`, `docker-compose*.yml`, `Jenkinsfile`, `.buildkite/`, `.drone.yml`.
- **PR-review signals** — prompt contains `#\d+` / "open PR" / "review PR" / "fix PR" / "merge PR", OR planned tool calls include `gh pr list|view|checks|review|merge` (any merge variant).

Added a **floor rule**: if any PR-review or CI/CD signal is present, depth is at minimum Standard — Trivial is disqualified even if the diff is small. v2.4.1's addition to the orchestrator Depth Gauge table was only a narrative example; the classifier itself (the mechanical gate) now has the signals.

### Changed — `skills/ciel/SKILL.md` mid-session re-routing (STRENGTHEN of v2.4.1 Fix 2)

v2.4.1 listed only `Edit` and `Write` as re-routing triggers. A `Bash(cat > .github/workflows/ci.yml)` heredoc would bypass the rule. v2.4.3 broadens to **any tool call that mutates a file** — native edit tools, `Bash` with redirect/heredoc/`sed -i`/`tee`/`cp`/`mv`/`install`/`patch`/`git apply`/`git checkout -- <path>`, and any MCP tool whose contract writes to disk.

### Changed — `skills/ciel/SKILL.md` prouver-verifier description (STRENGTHEN of v2.4.1 Fix 4)

v2.4.1 named only `gh pr merge --auto`. v2.4.3 generalizes to **every merge path** — `gh pr merge [--auto|--squash|--merge|--rebase]`, `git push` direct-to-default with admin bypass, and the GitHub UI "Merge" button. Added a pointer to the mirror in `pr-opener`.

### Changed — `skills/utility/pr-opener/SKILL.md` (mirror enforcement)

Added a guardrail mirroring the merge-precondition rule from `ciel/SKILL.md`. If `pr-opener` is asked to auto-merge (e.g., via a `--merge-when-green` intent), it must refuse unless `.git/ciel-prouver-verdict` exists with `verdict=PASS`. Fixes the "single-site invariant" meta-failure: a rule stated only in the orchestrator is invisible to forks that never read the orchestrator SKILL.md.

### Regenerated

`platforms/opencode/.opencode/plugins/ciel.ts` — version string bumped to v2.4.3.

### Known not-addressed-this-release

- Fix 1 (`[DISPATCH GATE]` hard-stop) — critic flagged MEDIUM "cosmetic-adjacent" because the emit still relies on the agent to self-count. A proper fix needs a mechanical counter (per-turn state) which is out of scope for SKILL.md-only patches. Left for a later release.
- Design consolidation from the `@ciel-improver` report (dedupe dispatch-gate block, promote mid-session rule into routing-table header, remove `(added vX.Y.Z)` meta-tags) — hygiene polish, not correctness. Left for a later hygiene pass.

---

## v2.4.2 — 2026-04-17 — Remove `/ciel` and `/ciel-improve` command files

**Context** — v2.4.1's "thin wrapper" fix reduced content duplication but both entries still appeared in the available-skills block (one as skill, one as command with the same name). The user reported "des doubles" — the visual duplicate name remained.

Per Claude Code documented behavior: **when a skill and a command share the same name, the skill takes precedence, and typing `/name` routes to the skill automatically via the Skill tool** ("or one the user explicitly typed as `/<name>` in their message"). The command file is redundant when a same-named skill exists.

### Removed

- `commands/ciel.md` — the `ciel` skill (`skills/ciel/SKILL.md`) handles `/ciel <task>` invocations directly.
- `commands/ciel-improve.md` — the `ciel-improve` skill (`skills/meta/ciel-improve/SKILL.md`) handles `/ciel-improve [scope]`.

### Preserved

- `commands/ciel-audit.md`, `ciel-create-skill.md`, `ciel-eval.md`, `ciel-init.md`, `ciel-recommend.md`, `ciel-update.md` — these have NO same-named skill, so there is no collision to dedupe. They remain as slash triggers.

### User-visible effect

- `/ciel <task>` and `/ciel-improve [scope]` continue to work. They now route directly to the skill with `$ARGUMENTS` treated as the task input.
- The available-skills block no longer lists the same name twice.

### Regenerated

`platforms/opencode/.opencode/commands/` — `ciel.md` and `ciel-improve.md` removed. OpenCode users type `/ciel <task>` and OpenCode's native `skill` tool picks up the `ciel` skill from `./.claude/skills/ciel/` (cross-platform — OpenCode reads `.claude/skills/` natively per its docs).

---

## v2.4.1 — 2026-04-17 — Orchestrator discipline + command-skill deduplication

**Context** — Two issues surfaced right after v2.4.0: (a) a post-hoc audit of a real `/ciel` session found that `researcher` + `explorer` were never dispatched and `.github/workflows/` edits skipped `cicd-security-hardener`, despite both being mandatory; (b) on install, `commands/ciel.md` + `skills/ciel/SKILL.md` (and same for `ciel-improve`) showed up as two near-identical entries in the available-skills list — confusing, looks like duplication.

### Changed — `skills/ciel/SKILL.md` (4 discipline fixes from the 2026-04-17 audit)

1. **Depth gauge row** — added `review open PRs + fix blocking CI` to the Standard examples. PR review with a CI fix is Standard, not Trivial — the classifier was reading it as low-effort.
2. **Dispatch gate hard-stop** — after the "whichever comes first" budget line, added an explicit `[DISPATCH GATE]` checkpoint instruction: on the 5th inline Bash/Read/Grep call of a Standard+ task, emit the checkpoint visibly to the user and dispatch Task() on the same turn. No "one more check first".
3. **Mid-session re-routing rule** — the intent routing table is no longer one-shot at `/ciel` invocation. Re-scan it on every Edit/Write using the target file path (e.g., first edit on `.github/workflows/` matches `cicd-security-hardener` → dispatch `@ciel-explorer` BEFORE writing). Catches late-emerging intents when a task's scope drifts.
4. **Auto-merge ordering constraint on `prouver-verifier`** — appended a MUST: complete prouver-verifier BEFORE `gh pr merge --auto`. Auto-merge is the consequence of the gate passing, not a parallel shortcut.

### Changed — `commands/ciel.md` + `commands/ciel-improve.md` (thin wrappers)

Both command files had ~60-70 lines re-stating what their same-named skills already document. They now ship as ≤20-line thin wrappers that invoke the matching skill via the Skill tool with `$ARGUMENTS`. The frontmatter `description` explicitly identifies them as "Slash trigger for the X skill" so they no longer visually collide with the skill's own description in the available-skills list. The skill is the single source of truth for the orchestration logic; the command is a UX shim.

### Changed — `scripts/build-platforms.sh`

- Added `CIEL_VERSION=$(cat VERSION)` at the top and interpolated it into the generated `ciel.ts` header comment (`// Ciel — OpenCode plugin (v${CIEL_VERSION})`). Future version bumps no longer drift the TS plugin comment.

### Regenerated

`platforms/opencode/.opencode/plugins/ciel.ts` (version string) + `.opencode/commands/ciel.md` + `ciel-improve.md` (thin wrappers).

### Intentional non-goals

- No rename of the `ciel` / `ciel-improve` skills or commands (would break muscle memory and existing references in SKILL.md / docs / README).
- No deletion of the command files (Claude Code needs a registered slash command to show `/ciel` in the picker — removing them would hide the trigger even though the skill still exists).

---

## v2.4.0 — 2026-04-17 — Real OpenCode parity, platform-aware `/ciel-init`

**Context** — The OpenCode build (`platforms/opencode/`) shipped since v2.1.0 was functionally broken for model-context injection: `chat.params.output.system.push(...)` was a silent no-op (`chat.params` has no `system` field in the published `@opencode-ai/plugin` types), and `tool.execute.before/after` reminders were `console.log` calls that reach the terminal, never the model. Verified against `@opencode-ai/plugin/dist/index.d.ts`. v2.4.0 rewires the plugin to use the verified-correct hooks and ports `/ciel-init` to OpenCode.

### Changed — `.opencode/plugins/ciel.ts` (via generator)

- Depth classification now runs in `experimental.chat.messages.transform` (reads the latest user text) and is injected every turn via `experimental.chat.system.transform` (pushes to `output.system: string[]`). No more no-op `chat.params.system.push`.
- Per-file FAIRE/RELIRE reminders now mutate `output.output` in `tool.execute.after`, which IS the tool-result string shipped to the model. The model reads the reminder attached to its own Write/Edit call on the next turn.
- Sticky RELIRE notice: once 3+ code files or a critical-pattern file has been written, every subsequent turn re-injects a system-prompt segment naming the files until `@ciel-critic` runs.
- Dropped `tool.execute.before` — its output is args-only; there is no way to inject context from it. Was previously a `console.log` that did nothing.

Source of truth: `scripts/build-platforms.sh` `emit_opencode_plugin`. Regenerate with `bash scripts/build-platforms.sh --target=opencode`.

### Changed — `commands/ciel-init.md` is now platform-aware

Auto-detects Claude vs OpenCode (project signals → installed CLIs → ask). Two branches:

- **Claude branch** — unchanged from v2.3.1. Merges `./.claude/settings.json` hooks block via `jq`, preserves non-Ciel entries, backs up to `.bak-<timestamp>`.
- **OpenCode branch** — new. Copies `.opencode/plugins/ciel.ts` + 4 subagents + 7 commands from `$CIEL_DIR/platforms/opencode/`; merges `./opencode.json` via Python (add `plugin`, add `instructions: ["AGENTS.md"]`, preserve every other key); copies `AGENTS.md` if absent. `--platform=claude|opencode` forces the branch; `--user` targets `~/.config/opencode/opencode.json`; `--check` dry-runs a diff.

### Changed — `scripts/build-platforms.sh`

- `LIMIT_opencode_command` bumped 8192 → 16384 to accommodate the platform-aware `ciel-init.md` body (12.3KB). Command files are loaded on-demand per slash invocation, not in session baseline — per-file byte count does not compound.
- `emit_opencode_plugin` rewritten per the plugin API verification above.

### Intentional non-goals

- No Claude-side hook changes (`hooks/*.sh`, `hooks/*.ps1` are unchanged from v2.3.1).
- No new skills.
- No npm-published plugin package (still ships as a project-scoped `./.opencode/plugins/ciel.ts` file).
- Non-Anthropic providers on OpenCode: `experimental.*` hooks may not fire for every provider — tested primarily against Anthropic via OpenCode. If depth hints don't appear, check `opencode --log-level=debug` for plugin errors.

---

## v2.3.1 — 2026-04-17 — Stop/PreCompact/PreToolUse hook JSON schema fix

- `hooks/stop.sh` + `.ps1` rewritten to use `{"decision":"block","reason":"..."}` with a `stop_hook_active` loop guard. The earlier `hookSpecificOutput.additionalContext` shape is rejected by the Stop event schema.
- `hooks/pre-compact.sh` + `.ps1` switched to top-level `{"systemMessage":"..."}` (PreCompact has no documented context-injection field; `systemMessage` is the universally-valid fallback).
- `hooks/pre-tool-write.sh` + `.ps1` same switch (PreToolUse `hookSpecificOutput` only accepts `permissionDecision` fields).

No behavior change for users aside from hooks actually firing again. Claude Code was silently rejecting the v2.3.0 JSON and continuing — reminders never landed in the model context.

## v2.3.0 — 2026-04-17 — `/ciel-init` + MCP routing + two new guards

- **`commands/ciel-init.md`** (new) — bootstraps/repairs `./.claude/settings.json` with absolute-path Ciel hook entries. Resolves `$CIEL_DIR` via candidate ladder (`$CLAUDE_PLUGIN_DIR`, `$HOME/.claude/plugins/ciel`, `/root/.claude/plugins/ciel`, `find` fallback). Preserves non-Ciel keys. Backs up before writing. `--check` dry-run, `--user` for `$HOME/.claude/settings.json`.
- **`skills/ciel/SKILL.md`** — added MCP-related intent routing row (`"mcp server"`, `".mcp.json"`, `"claude mcp"` → `debug-reasoning-rca` + `stride-analyzer` if secrets).
- **`skills/ciel/reference.md`** — 2 new failure modes (35 → 37): **Dispatch gate bypass** (>5 inline tool calls without any `Task()` on Standard+) and **Hook name drift** (`settings.json` references a filename that no longer exists in `hooks/`).

---

## v2.2.1 — 2026-04-17 — `/ciel-audit` session post-mortem

**Context** — User reported that `/ciel <task>` keeps working inline in the main session instead of dispatching `Task(subagent_type=ciel-*)` forks. Hypothesis: the dispatch rule in `skills/ciel/SKILL.md:201-273` is documented but not enforced, and the `UserPromptSubmit` / `PreToolUse` hooks that could remind the model are probably inactive because `settings.json` declares them with relative paths (`bash .claude/plugins/ciel/hooks/…`) that do not resolve when `claude` is launched from any CWD other than the plugin root.

v2.2.1 adds a diagnostic command that does not depend on hooks being active.

### Added

- **`commands/ciel-audit.md`** — `/ciel-audit` audits the current Claude Code session by re-reading its own tool-use history. Checks six dimensions: dispatch discipline, hook activity (looks for `CIEL depth hint:` / `CIEL [CRITIQUE]` signatures), skill coverage vs depth, skill overlap (e.g., `relire-critic` + `critiquer-auditor` on same diff), agent report truncation, intent routing hits/misses. Produces a self-contained markdown report with `file:line` references and concrete proposed fixes. The user copies the report into a fresh Claude session with the prompt "Apply these Ciel fixes" to actually apply them — the report is mechanical enough for a cold session to execute without any transcript context.

### Diagnosis

First known usage will validate the hypothesis that hooks are inactive due to relative paths in `settings.json:8,19,31,42,54,65,76`. If confirmed, a separate v2.2.2 will fix hook paths (probably via `$CLAUDE_PLUGIN_ROOT/hooks/…`) — but that fix is out of scope of v2.2.1. `/ciel-audit` itself is hook-independent by design, so it remains useful even if hooks stay broken.

### Intentional non-goals

- Does not touch the orchestrator `skills/ciel/SKILL.md`.
- Does not create or modify any hook.
- Does not create or modify any skill.
- Does not modify other commands.
- Does not run eval harness or touch `evals/`.

Strictly additive: one new command file, three documentation updates (README, PLUGIN.md, this CHANGELOG).

---

## v2.2.0 — 2026-04-17 — GitHub workflow: issue → branch → PR → close

**Context** — Ciel had the reasoning side solid (RCA, skills, dispatch) but left project management implicit. After a bug was diagnosed, Claude would jump straight to writing code with no issue tracker entry, no feature branch, no PR opened at the end. Traceability lost. v2.2.0 adds an opinionated workflow: issue first, branch next, commits reference issue, PR closes it, issue-closer adds evidence post-merge.

### Added — 3 new utility skills

- **`skills/utility/issue-creator/SKILL.md`** — `gh issue create` with a structured body (Problem / Repro / Root cause / Proposed fix / Acceptance criteria / Evidence) generated from RCA output or feature spec. Dupe detection against open issues. Mandatory on Critical (audit trail), default on Standard + bug intent, skippable on Trivial.
- **`skills/utility/branch-setup/SKILL.md`** — creates `fix/<N>-<slug>` / `feat/<N>-<slug>` / `chore/<N>-<slug>` from fresh `origin/<default-branch>`. Preflight: clean working tree + issue number present. Writes `.git/ciel-work-context` so downstream skills (commit-writer, pr-opener) know the issue number.
- **`skills/utility/pr-opener/SKILL.md`** — `gh pr create` with `Closes #<N>` auto-link, body composed by `pr-body-generator`, draft if CI not green, updates existing PR if one already open for the branch.

### Changed — orchestrator pipeline

`skills/ciel/SKILL.md` Standard pipeline now has 12 steps (was 9). Inserted after `avec-quoi-versioner`:

- **Step 3** — Project management setup: `issue-creator` → `branch-setup`
- **Step 7** — FAIRE now explicitly includes `commit-writer` with `Refs #<N>` footer
- **Step 10** — `pr-opener` opens the PR with `Closes #<N>`
- **Step 11** — `issue-closer` post-merge

Intent routing table adds a new line: any "fix", "bug fix", "feature", "implement" intent OR any post-RCA action routes to the full GitHub workflow chain.

Inline-OK skills list now includes the 6 GitHub utility skills (all inline — deterministic `gh` / `git`).

### Skip paths

- `--no-pm` flag or explicit "quick fix, no issue" → skip issue-creator + branch-setup (direct commit to branch)
- Trivial depth → GitHub workflow off by default
- No repo remote configured → issue-creator's preflight fails cleanly with a human-readable message

### Effect

Post-RCA (e.g., the `/opt/Neiyomi` library update bug), Ciel now:

1. Returns RCA VERDICT
2. `issue-creator` → files issue #N with Problem/RootCause/ProposedFix/Acceptance
3. `branch-setup` → checks out `fix/N-library-update-db-timeout`
4. FAIRE — writes code, commits use `Refs #N`
5. `critic` (MODE=RELIRE) → 3 RISQUE, inline or fork based on depth
6. `prouver-verifier` → staging evidence, CI gate
7. `pr-opener` → `gh pr create` with `Closes #N`
8. (user reviews, merges)
9. `issue-closer` → adds evidence comment, closes issue
10. `meta-critiquer` → 30s reflection

Instead of: RCA → code → commit → push. Full audit trail maintained.

---

## v2.1.7 — 2026-04-17 — hotfix: critic.md frontmatter missing

**Context** — v2.1.6 was supposed to add YAML frontmatter to all 4 agents (`critic`, `explorer`, `researcher`, `improver`). Live test on `/opt/Neiyomi` revealed only 3 were registered — `ciel-critic` was MISSING from the Task tool's available subagents. Claude correctly tried `Task(subagent_type="ciel-critic", ...)` but got `Agent type 'ciel-critic' not found`.

Root cause: the critic.md Edit in v2.1.6 reported success but didn't actually land on disk (likely due to the editor session's file-state tracking — a previously successful Edit wasn't present after the branch switch). The 3 other agents (explorer, researcher, improver) landed correctly because they were re-edited after a fresh Read.

### Fixed

- **`agents/critic.md`** — frontmatter block actually written this time:
  \`\`\`yaml
  ---
  name: ciel-critic
  description: Isolated-context critic subagent for Ciel...
  tools: Read, Grep, Glob, Bash
  ---
  \`\`\`

### Impact on the affected user

After \`--update\` to v2.1.7, `Task(subagent_type="ciel-critic", ...)` will succeed. The test case (`/ciel my library update broke production`) should now complete the full flow: gather (3-5 calls) → dispatch ciel-critic → fork runs RCA → verdict returned.

---

## v2.1.6 — 2026-04-17 — agents frontmatter + dispatch gate

**Context** — v2.1.4's dispatch directive said "Task(@ciel-critic, ...)" but live use on `/opt/Neiyomi` revealed Claude doing ALL the RCA inline in the main session (10+ Bash calls, 20K+ tokens) instead of dispatching. Root causes:

1. **Agent files had no YAML frontmatter** — Claude Code subagents require `name:` + `description:` in frontmatter to be registered as callable `subagent_type`s. Without it, `Task(subagent_type="ciel-critic", ...)` errors silently and Claude falls back to inline.
2. **No dispatch gate** — the autonomy protocol told Claude to "gather before asking" but never said "stop gathering once inputs are fillable". Claude kept drilling deeper in the main session.

### Fixed

- **`agents/critic.md`, `explorer.md`, `researcher.md`, `improver.md`** — each now has YAML frontmatter with `name: ciel-<role>`, focused `description:`, and scoped `tools:` list. Dispatchable via `Task(subagent_type="ciel-critic", ...)`.
- **`skills/ciel/SKILL.md`** — added "Dispatch gate": gather MINIMUM inputs, max 5 tool calls OR 2 minutes, then dispatch. Anti-pattern from v2.1.5 documented, correct pattern shown.
- **`skills/ciel/SKILL.md`** — Dispatch directive rewritten with concrete `Task(subagent_type=..., description=..., prompt=...)` syntax and per-skill mapping.

### Effect

`/ciel my library update broke production` should now: gather MINIMUM inputs (≤5 calls) → `Task(subagent_type="ciel-critic", ...)` → fork executes debug-reasoning-rca phases 1-5. Instead of 10+ inline investigations burning main-session tokens.

---

## v2.1.5 — 2026-04-17 — autonomy protocol (gather before asking)

**Context** — Ciel agents were written with "bail out and ask the user" logic ("If REPRO is missing → STOP" in `debug-reasoning-rca`). This treats the user as a form to fill in, instead of treating the agent as capable of gathering context. An autonomous agent should exhaust available sources (git, filesystem, overlay, tool calls, MCP) before asking.

### Added

- **`skills/ciel/SKILL.md`** — new "Autonomy protocol" section defining the 7-source gather order (user prompt → overlay → git state → filesystem → tool invocations → MCP → codebase grep) and the `[ASSUMED from <source>]` / `[GIVEN by user]` / `[UNKNOWN]` annotation format that every dispatched skill must emit.
- **Individual skill INPUTS sections updated** with explicit "Auto-inference sources" — each input documents how to obtain it without asking:
  - `debug-reasoning-rca` — SYMPTOM from error logs, REPRO from package scripts / Playwright MCP, SCOPE from `git diff` + `git blame`, RECENT_CHANGES from `git log --since="7 days ago"`
  - `doc-validator-official` — PACKAGE_SOURCES from manifest glob, TARGET_STACK from manifest reads, PROPOSED_APIS from task description parse
  - `ai-failure-modes-detector` — AUTHOR from commit trailer (`Claude Code` = LLM), TEST_COVERAGE from filesystem existence, PROPOSED_DEPS from manifest diff
  - `modern-patterns-checker` — CODE_UNDER_REVIEW from branch diff, TARGET_STACK from manifests

### Behavioral change

Before (interrogative):
```
User: /ciel my library update broke production
Ciel: Can you tell me: what library? what error? what command?
```

After (autonomous):
```
User: /ciel my library update broke production
Ciel: [ASSUMED] lib = @auth/core 3→4 from package.json diff, error = logs show
"useAuth undefined" 1243x, repro = curl .../login returns 500. Dispatching
@ciel-critic MODE=RCA...
```

### When Ciel still asks

Only when a critical input cannot be gathered after exhausting all sources (e.g., greenfield project with no manifests at all). Always ONE specific question with 2-3 concrete options — never open-ended "tell me more".

### Unchanged

Dispatch directive (v2.1.4), intent routing (v2.1.3), installer, manifest, skills inventory — all intact.

---

## v2.1.4 — 2026-04-17 — force Task-dispatch for fork-context skills

**Context** — v2.1.3 made the orchestrator route intents to the correct Ciel skill (e.g., debug → `debug-reasoning-rca`), but Claude invoked it **inline via the Skill tool** in the main session. The skill's frontmatter declares `context: fork` + `agent: critic` — meaning it's supposed to run in a forked subagent context for blind-spot mitigation (CriticBench 2024). Inline invocation defeats the architecture: same-session critique of same-session work = degenerate self-review.

### Fixed

- **`skills/ciel/SKILL.md`** — added a "Dispatch directive" section after the intent routing table. Explicitly maps each `context: fork` Ciel skill to a `Task(@ciel-<role>, '...')` dispatch, NOT a `Skill(<name>)` inline. Lists the inline-OK exceptions (`depth-classifier`, `quoi-framer`, `faire-gatekeeper`, `meta-critiquer`, `prouver-verifier`, etc.) and the anti-pattern to avoid.

### Rationale

| Skill frontmatter | Invocation | Why |
|---|---|---|
| `context: fork` + `agent: X` | `Task(@ciel-X, ...)` | Fresh context — blind-spot mitigation, isolated tool permissions, main session stays lean |
| No `context: fork` | `Skill(...)` inline | Deterministic / lightweight — fork overhead unjustified |

### Effect

- `/ciel debug production issue` → now triggers `Task(@ciel-critic, 'MODE=RCA ...')` instead of inline `Skill(debug-reasoning-rca)`. The critic runs in a fork with fresh context, its own RCA hypotheses, and `edit: false` tool permission.
- Same story for `doc-validator-official`, `modern-patterns-checker`, `playwright-visual-critic`, `cicd-security-hardener`, `accessibility-wcag-auditor`, `skills-first-design-auditor`, `self-consistency-verifier`, `ai-failure-modes-detector`, and all `skills/research/*`.

### Unchanged

Inline pipeline skills (`quoi-framer`, `depth-classifier`, `avec-quoi-versioner`, `faire-gatekeeper`, `evaluer-sizer`, `relire-critic` for Trivial/Standard <3 files, `meta-critiquer`, `prouver-verifier`, `synthesize-findings`, `learnings-capture`) still run inline — fork would be overkill.

---

## v2.1.3 — 2026-04-17 — hotfix: orchestrator routes v2.1.0 skills + command frontmatter

**Context** — On a live install, `/ciel debug this production issue` invoked Claude Code's native `systematic-debugging` skill instead of Ciel's `debug-reasoning-rca`. Root cause: the `skills/ciel/SKILL.md` orchestrator was written for v2.0.0 and never updated to reference the 10 new v2.1.0 skills. Claude's skill-matcher fell back to the native skill with the closest description. Separately, `commands/*.md` lacked YAML frontmatter, which on some Claude Code versions caused `Unknown command: /ciel`.

### Fixed

- **`skills/ciel/SKILL.md`** — added "Intent routing (v2.1.0 skills)" section mapping debugging/docs/testing/a11y/CI-CD/UI-critique intents to the correct Ciel skill + dispatcher. Includes an anti-collision rule: "systematic debugging", "root cause analysis", "bug investigation" MUST route to `debug-reasoning-rca`, never to native `systematic-debugging`.
- **`skills/workflow/debug-reasoning-rca/SKILL.md`** — strengthened YAML `description` to include "systematic debugging" / "THE skill to invoke for ANY bug" so semantic matching prefers it over the native.
- **`commands/*.md`** — added YAML frontmatter (`description:`) to all 6 commands for proper Claude Code slash-command registration.
- **`commands/ciel.md`** — body updated to document the intent-matching step explicitly.

### Unchanged

Installer, manifest, update flow (v2.1.2's semver guard), hooks — nothing else touched.

### Effect

- `/ciel debug X` now routes to `debug-reasoning-rca` via `@ciel-critic` MODE=RCA (3 hypotheses, fault-type taxonomy) instead of the generic native `systematic-debugging`.
- `/ciel <task>` no longer triggers "Unknown command" on fresh installs.
- All 10 v2.1.0 skills are now explicitly reachable via natural-language intent signals.

---

## v2.1.2 — 2026-04-17 — hotfix: semver guard + CDN staleness

**Context** — A live `--update` run produced a bewildering loop: remote `VERSION` was served stale by the GitHub raw CDN (5 min `max-age`), returning `2.1.0` while the user's local manifest already had `2.1.1`. The v2.1.1 check used string equality (`!=`), so "remote 2.1.0 ≠ local 2.1.1" was flagged as an "update available" — pointing DOWN. `_do_update` ran, executed uninstall, then the re-entry used the ALSO-cached v2.1.0 script from `curl` (the CDN doesn't discriminate per-file), re-triggering the `BASH_SOURCE[0]: unbound variable` that was supposedly fixed in v2.1.1 — because the CDN was serving the pre-fix script.

### Fixed

- **`_check_update`** now parses X.Y.Z semver and only returns "update available" (code `2`) when `remote > local`. When `remote < local` (CDN stale / dev build), it reports "Up to date. (local ahead of remote — CDN stale or dev build; nothing to do.)" and returns `0`.
- **`_check_update`** also sends `Cache-Control: no-cache` + `Pragma: no-cache` + a cache-busting `?t=<epoch>` query param on the `VERSION` request to reduce staleness (CDN usually honors at least one).
- Added `_semver_cmp` helper (pure-bash, no external tool required).

### Unchanged

Everything from v2.1.1 (tri-state `_check_update`, `${BASH_SOURCE[0]:-}` guard, `bash <(curl ...)` re-entry) is intact.

### Recovery for users bitten by the loop

If your install was wiped by the v2.1.0 or v2.1.1 `--update` loop, restore fresh:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
```

Do NOT use `--update` until your `curl https://raw.githubusercontent.com/KaosKyun/Ciel/main/VERSION` returns `2.1.2` (wait up to 5 min for CDN).

---

## v2.1.1 — 2026-04-17 — hotfix: `--update` flow

**Context** — v2.1.0's `--update` had two production bugs surfaced on a live install:

1. **`_check_update` return code was ambiguous** — it returned `0` whether you were up-to-date or a new version existed. `_do_update` therefore ran the uninstall + re-install cycle even when nothing had changed, destroying a perfectly good install.
2. **`curl | bash -s --` tripped `set -u`** — the re-entry via `bash -s` leaves `BASH_SOURCE[0]` unset, and the tmp-clone guard read `${BASH_SOURCE[0]}` directly. Result: `unbound variable` exit, install left in a half-removed state.

### Fixed

- **`scripts/install.sh`** — `_check_update` now returns tri-state (`0`=up-to-date, `2`=update available, `1`=error). `_do_update` branches on this and short-circuits cleanly when already current.
- **`scripts/install.sh`** — tmp-clone guard reads `${BASH_SOURCE[0]:-}` via an intermediate variable. Both `curl | bash -s` (stdin) and `bash <(curl ...)` (process substitution) now fall through to the clone path without crashing.
- **`_do_update`** — re-entry now uses `bash <(curl ...)` instead of `curl | bash -s --`, ensuring `BASH_SOURCE[0]` is defined in the child shell.

### Unchanged

Everything else from v2.1.0 (10 skills, MCP opt-in, manifest, uninstall, SessionStart banner) is intact.

### If you were bitten by the bug

Your install was uninstalled but not re-installed. Restore with a fresh install:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaosKyun/Ciel/main/scripts/install.sh)
```

---

## v2.1.0 — 2026-04-17 — 10 new skills + MCP opt-in + uninstall/update

**Context** — v2.0.0 landed the skills-first architecture but left gaps in the reasoning coverage (no debugging RCA, no official-doc validator, no anti-pattern 2026 guardrail, no AI-failure-mode detector), did not exploit available MCP servers (Playwright for visual critique, Context7 for live docs), and the installer had no clean uninstall or update path. v2.1.0 closes all three gaps in one pass.

### Added — 10 new skills

- **`skills/workflow/debug-reasoning-rca/`** — Root-Cause Analysis with 3 parallel hypotheses, fault-type classification (model/context/orchestration/environment), semantic diff. Dispatched via `@ciel-critic`. 75% MTTR reduction target (STRATUS).
- **`skills/workflow/doc-validator-official/`** — Fetches official docs for the pinned lib version, validates every proposed API call, rejects Stack Overflow as primary source. Flags cutoff-warning for libs post-January 2026. Dispatched via `@ciel-researcher`.
- **`skills/workflow/modern-patterns-checker/`** — Detects obsolete patterns (React classes, Python 2, sync-in-async, CommonJS in ESM, old Go error handling) with 2026 canonical replacements. ThoughtWorks Technology Radar April 2026.
- **`skills/workflow/ai-failure-modes-detector/`** — Six canonical LLM failure modes: invented APIs, hallucinated deps, version drift, async/sync mismatch, confident-wrong, extrinsic hallucination. Dispatched via `@ciel-explorer`.
- **`skills/workflow/self-consistency-verifier/`** — IdentityChain pattern: 3 diverse solutions, AST compare, behavioral compare, consistency score. Dispatched via `@ciel-critic` for Critical tasks.
- **`skills/workflow/test-strategy-vitest-playwright/`** — Pyramid 70/20/10 (unit/integration/E2E), Vitest + MSW + Playwright + fast-check. Accessibility-tree assertions over screenshots.
- **`skills/workflow/playwright-visual-critic/`** — Wraps Playwright MCP: navigate → accessibility-tree snapshot → dispatch `@ciel-critic`. Requires `--with-mcp=playwright`. Documents OpenCode gap #2319.
- **`skills/domain/cicd-security-hardener/`** — SLSA Level 3 baseline, Sigstore/Cosign keyless, ephemeral runners, SBOM, no long-lived cloud credentials, no `pull_request_target` with untrusted checkout.
- **`skills/domain/accessibility-wcag-auditor/`** — WCAG 2.2 AA (legal baseline April 2026 via ADA Title II / EN 301 549). Focus Not Obscured 2.4.11, Target Size 2.5.8, Accessible Auth 3.3.8. Manual + automated layers.
- **`skills/meta/skills-first-design-auditor/`** — Lints new skills against Anthropic's April 2026 skills guide (≤500 lines, 2-3 examples, executable checks, clear trigger). Dispatched via `@ciel-improver`.

### Added — MCP integration

- **`.mcp.json`** — project-scope template with `playwright` (@playwright/mcp) and `context7` (@upstash/context7-mcp). Opt-in only.
- **`install.sh --with-mcp=playwright,context7`** — merges selected servers into `$PROJECT_ROOT/.mcp.json`. Backs up any existing file.
- **AGENTS.md** (OpenCode) — documents MCP workflow and OpenCode gap #2319 (plugin hooks do NOT see MCP tool calls; `playwright-visual-critic` orchestrates the critic dispatch explicitly).

### Added — installer uninstall / update

- **`VERSION`** — root file holding `2.1.0`. Compared against GitHub main by `--check-update`.
- **`~/.ciel/manifest.json`** — generated on every install. Lists version, installed_at, platforms, mcp servers, and the full list of tracked files. Enables clean uninstall.
- **`install.sh --uninstall`** — iterates manifest `files[]`, prompts confirmation (skippable with `-y`), preserves whitelist (`.mcp.json`, `ciel-overlay.md`, `AGENTS.md`).
- **`install.sh --check-update`** — non-blocking (`curl --max-time 5`) fetch of remote `VERSION`, compares, prints banner if newer.
- **`install.sh --update`** — requires manifest, runs uninstall-then-reinstall from the latest main branch.
- **`hooks/session-start.{sh,ps1}`** — throttled 24h update check (curl max 2s, silent on failure). Surfaces `[UPDATE] Ciel vX → vY available` banner in the session banner.
- **`commands/ciel-update.md`** — rewritten to delegate to `install.sh --update` / `--check-update`.

### Changed

- **`scripts/build-platforms.sh`** — `LIMIT_opencode_agent` bumped from 49152 to 65536 (bundles now include 6 additional skills inline/compact across roles). Routing matrix adds: `doc-validator-official` → researcher (inline); `modern-patterns-checker` + `ai-failure-modes-detector` → explorer (inline); `test-strategy-vitest-playwright` + `playwright-visual-critic` → explorer (compact); `cicd-security-hardener` + `accessibility-wcag-auditor` → explorer domain (compact); `debug-reasoning-rca` + `self-consistency-verifier` → critic (inline); `skills-first-design-auditor` → improver (inline).
- **`scripts/install.sh`** — refactored flag parser, added `INSTALLED_FILES` tracking, `_register_installed_files` post-install registry, `_install_mcp`, `_do_uninstall`, `_do_update`, `_check_update`, `_manifest_write`. Bumps banner to v2.1.0.

### Removed

- **`scripts/self-update.sh`** — deprecated in favor of `install.sh --update`. `gh` CLI no longer required for updates.

### Follow-up

- 5 platform issues (#2 Cursor, #3 Windsurf, #4 Codex, #5 Kilo, #6 LMStudio+Ollama) still open — when their native primitives are restored, they should bundle these 10 new skills as well.
- MCP opt-in wiring for OpenCode (the project-level `.mcp.json` works for Claude Code; OpenCode reads its own `opencode.json` mcp block — users may mirror).

---

## Unreleased — platforms: restore native OpenCode adaptation

**Context** — v2.0.0 replaced all platform-native adaptations with a single 907-line compressed `AGENTS.md` dump. The pre-refactor OpenCode integration (plugin with pre/post-write hooks, 3 ciel-* subagents, 2 commands) was deleted in the process. This lot restores OpenCode's native primitives and updates them to the v2 4-agent + 33-skill model.

### Added

- **`platforms/opencode/.opencode/plugins/ciel.ts`** — TypeScript plugin (port of `hooks/pre-tool-write.sh`, `post-tool-write.sh`, `user-prompt-submit.sh`). Fires on `tool.execute.before`, `tool.execute.after`, `chat.params`. Injects depth classification and FAIRE/RELIRE reminders. Pure TS, no shell dependency.
- **`platforms/opencode/.opencode/agents/ciel-{researcher,explorer,critic,improver}.md`** — 4 subagents with OpenCode frontmatter (`mode: subagent`, scoped tool permissions). Skills they invoke (`research/*`, `workflow/*`, `domain/*`, `meta/*`) are bundled inline since OpenCode has no native skills primitive — agents are self-sufficient.
- **`platforms/opencode/.opencode/commands/ciel*.md`** — 6 slash commands (`/ciel`, `/ciel-improve`, `/ciel-eval`, `/ciel-create-skill`, `/ciel-recommend`, `/ciel-update`) with OpenCode frontmatter (`agent`, `subtask`). Meta commands (`/ciel-improve`, `/ciel-eval`, `/ciel-create-skill`) noted as degraded without `claude --print` headless mode.
- **`build-platforms.sh`** — new helpers `bundle_skills_inline`, `emit_opencode_agent`, `emit_opencode_command`, `emit_opencode_plugin`, `emit_opencode_config`, `emit_opencode_agents_md`. Regex extracted as script-level variables (`CIEL_CRITICAL_FILE_RE`, `CIEL_CODE_EXT_RE`, etc.) — single source of truth shared with hooks.

### Changed

- **`platforms/opencode/AGENTS.md`** — reduced from 907-line dump (31KB) to a 3.5KB index pointing to the native primitives.
- **`platforms/opencode/opencode.json`** — now registers the `ciel.ts` plugin alongside `AGENTS.md` instructions.
- **`build-platforms.sh`** — converted `declare -A LIMITS` associative array to portable prefixed variables (`LIMIT_<name>`) for bash 3.2 compatibility (macOS default shell).

### Unchanged

No source-of-truth files (`skills/`, `agents/`, `hooks/`, `commands/`, `settings.json`) were modified — this lot only touches `platforms/opencode/` and `scripts/build-platforms.sh`.

### Follow-up

The 5 remaining platforms (Cursor, Windsurf, Codex, Kilo, LM Studio/Ollama) will each get a dedicated issue + PR restoring their native primitives. Current state on those platforms is still the compressed dump.

---

## v2.0.0 — 2026-04-17 — Skills-first total refactor

**BREAKING — total architecture rewrite aligned with Anthropic's Skills-first paradigm.**

### Context

Barry Zhang and Mahesh Murag (Anthropic, AI Engineer Code Summit): *"Stop building agents. Build Skills."* v1.x's 455-line monolithic SKILL.md violated the paradigm directly — it couldn't be selectively invoked, improved at failure granularity, or evaluated per-step. Philosophy was sound; implementation was monolithic.

### Added

- **33 specialized skills** organized in 5 categories:
  - `skills/workflow/` (13): `depth-classifier`, `quoi-framer`, `avec-quoi-versioner`, `stride-analyzer`, `pattern-fitness-check`, `evaluer-sizer`, `flux-narrator`, `faire-gatekeeper`, `security-regression-check`, `relire-critic`, `prouver-verifier`, `critiquer-auditor`, `meta-critiquer`
  - `skills/research/` (6): `research-web-sources`, `research-github-issues`, `research-forums`, `validate-source-credibility`, `synthesize-findings`, `fact-check-claims`
  - `skills/domain/` (8): `frontend-mastery`, `backend-mastery`, `database-mastery`, `security-hardening`, `api-architecture`, `observability`, `performance-engineering`, `refactoring-patterns`
  - `skills/utility/` (5): `commit-writer`, `pr-body-generator`, `issue-closer`, `changelog-updater`, `staging-verifier`
  - `skills/meta/` (4): `ciel-improve`, `skill-creator`, `skill-variant-evaluator`, `learnings-capture`
- **Self-improvement subsystem**: `/ciel-improve` analyses session transcripts → proposes patch-set for approval (never autonomous rewrite); `skill-variant-evaluator` runs binary evals via `claude --print`; `skill-creator` generates valid SKILL.md scaffolds
- **Eval harness** under `evals/`: datasets (4 seed), runners (`skill-eval.sh`, `run-evals.sh`), results/
- **Build-platforms script**: `scripts/build-platforms.sh` auto-generates Cursor/Windsurf/Codex/OpenCode/Kilo/Ollama/LM Studio artifacts from `skills/` — no more hand-maintaining per-platform files
- **4 hook events added**: `SessionStart`, `UserPromptSubmit`, `PreCompact`, `SubagentStop`, `Stop` (in addition to `PreToolUse` / `PostToolUse`)
- **3 new commands**: `/ciel-improve`, `/ciel-create-skill`, `/ciel-eval`
- **New agent**: `agents/improver.md` — long-running self-improvement meta-agent
- **New command**: `/ciel` (main entry point, was previously implicit)

### Changed

- **`skills/ciel/SKILL.md`**: rewritten from 455-line monolith to ~180-line orchestrator that routes to specialized skills. Full Guards table and extended philosophy moved to `skills/ciel/reference.md` (progressive disclosure).
- **`agents/{researcher,explorer,critic}.md`**: rewritten as thin orchestrators (~60-80 lines each). They invoke specialized skills rather than duplicating logic inline.
- **`hooks/pre-write-gate.sh`** → `hooks/pre-tool-write.sh` (renamed, updated to trigger `faire-gatekeeper` skill)
- **`hooks/post-write-relire.sh`** → `hooks/post-tool-write.sh` (renamed, updated to trigger `relire-critic` skill)
- **`settings.json`**: expanded to 7 hook events
- **`.claude-plugin/plugin.json`** + **`marketplace.json`**: bumped to 2.0.0
- **`PLUGIN.md`** + **`README.md`**: rewritten to document new architecture

### Removed

- **Old monolithic `skills/ciel/SKILL.md`** content (455 lines) — redistributed across 13 workflow skills + 6 research skills + reference.md
- **`hooks/pre-write-gate.{sh,ps1}`** — replaced by `pre-tool-write.{sh,ps1}`
- **`hooks/post-write-relire.{sh,ps1}`** — replaced by `post-tool-write.{sh,ps1}`
- **All `platforms/*` files** — now auto-regenerated; editing `skills/` is the only source of truth

### Migration (v1.x → v2.0.0)

- `/ciel <task>` behaves the same user-visible (depth classification + pipeline routing)
- `ciel-overlay.md` format unchanged — existing overlays work as-is
- Agent input formats preserved (`TASK:`, `TECHNOLOGIES:`, etc.) for compat with existing prompts
- Custom settings.json hooks require manual merge with new 7-event surface
- Platform rule files: users who edited `platforms/*` manually will see overwrites on next `build-platforms.sh`

### Metrics

- **Baseline (v1.x)**: 62.8% fix/revert ratio on 675 commits with monolithic SKILL.md
- **v2.0.0 target**: < 45% fix/revert (reference: SICA research, 17→53% improvement via self-edit + metrics)
- Eval datasets seeded (depth-classification, research-gate, flux-narration, relire-3-risques); initial scoreboard will land in v2.0.1

### Triggered by

Direct user request for a total refactor aligned with Anthropic's Skills-first paradigm. Philosophy of Ciel (the Primordial Sage from Tensura — reason before act) is preserved; only the delivery mechanism changes.

---

## v1.9.0 — 2026-04-05

**Changements** : CRITIQUER overhaul — parité output gates avec CRÉER

- **Entry**: instruction explicite "lire le diff/PR avant tout step"
- **APPRENDRE**: modèle de comportement attendu remplace "WebSearch anti-patterns" (langage CRÉER inadapté à la review); checklist de bypass signals explicite; 2 output gates ajoutés
- **COMPRENDRE**: 3 assumptions doivent être *vérifiées* (grep/blame/read), pas juste "surfacées" — distinction passive→active
- **QUESTIONNER**: 2 output gates ajoutés ("nothing considered?", "scope proportional?")
- **COMPARER**: STRIDE étendu — 6 questions explicites à cocher (Spoofing/Tampering/Repudiation/InfoDisclosure/DoS/Elevation); 3 output gates ajoutés
- **COHÉRENCE**: 3 checks concrets (grep pattern, layer boundaries, overlay thresholds) remplacent les bullets vagues
- **SIGNALER**: seuils de sévérité définis (BLOCKING = correctness/security/data loss; IMPORTANT = degraded behavior; MINOR = style; VALIDATED = confirmed correct); 3 output gates ajoutés
- **CAPITALISER**: actions concrètes (Guard ou overlay); 2 output gates ajoutés

**Problème adressé** : CRITIQUER avait 0 output gates sur 7 steps — exécutable sans produire aucune preuve. Un reviewer pouvait "compléter" CRITIQUER en 2 minutes et déclarer done.

**Métriques observées** :
- Critique de CRITIQUER (6 findings dont 3 BLOCKING) : 0 gates, STRIDE non exécuté, APPRENDRE = mauvais step, sévérités non définies, diff jamais explicitement lu, assumptions non vérifiées

**Déclenché par** : Audit capacités CRITIQUER de Ciel par CEO (2026-04-05)

---

## v1.8.0 — 2026-04-05

**Changements** (corrections structurelles — 0 nouvelles fonctionnalités, 6 fixes):
- SÉCURITÉ PASSE 4 supprimée du step 4 — elle instruisait une action post-FAIRE depuis un step pré-FAIRE (contradiction temporelle)
- Nouveau step **8b — SECURITY REGRESSION CHECK** entre FAIRE et RELIRE (Critical only) — même contenu, exécuté au bon moment
- **Before-state capture** ajouté à FAIRE (bug fix only) — capture AVANT avant d'écrire le code, satisfait l'obligation PROUVER AVANT/APRÈS
- PROUVER **Trivial allégé** : compile OK + push + no regression — CI gate et staging mandatory exclus pour les 1-line fixes
- RELIRE checklist TDD : `□ Tests written BEFORE` → `□ Tests could fail independently of implementation?` — vérifiable à n'importe quel moment
- RECHERCHE/CODEBASE boundary : `Imports/signatures` déplacé de RECHERCHE vers CODEBASE (API surface check) — clarification que RECHERCHE = externe, CODEBASE = interne
- META-CRITIQUER step 4 : grep `worktree-agent` spécifique Neiyomi → `git branch -r | wc -l` générique + note overlay

**Métriques observées** :
- Critique isolée (17 findings, 5 BLOCKING) a détecté : step 8b inaccessible depuis step 4, AVANT/APRÈS sans capture pre-FAIRE, PROUVER Trivial inutilisable, TDD check non-vérifiable à RELIRE, grep projet-spécifique dans un plugin universel

**Déclenché par** : Critique structurelle complète de SKILL.md v1.7.0 par agent critic isolé (2026-04-05)

---

## v1.7.0 — 2026-04-05

**Changements** :
- RECHERCHE output gate: version changelog check (breaking changes/deprecations for installed version)
- RECHERCHE output gate: framework philosophy now requires "HOW does this framework want me to solve this?" — not just API docs
- SÉCURITÉ PASSE 4: security regression check — grep diff for new inputs/trust boundaries/removed auth blocks
- PROUVER: CI gate — `gh run list --branch $BRANCH` mandatory before presenting report
- PROUVER: issue comment gate — staging PID + AVANT/APRÈS on linked issue BEFORE creating PR (not post-merge only)
- PROUVER: open PR hygiene — draft + CI green → convert to ready; PR > 2 days CI green → flag
- Guards: 6 new entries (security surface, CI ignored, draft PR left open, issue comment missing, version changelog missed)

**Déclenché par** : 3 retours CEO sur security rigor, PR/issue tracking, et profondeur de recherche (2026-04-05)

---

## v1.6.0 — 2026-04-05

**Changements** :
- ÉVALUER: recent-churn check — `git log --since=7days` on impacted files before proposing fix; prevents fix-of-fix chains
- FAIRE: volume gate — pause + verify each PR when 3+ created in same session
- RELIRE checklist: linter gate — explicit "0 new violations (Detekt/ESLint)" item
- PROUVER: PR body gate — `Closes #XXX` required, WIP title forbidden, PR closed check
- META-CRITIQUER: stale branch check

**Déclenché par** : Audit CRITIQUER des 25 issues + 8 PRs ouverts Neiyomi (2026-04-05)

---

## v1.3.0 — 2026-04-04

**Déclenché par** : Analyse des lacunes TDD — aucun gate ne forçait test-avant-implémentation, niveau de test implicite, failure path optionnel.

**Changements** : FLUX test level item, FAIRE test gate (RED first), RELIRE checklist TDD item, Guard TDD inversion.

---

## v1.2.0 — 2026-04-04

**Déclenché par** : Recherche 2026 (SWE-Bench Pro, SICA, MAST, SWE-EVO, AI Agent Memory 2026).

**Changements** : task decomposition gate, typed agent dispatch (MAST), assumption verification (SWE-EVO), 4-type memory model, SICA validator, self-cleaning cycle, self-update script.

---

## v1.1.0 — 2026-04-04

**Déclenché par** : Audit CRITIQUER dev-reasoning v18.3. 3 BLOCKING + 4 IMPORTANT.

**Changements** : RELIRE-A/B inline, removal gate, Guards "How it manifests" column, PROUVER attacker perspective, mini repo-map, SÉCURITÉ hygiene.

---

## v1.0.0 — 2026-04-04

**Déclenché par** : 62.8% fix/revert sur 675 commits Neiyomi avec dev-reasoning monolithique.

**Changements** : architecture 5-layer, agents OBLIGATOIRES Standard/Critical, RECHERCHE output gate (6 items), FLUX 3 items test-spécifiques.
