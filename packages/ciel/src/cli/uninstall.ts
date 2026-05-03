// Uninstall command — remove Ciel files from the current project

import { existsSync, unlinkSync, rmSync, readdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import { say, ok, warn, header } from "./utils";

export interface UninstallOptions {
  yes: boolean;
  quiet: boolean;
}

export async function runUninstall(options: UninstallOptions): Promise<void> {
  const { yes } = options;
  const targetDir = process.cwd();
  let count = 0;

  header("Ciel — Uninstall");

  // Ciel state directory
  const cielDir = join(targetDir, ".ciel");
  if (existsSync(cielDir)) {
    rmSync(cielDir, { recursive: true, force: true });
    ok(".ciel/ removed");
    count++;
  }

  // OpenCode: plugin file
  const pluginPath = join(targetDir, ".opencode/plugins/ciel.ts");
  if (existsSync(pluginPath)) {
    unlinkSync(pluginPath);
    ok(".opencode/plugins/ciel.ts removed");
    count++;
  }

  // OpenCode: Ciel agents (only Ciel-specific files)
  const agentFiles = [
    "ciel.md", "ciel-researcher.md", "ciel-explorer.md",
    "ciel-critic.md", "ciel-improver.md",
  ];
  for (const agent of agentFiles) {
    const path = join(targetDir, ".opencode/agents", agent);
    if (existsSync(path)) {
      unlinkSync(path);
      ok(`.opencode/agents/${agent} removed`);
      count++;
    }
  }

  // OpenCode: Ciel commands
  const commandsDir = join(targetDir, ".opencode/commands");
  if (existsSync(commandsDir)) {
    try {
      const files = readdirSync(commandsDir);
      for (const file of files) {
        if (file.startsWith("ciel-")) {
          unlinkSync(join(commandsDir, file));
          ok(`.opencode/commands/${file} removed`);
          count++;
        }
      }
    } catch { /* ignore */ }
  }

  // Shared files
  for (const f of ["AGENTS.md", "CLAUDE.md"]) {
    const path = join(targetDir, f);
    if (existsSync(path)) {
      unlinkSync(path);
      ok(`${f} removed`);
      count++;
    }
  }

  // Claude Code: Ciel agents
  for (const agent of ["ciel-researcher.md", "ciel-explorer.md", "ciel-critic.md", "ciel-improver.md"]) {
    const path = join(targetDir, ".claude/agents", agent);
    if (existsSync(path)) {
      unlinkSync(path);
      ok(`.claude/agents/${agent} removed`);
      count++;
    }
  }

  // Claude Code: Ciel hooks
  for (const hook of ["check-test-first.sh", "block-destructive.sh", "track-file.sh", "meta-critiquer.sh"]) {
    const path = join(targetDir, ".claude/hooks", hook);
    if (existsSync(path)) {
      unlinkSync(path);
      ok(`.claude/hooks/${hook} removed`);
      count++;
    }
  }

  // Claude Code: Ciel commands
  const claudeCommandsDir = join(targetDir, ".claude/commands");
  if (existsSync(claudeCommandsDir)) {
    try {
      const files = readdirSync(claudeCommandsDir);
      for (const file of files) {
        if (file.startsWith("ciel-")) {
          unlinkSync(join(claudeCommandsDir, file));
          ok(`.claude/commands/${file} removed`);
          count++;
        }
      }
    } catch { /* ignore */ }
  }

  // Claude Code: Ciel skill
  const skillDir = join(targetDir, ".claude/skills/ciel");
  if (existsSync(skillDir)) {
    rmSync(skillDir, { recursive: true, force: true });
    ok(".claude/skills/ciel/ removed");
    count++;
  }

  // Claude Code settings: remove Ciel hooks from JSON
  const settingsPath = join(targetDir, ".claude/settings.json");
  if (existsSync(settingsPath)) {
    try {
      const raw = readFileSync(settingsPath, "utf-8");
      const config = JSON.parse(raw);
      if (config.hooks) {
        // Remove Ciel-related hooks
        for (const key of Object.keys(config.hooks)) {
          if (Array.isArray(config.hooks[key])) {
            config.hooks[key] = config.hooks[key].filter(
              (h: any) => !JSON.stringify(h).toLowerCase().includes("ciel")
            );
          }
        }
        // Remove empty hooks
        const hasHooks = Object.values(config.hooks).some(
          (v: any) => Array.isArray(v) && v.length > 0
        );
        if (!hasHooks) delete config.hooks;
        writeFileSync(settingsPath, JSON.stringify(config, null, 2) + "\n", "utf-8");
        ok(".claude/settings.json (Ciel hooks removed)");
        count++;
      }
    } catch {
      warn("Could not patch .claude/settings.json");
    }
  }

  // opencode.json: remove Ciel plugin reference
  const opencodeConfigPath = join(targetDir, "opencode.json");
  if (existsSync(opencodeConfigPath)) {
    try {
      const raw = readFileSync(opencodeConfigPath, "utf-8");
      const config = JSON.parse(raw);
      if (config.plugin) {
        config.plugin = config.plugin.filter(
          (p: string) => p !== "@neikyun/ciel" && p !== "./.opencode/plugins/ciel.ts"
        );
      }
      if (config.instructions) {
        config.instructions = config.instructions.filter(
          (i: string) => i !== "AGENTS.md"
        );
      }
      writeFileSync(opencodeConfigPath, JSON.stringify(config, null, 2) + "\n", "utf-8");
      ok("opencode.json (Ciel references removed)");
      count++;
    } catch {
      warn("Could not patch opencode.json");
    }
  }

  header("Uninstall Complete");
  ok(`${count} file(s) affected`);
  say("Ciel has been uninstalled from this project.");
  say("Restart your editor for changes to take effect.");
}
