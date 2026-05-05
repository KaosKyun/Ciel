// Claude Code platform installer logic
// Handles detection, file copy, and config generation for Claude Code projects

import { existsSync, mkdirSync, copyFileSync, chmodSync, readFileSync, writeFileSync, statSync, unlinkSync } from "fs";
import { join, dirname } from "path";
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
  const { targetDir, srcDir, force } = opts;
  const installed: string[] = [];
  const skipped: string[] = [];

  // Claude Code directories
  const agentsDest = join(targetDir, ".claude/agents");
  const hooksDest = join(targetDir, ".claude/hooks");
  const commandsDest = join(targetDir, ".claude/commands");
  const skillsDest = join(targetDir, ".claude/skills/ciel");

  // Create directories (remove file-blocker if path exists as a regular file)
  mkdirSafe(agentsDest);
  mkdirSafe(hooksDest);
  mkdirSafe(commandsDest);
  mkdirSafe(skillsDest);

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
      }
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
    } catch {
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
    } catch {
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
    } catch {
      skipped.push(".claude/settings.json");
    }
  } else if (existsSync(settingsDest)) {
    skipped.push(".claude/settings.json (preserved)");
  }

  return { installed, skipped };
}

/** Remove a file-blocker then create the directory. */
function mkdirSafe(dir: string): void {
  if (existsSync(dir) && !statSync(dir).isDirectory()) {
    unlinkSync(dir);
  }
  mkdirSync(dir, { recursive: true });
}

/**
 * Copy file only if destination doesn't exist or force is true.
 */
function copyIfNewer(src: string, dest: string, force: boolean): string {
  if (!existsSync(src)) return "missing";
  if (existsSync(dest) && !force) return "skipped";
  try {
    mkdirSafe(dirname(dest));
    copyFileSync(src, dest);
    return "copied";
  } catch {
    return "skipped";
  }
}
