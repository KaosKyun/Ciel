// Claude Code platform installer logic
// Handles detection, file copy, and config generation for Claude Code projects

import { existsSync, mkdirSync, copyFileSync, chmodSync, readFileSync, writeFileSync, lstatSync, unlinkSync, readdirSync } from "fs";
import { join, dirname, sep, resolve } from "path";
import { ok, warn } from "./utils";

export interface ClaudeOptions {
  targetDir: string;
  srcDir: string;
  force: boolean;
  quiet: boolean;
}

export interface InstallResult {
  installed: string[];
  skipped: string[];
}

// Hook scripts CURRENTLY shipped by Ciel. Used by BOTH the install copy loop
// AND mergeSettings() to recognize Ciel-managed wrappers. Anything in this
// list will be (re)installed on `--force` upgrade.
// Exported for test/merge-settings.test.ts — internal API, not for SDK consumers.
export const CIEL_HOOK_FILES = [
  "block-destructive.sh",
  "track-file.sh",
  "track-verification.sh",
  "pre-tool-write.sh",
  "pre-agent-gate.sh",
  "check-dispatch-gate.sh",
  "stop.sh",
  "session-start.sh",
  "user-prompt-submit.sh",
  "memory-bootstrap.sh",
  "memory-engine.py",
];

// Legacy hook basenames from PRIOR Ciel versions. Used ONLY by mergeSettings()
// to evict stale wrappers on `--force` upgrade — NEVER iterated by the install
// copy loop (assets/ no longer ships these files).
//
// IMPORTANT: every entry here is a basename Ciel has owned at some point.
// Do NOT add basenames that may belong to USER-DEFINED custom hooks (the
// mergeSettings() filter uses a substring `cmd.includes(name)` check, so
// adding a user-owned basename here causes silent data loss on `--force`).
// Specifically: `post-edit-check.sh` is intentionally absent — it has never
// been a Ciel-shipped hook; it appears in some user settings as a custom
// post-edit linter wrapper. Preserve it.
export const CIEL_LEGACY_HOOK_FILES = [
  "pre-write-gate.sh",      // renamed → pre-tool-write.sh in v2.0
  "post-write-relire.sh",   // renamed → post-tool-write.sh in v2.0
  "post-tool-write.sh",     // removed in v6.x (replaced by track-file + RELIRE gate)
  "check-test-first.sh",    // removed in v6.14 (v9 thin shell)
  "meta-critiquer.sh",      // removed in v6.14 (v9 thin shell)
];

// Top-level settings.json keys that Ciel OWNS and SHOULD overwrite on `--force`
// upgrade, even when the user already has a value. Everything else stays
// user-controlled (existing wins). Add with care — each entry here is a key
// the user cannot override via settings.json once they run `ciel-init --force`.
export const CIEL_OWNED_SETTINGS_KEYS = [
  // autoMemoryEnabled MUST be false on Ciel projects: Claude Code's auto-memory
  // competes with the cued-recall corpus and is invisible to /ciel-audit.
  // See ADR-0001 and CLAUDE.md "Ciel memory ≠ Claude Code auto-memory".
  "autoMemoryEnabled",
] as const;

/**
 * Detect if the project has Claude Code configuration.
 */
export function detectClaude(targetDir: string): boolean {
  return (
    existsSync(join(targetDir, ".claude/settings.json")) ||
    existsSync(join(targetDir, ".claude"))
  );
}

/**
 * Install Ciel files for Claude Code platform.
 */
