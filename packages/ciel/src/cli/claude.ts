// Claude Code platform installer logic
// Handles detection, file copy, and config generation for Claude Code projects

import { existsSync, mkdirSync, copyFileSync, chmodSync, readFileSync, writeFileSync, lstatSync, unlinkSync } from "fs";
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
  const hookFiles = [
    "check-test-first.sh",
    "block-destructive.sh",
    "track-file.sh",
    "meta-critiquer.sh",
  ];
  for (const hook of hookFiles) {
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
    "ciel-refresh.md",
    "ciel-eval.md",
    "ciel-create-skill.md",
    "ciel-recommend.md",
    "ciel-audit.md",
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

  // Ciel skill (SKILL.md + reference.md)
  const skillSrc = join(srcDir, "skills/ciel/SKILL.md");
  const skillRefSrc = join(srcDir, "skills/ciel/reference.md");
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

  // .claude/settings.json — NEVER overwrite existing (preserves user MCP/hooks)
  const settingsSrc = join(srcDir, ".claude/settings.json");
  const settingsDest = join(targetDir, ".claude/settings.json");
  if (existsSync(settingsSrc) && !existsSync(settingsDest)) {
    try {
      copyFileSync(settingsSrc, settingsDest);
      installed.push(".claude/settings.json");
    } catch (e: any) {
      if (!quiet) warn(`  skipped .claude/settings.json — ${e.code ?? e.message}`);
      skipped.push(".claude/settings.json");
    }
  } else if (existsSync(settingsDest)) {
    skipped.push(".claude/settings.json (preserved)");
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
