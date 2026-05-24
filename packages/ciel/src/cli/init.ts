// Init command — install Ciel into the current project
// Handles both OpenCode and Claude Code platforms

import { existsSync, mkdirSync, writeFileSync, mkdtempSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";
import { say, ok, warn, header, promptConfirm } from "./utils";
import { installOpenCode, detectOpenCode } from "./opencode";
import { installClaude, detectClaude } from "./claude";
import { getVersion } from "./version";

export interface InitOptions {
  yes: boolean;
  quiet: boolean;
  force?: boolean;
}

/**
 * Signal file to verify when resolving the template source directory.
 */
const AGENT_SIGNAL = "platforms/opencode/.opencode/agents/ciel.md";
const GITHUB_RAW = "https://raw.githubusercontent.com/KaosKyun/Ciel/main";

/**
 * Resolve the source directory for template files.
 *
 * Tries, in order:
 *   1. Dev mode — running from repo root
 *   2. npm assets — bundled templates (packages/cli/assets/)
 *   3. npm global — various npx/npm install locations
 *   4. GitHub — download to temp directory (fallback)
 *
 * Returns the directory containing platform/opencode/..., or null.
 */
function resolveSourceDir(): string | null {
  const candidates = [
    // Dev: running from repo root
    process.cwd(),
    // Dev: running from packages/cli/ (workspace)
    join(process.cwd(), "../.."),
    // Dev: running from packages/ (sub-workspace)
    join(process.cwd(), ".."),
    // npm: bundled assets (compiled CLI: __dirname = dist/cli/)
    join(__dirname, "..", "..", "assets"),
    // npm: installed globally (__dirname = dist/cli/ → go up to root)
    join(__dirname, "..", ".."),
    // npm: one level from assets (if __dirname is assets/)
    join(__dirname, "..", "assets"),
    // npm: npx cache deeper
    join(__dirname, ".."),
    join(__dirname, "../.."),
    join(__dirname, "../../.."),
  ];

  for (const dir of candidates) {
    if (existsSync(join(dir, AGENT_SIGNAL))) {
      return dir;
    }
  }

  return null;
}

/**
 * Download all required template files from GitHub to a local directory.
 * Uses the same URL scheme as install.sh (curl mode).
 */
async function downloadTemplatesToTemp(): Promise<string | null> {
  const tmpDir = mkdtempSync(join(tmpdir(), "ciel-templates-"));
  const templatePaths = [
    // Compiled plugin JS (for local reference, no node_modules needed)
    "platforms/opencode/.opencode/plugins/ciel.js",
    // OpenCode agents
    "platforms/opencode/.opencode/agents/ciel.md",
    "platforms/opencode/.opencode/agents/ciel-researcher.md",
    "platforms/opencode/.opencode/agents/ciel-explorer.md",
    "platforms/opencode/.opencode/agents/ciel-critic.md",
    "platforms/opencode/.opencode/agents/ciel-improver.md",
    // OpenCode commands
    "platforms/opencode/.opencode/commands/ciel-init.md",
    "platforms/opencode/.opencode/commands/ciel-update.md",
    "platforms/opencode/.opencode/commands/ciel-improve.md",
    "platforms/opencode/.opencode/commands/ciel-eval.md",
    "platforms/opencode/.opencode/commands/ciel-create-skill.md",
    "platforms/opencode/.opencode/commands/ciel-status.md",
    "platforms/opencode/.opencode/commands/ciel-audit.md",
    "platforms/opencode/.opencode/commands/ciel-memory-bootstrap.md",
    "platforms/opencode/.opencode/commands/ciel.md",
    // OpenCode platform
    "platforms/opencode/AGENTS.md",
    // Claude Code agents
    ".claude/agents/ciel-researcher.md",
    ".claude/agents/ciel-explorer.md",
    ".claude/agents/ciel-critic.md",
    ".claude/agents/ciel-improver.md",
    // Claude Code hooks
    ".claude/hooks/check-test-first.sh",
    ".claude/hooks/block-destructive.sh",
    ".claude/hooks/track-file.sh",
    ".claude/hooks/meta-critiquer.sh",
    ".claude/hooks/session-version-check.sh",
    ".claude/hooks/pre-tool-write.sh",
    ".claude/hooks/pre-agent-gate.sh",
    ".claude/hooks/session-start.sh",
    ".claude/hooks/user-prompt-submit.sh",
    ".claude/hooks/memory-bootstrap.sh",
    ".claude/hooks/memory-engine.py",
    // Claude Code settings
    ".claude/settings.json",
    // Shared files
    "CLAUDE.md",
    "AGENTS.md",
    // Generic commands
    "commands/ciel-init.md",
    "commands/ciel-update.md",
    "commands/ciel-eval.md",
    "commands/ciel-create-skill.md",
    "commands/ciel-status.md",
    "commands/ciel-audit.md",
    "commands/ciel-memory-bootstrap.md",
    // Ciel skill
    "skills/ciel/SKILL.md",
    "skills/ciel/reference.md",
  ];

  let downloaded = 0;

  for (const relPath of templatePaths) {
    try {
      const url = `${GITHUB_RAW}/${relPath}`;
      const response = await fetch(url);
      if (!response.ok) continue;

      const content = await response.text();
      const destPath = join(tmpDir, relPath);
      mkdirSync(join(destPath, ".."), { recursive: true });
      writeFileSync(destPath, content, "utf-8");
      downloaded++;
    } catch {
      // Skip failed downloads — continue with the next file
    }
  }

  // Verify we got the critical signal file
  if (!existsSync(join(tmpDir, AGENT_SIGNAL))) {
    warn(`Could not download template files from GitHub (${downloaded}/${templatePaths.length} files)`);
    return null;
  }

  ok(`Downloaded ${downloaded} template files from GitHub`);
  return tmpDir;
}

export async function runInit(options: InitOptions): Promise<void> {
  const { yes, quiet, force = false } = options;
  const version = getVersion();
  const targetDir = process.cwd();

  header(`Ciel v${version} — Install`);

  // Resolve source templates directory (local or GitHub)
  let srcDir = resolveSourceDir();

  if (!srcDir) {
    // Not found locally — try GitHub download
    warn("Local template files not found. Trying GitHub download...");
    srcDir = await downloadTemplatesToTemp();
  }

  if (!srcDir) {
    warn("Could not find Ciel template files.");
    warn("Make sure you have @ciel/cli properly installed.");
    warn("Or run from the Ciel project root.");
    warn("");
    warn("Still using curl? Try the legacy installer:");
    warn("  curl -fsSL https://install.ciel.sh | bash");
    process.exit(1);
  }

  // Detect platforms
  const hasOpenCode = detectOpenCode(targetDir);
  const hasClaude = detectClaude(targetDir);

  // Interactive confirmation
  if (!yes) {
    const platforms = [hasOpenCode ? "OpenCode" : "", hasClaude ? "Claude Code" : ""]
      .filter(Boolean)
      .join(" + ") || "unknown";
    const confirmed = await promptConfirm(
      `Install Ciel v${version} in ${targetDir} (detected: ${platforms})?`,
      true
    );
    if (!confirmed) {
      say("Aborted.");
      process.exit(0);
    }
  }

  // Create .ciel/ state directory
  mkdirSync(join(targetDir, ".ciel"), { recursive: true });
  if (!existsSync(join(targetDir, ".ciel/map.json"))) {
    writeFileSync(join(targetDir, ".ciel/map.json"), JSON.stringify({ modules: [], lastUpdated: "" }), "utf-8");
  }
  if (!existsSync(join(targetDir, ".ciel/memory.json"))) {
    writeFileSync(join(targetDir, ".ciel/memory.json"), "{}", "utf-8");
  }
  if (!existsSync(join(targetDir, ".ciel/parking.md"))) {
    writeFileSync(join(targetDir, ".ciel/parking.md"), "# Ciel Parking Lot -- Decouvertes fortuites\n\n", "utf-8");
  }

  // Install for each detected platform
  if (hasOpenCode) {
    say("Installing for OpenCode...");
    const result = installOpenCode({ targetDir, srcDir, force, quiet });
    for (const f of result.installed) ok(f);
    for (const f of result.skipped) warn(`Skipped: ${f}`);
  }

  if (hasClaude) {
    say("Installing for Claude Code...");
    const result = installClaude({ targetDir, srcDir, force, quiet });
    for (const f of result.installed) ok(f);
    for (const f of result.skipped) warn(`Skipped: ${f}`);
  }

  // Fallback: install generic files
  if (!hasOpenCode && !hasClaude) {
    warn("No recognized platform config found.");
    say("Installing shared files (.ciel/, AGENTS.md)");
  }

  // Summary
  header(`Ciel v${version} — Install Complete`);
  ok("Run 'npx ciel-init check' to verify installation");
  ok("Run 'npx ciel-init repair' to fix missing files");
  if (hasOpenCode) {
    say("OpenCode: restart OpenCode to load Ciel");
    say("  Test: type a message — should see depth classification");
    say("  For SPIKE mode: touch .ciel/exploration.active");
  }
  if (hasClaude) {
    say("Claude Code: restart Claude Code to load Ciel");
    say("  Test: edit a file without tests — hook should warn");
  }
}