export function installClaude(opts: ClaudeOptions): InstallResult {
  const { targetDir, srcDir, force, quiet } = opts;
  const installed: string[] = [];
  const skipped: string[] = [];

  // Claude Code directories
  const agentsDest = join(targetDir, ".claude/agents");
  const hooksDest = join(targetDir, ".claude/hooks");
  const commandsDest = join(targetDir, ".claude/commands");
  const skillsDest = join(targetDir, ".claude/skills/ciel");

  // Create directories — remove any file-blocker at any segment within targetDir
  mkdirSafe(agentsDest, targetDir);
  mkdirSafe(hooksDest, targetDir);
  mkdirSafe(commandsDest, targetDir);
  mkdirSafe(skillsDest, targetDir);

  // Agent files
  const agentFiles = [
    "ciel-researcher.md",
    "ciel-explorer.md",
    "ciel-critic.md",
    "ciel-improver.md",
  ];
  for (const agent of agentFiles) {
    const src = join(srcDir, ".claude/agents", agent);
    const dest = join(agentsDest, agent);
    if (existsSync(src)) {
      const action = copyIfNewer(src, dest, force);
      if (action === "copied") installed.push(`.claude/agents/${agent}`);
      else if (action.startsWith("error:") && !quiet) warn(`  skipped .claude/agents/${agent} — ${action.slice(6)}`);
    }
  }

  // Hook files
  for (const hook of CIEL_HOOK_FILES) {
    const src = join(srcDir, ".claude/hooks", hook);
    const dest = join(hooksDest, hook);
    if (existsSync(src)) {
      const action = copyIfNewer(src, dest, force);
      if (action === "copied") {
        installed.push(`.claude/hooks/${hook}`);
        try { chmodSync(dest, 0o755); } catch { /* ignore */ }
      } else if (action.startsWith("error:") && !quiet) warn(`  skipped .claude/hooks/${hook} — ${action.slice(6)}`);
    }
  }

  // Command files
  const commandFiles = [
    "ciel-init.md",
    "ciel-update.md",
    "ciel-eval.md",
    "ciel-create-skill.md",
    "ciel-audit.md",
    "ciel-memory-init.md",
    "ciel-memory.md",
    "ciel-status.md",
  ];
  for (const cmd of commandFiles) {
    const src = join(srcDir, "commands", cmd);
    const dest = join(commandsDest, cmd);
    if (existsSync(src)) {
      const action = copyIfNewer(src, dest, force);
      if (action === "copied") installed.push(`.claude/commands/${cmd}`);
      else if (action.startsWith("error:") && !quiet) warn(`  skipped .claude/commands/${cmd} — ${action.slice(6)}`);
    }
  }

  // Skills source: npm assets ship them flat under skills/; the repo keeps the
  // canonical tree under src/skills/ (local install). Resolve whichever exists.
  const skillsRoot = existsSync(join(srcDir, "skills"))
    ? join(srcDir, "skills")
    : join(srcDir, "src/skills");

  // Ciel skill (SKILL.md + reference.md)
  const skillSrc = join(skillsRoot, "ciel/SKILL.md");
  const skillRefSrc = join(skillsRoot, "ciel/reference.md");
  if (existsSync(skillSrc)) {
    const action = copyIfNewer(skillSrc, join(skillsDest, "SKILL.md"), force);
    if (action === "copied") installed.push(".claude/skills/ciel/SKILL.md");
  }
  if (existsSync(skillRefSrc)) {
    const action = copyIfNewer(skillRefSrc, join(skillsDest, "reference.md"), force);
    if (action === "copied") installed.push(".claude/skills/ciel/reference.md");
  }

  // CLAUDE.md
  const claudeMdSrc = join(srcDir, "CLAUDE.md");
  const claudeMdDest = join(targetDir, "CLAUDE.md");
  if (existsSync(claudeMdSrc) && (!existsSync(claudeMdDest) || force)) {
    try {
      copyFileSync(claudeMdSrc, claudeMdDest);
      installed.push("CLAUDE.md");
    } catch (e: any) {
      if (!quiet) warn(`  skipped CLAUDE.md — ${e.code ?? e.message}`);
      skipped.push("CLAUDE.md");
    }
  }

  // AGENTS.md
  const agentsMdSrc = join(srcDir, "AGENTS.md");
  const agentsMdDest = join(targetDir, "AGENTS.md");
  if (existsSync(agentsMdSrc) && (!existsSync(agentsMdDest) || force)) {
    try {
      copyFileSync(agentsMdSrc, agentsMdDest);
      installed.push("AGENTS.md");
    } catch (e: any) {
      if (!quiet) warn(`  skipped AGENTS.md — ${e.code ?? e.message}`);
      skipped.push("AGENTS.md");
    }
  }

  // .claude/rules/ — domain rules (v9), auto-load via paths: frontmatter
  const rulesSrcDir = join(srcDir, ".claude/rules");
  const rulesDestDir = join(targetDir, ".claude/rules");
  if (existsSync(rulesSrcDir)) {
    mkdirSafe(rulesDestDir, targetDir);
    for (const ruleFile of readdirSync(rulesSrcDir)) {
      if (!ruleFile.endsWith(".md")) continue;
      const src = join(rulesSrcDir, ruleFile);
      const dest = join(rulesDestDir, ruleFile);
      const action = copyIfNewer(src, dest, force);
      if (action === "copied") installed.push(`.claude/rules/${ruleFile}`);
    }
  }

  // .claude/skills/ — skills (v9), invoked via Skill() by rules Dispatch.
  // Read from the unified canonical asset tree (assets/skills, src-derived).
  // The top-level loop ships discoverable skills (domain + ciel + the three
  // recovered: environments/github/research); nested workflow/meta dirs have no
  // root SKILL.md so they are skipped — Claude discovery is top-level only.
  const skillsSrcDir = skillsRoot;
  const skillsDestDir = join(targetDir, ".claude/skills");
  if (existsSync(skillsSrcDir)) {
    for (const entry of readdirSync(skillsSrcDir)) {
      const skillMd = join(skillsSrcDir, entry, "SKILL.md");
      if (!existsSync(skillMd)) continue;
      const entryDestDir = join(skillsDestDir, entry);
      mkdirSafe(entryDestDir, targetDir);
      const action = copyIfNewer(skillMd, join(entryDestDir, "SKILL.md"), force);
      if (action === "copied") installed.push(`.claude/skills/${entry}/SKILL.md`);
      const ref = join(skillsSrcDir, entry, "reference.md");
      if (existsSync(ref)) {
        const refAction = copyIfNewer(ref, join(entryDestDir, "reference.md"), force);
        if (refAction === "copied") installed.push(`.claude/skills/${entry}/reference.md`);
      }
    }
  }

  // .claude/settings.json
  // Fresh install: copy as-is. Update (force): merge hooks from template
  // so stale Ciel hook references are replaced while user MCP configs are kept.
  const settingsSrc = join(srcDir, ".claude/settings.json");
  const settingsDest = join(targetDir, ".claude/settings.json");
  if (existsSync(settingsSrc)) {
    if (!existsSync(settingsDest)) {
      try {
        copyFileSync(settingsSrc, settingsDest);
        installed.push(".claude/settings.json");
      } catch (e: any) {
        if (!quiet) warn(`  skipped .claude/settings.json — ${e.code ?? e.message}`);
        skipped.push(".claude/settings.json");
      }
    } else if (force) {
      const merged = mergeSettings(settingsDest, settingsSrc);
      if (merged !== null) {
        writeFileSync(settingsDest, JSON.stringify(merged, null, 2) + "\n");
        installed.push(".claude/settings.json (hooks merged)");
      } else {
        skipped.push(".claude/settings.json (preserved — parse error)");
      }
    } else {
      skipped.push(".claude/settings.json (preserved)");
    }
  }

  return { installed, skipped };
}

/**
 * Walk every segment of dir that falls within fence; unlink any regular file
 * or symlink that blocks a directory create. Uses lstatSync so symlinks are
 * never mistaken for directories. ENOENT between check and unlink is silently
 * ignored (concurrent removal is fine).
 */
function mkdirSafe(dir: string, fence: string): void {
  const abs = resolve(dir);
  const absBase = resolve(fence);
  if (!abs.startsWith(absBase + sep) && abs !== absBase) {
    throw new Error(`mkdirSafe: ${abs} is outside fence ${absBase}`);
  }
  const segments = abs.split(sep);
  for (let i = 1; i <= segments.length; i++) {
    const partial = segments.slice(0, i).join(sep);
    if (!partial) continue;
    try {
      if (!lstatSync(partial).isDirectory()) unlinkSync(partial);
    } catch (e: any) {
      if (e.code !== "ENOENT") throw e;
    }
  }
  mkdirSync(abs, { recursive: true });
}

/**
 * Merge the hooks section of a Ciel settings.json template into an existing
 * settings file. Replaces Ciel-managed hook entries (those whose inner
 * hooks[].command references a known Ciel hook script basename, regardless
 * of path) with the template entries; user-added wrappers are preserved.
 * All other top-level keys (mcpServers, permissions, etc.) are kept from
 * the existing file. Returns null if either file cannot be read or parsed.
 */
export function mergeSettings(existingPath: string, templatePath: string): object | null {
  let existing: Record<string, unknown>;
  let template: Record<string, unknown>;

  try {
    const raw = JSON.parse(readFileSync(existingPath, "utf8"));
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
    existing = raw as Record<string, unknown>;
  } catch {
    return null;
  }

  try {
    const raw = JSON.parse(readFileSync(templatePath, "utf8"));
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
    template = raw as Record<string, unknown>;
  } catch {
    return null;
  }

  const merged: Record<string, unknown> = { ...existing };

  if (template.hooks && typeof template.hooks === "object") {
    const existingHooks = (existing.hooks ?? {}) as Record<string, unknown[]>;
    const templateHooks = template.hooks as Record<string, unknown[]>;
    const mergedHooks: Record<string, unknown[]> = {};

    const allEvents = new Set([
      ...Object.keys(existingHooks),
      ...Object.keys(templateHooks),
    ]);

    // A wrapper is Ciel-managed if any inner hook command references a
    // currently-shipped or legacy Ciel basename. Substring match — catches
    // both new `.claude/hooks/x.sh` and legacy `hooks/x.sh` / absolute paths.
    const cielBasenames = [...CIEL_HOOK_FILES, ...CIEL_LEGACY_HOOK_FILES];

    for (const event of allEvents) {
      const templateEntries = templateHooks[event] ?? [];
      const existingEntries = existingHooks[event] ?? [];
      const userEntries = existingEntries.filter((e) => {
        const wrapper = e as Record<string, unknown>;
        const inner = Array.isArray(wrapper.hooks)
          ? (wrapper.hooks as Record<string, string>[])
          : [];
        return !inner.some((h) => {
          const cmd = String(h.command ?? "");
          return cielBasenames.some((name) => cmd.includes(name));
        });
      });
      const entries = [...templateEntries, ...userEntries];
      // Omit event key if empty (avoids clobbering user events dropped from template)
      if (entries.length > 0) mergedHooks[event] = entries;
    }

    merged.hooks = mergedHooks;
  }

  // Propagate Ciel-owned top-level keys from template — overwrites existing
  // values on `--force`. Without this, flipping a setting in the template
  // (e.g. autoMemoryEnabled false) never reaches users on upgrade.
  for (const k of CIEL_OWNED_SETTINGS_KEYS) {
    if (k in template) merged[k] = template[k];
  }

  return merged;
}

/**
 * Copy src to dest if dest doesn't exist or force is true.
 * Returns "copied", "skipped", "missing", or "error:<reason>".
 */
function copyIfNewer(src: string, dest: string, force: boolean): string {
  if (!existsSync(src)) return "missing";
  if (existsSync(dest) && !force) return "skipped";
  try {
    copyFileSync(src, dest);
    return "copied";
  } catch (e: any) {
    return `error:${e.code ?? e.message}`;
  }
}
