// OpenCode platform installer logic
// Handles detection, file copy, and config generation for OpenCode projects

import { existsSync, mkdirSync, copyFileSync, readFileSync, writeFileSync } from "fs";
import { join, dirname } from "path";
import { ok, warn } from "./utils";

export interface OpenCodeOptions {
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
 * Detect if the project has OpenCode configuration.
 */
export function detectOpenCode(targetDir: string): boolean {
  return (
    existsSync(join(targetDir, "opencode.json")) ||
    existsSync(join(targetDir, ".opencode"))
  );
}

/**
 * Find the compiled plugin JS file from various install locations.
 * Returns the absolute path to dist/plugin/index.js or null.
 */
function findPluginJs(srcDir: string): string | null {
  const candidates = [
    // NPM local: assets/dist/plugin/index.js (bundled by copy-assets)
    join(srcDir, "dist/plugin/index.js"),
    // NPM global: from assets/, go up to package root
    join(srcDir, "..", "dist/plugin/index.js"),
    join(srcDir, "../..", "dist/plugin/index.js"),
    // GitHub download: platforms/opencode/.opencode/plugins/ciel.js
    join(srcDir, "platforms/opencode/.opencode/plugins/ciel.js"),
    // Dev mode: from repo root
    join(srcDir, "packages/ciel/dist/plugin/index.js"),
    // Direct path (if srcDir is already the plugin dir)
    join(srcDir, "ciel.js"),
  ];
  for (const candidate of candidates) {
    if (existsSync(candidate)) return candidate;
  }
  return null;
}

/**
 * Install Ciel files for OpenCode platform.
 */
export function installOpenCode(opts: OpenCodeOptions): InstallResult {
  const { targetDir, srcDir, force } = opts;
  const installed: string[] = [];
  const skipped: string[] = [];

  const agentsSrc = join(srcDir, "platforms/opencode/.opencode/agents");
  const agentsDest = join(targetDir, ".opencode/agents");
  const commandsSrc = join(srcDir, "platforms/opencode/.opencode/commands");
  const commandsDest = join(targetDir, ".opencode/commands");

  // Create directories
  mkdirSync(join(targetDir, ".opencode/plugins"), { recursive: true });
  mkdirSync(agentsDest, { recursive: true });
  mkdirSync(commandsDest, { recursive: true });

  // Copy compiled plugin JS (self-contained, no node_modules needed)
  const pluginJs = findPluginJs(srcDir);
  if (pluginJs) {
    const pluginDest = join(targetDir, ".opencode/plugins/ciel.js");
    const action = copyIfNewer(pluginJs, pluginDest, force);
    if (action === "copied") installed.push(".opencode/plugins/ciel.js");
    else skipped.push("plugin.js");
  } else {
    // Fallback: try old .ts source (dev mode)
    const pluginTs = join(srcDir, "platforms/opencode/.opencode/plugins/ciel.ts");
    if (existsSync(pluginTs)) {
      const pluginTsDest = join(targetDir, ".opencode/plugins/ciel.ts");
      const action = copyIfNewer(pluginTs, pluginTsDest, force);
      if (action === "copied") installed.push(".opencode/plugins/ciel.ts");
    }
  }

  // Copy agents
  const agentFiles = [
    "ciel.md",
    "ciel-researcher.md",
    "ciel-explorer.md",
    "ciel-critic.md",
    "ciel-improver.md",
  ];
  for (const agent of agentFiles) {
    const src = join(agentsSrc, agent);
    const dest = join(agentsDest, agent);
    if (existsSync(src)) {
      const action = copyIfNewer(src, dest, force);
      if (action === "copied") installed.push(`.opencode/agents/${agent}`);
    }
  }

  // Copy commands
  const commandFiles = [
    "ciel-init.md",
    "ciel-update.md",
    "ciel-improve.md",
    "ciel-eval.md",
    "ciel-create-skill.md",
    "ciel-audit.md",
    "ciel-status.md",
    "ciel-memory-bootstrap.md",
    "ciel.md",
  ];
  for (const cmd of commandFiles) {
    const src = join(commandsSrc, cmd);
    const dest = join(commandsDest, cmd);
    if (existsSync(src)) {
      const action = copyIfNewer(src, dest, force);
      if (action === "copied") installed.push(`.opencode/commands/${cmd}`);
    }
  }

  // Copy AGENTS.md if not present (first install only)
  const agentsMdPath = join(targetDir, "AGENTS.md");
  const agentsMdSrc = join(srcDir, "platforms/opencode/AGENTS.md");
  if (existsSync(agentsMdSrc) && !existsSync(agentsMdPath)) {
    try {
      copyFileSync(agentsMdSrc, agentsMdPath);
      installed.push("AGENTS.md");
    } catch {
      skipped.push("AGENTS.md");
    }
  }

  // Generate or patch opencode.json (NEVER overwrite — always merge)
  const configPath = join(targetDir, "opencode.json");
  if (!existsSync(configPath)) {
    generateOpencodeConfig(configPath);
    installed.push("opencode.json");
  } else {
    patchOpencodeConfig(configPath);
    installed.push("opencode.json (patched)");
  }

  return { installed, skipped };
}

/**
 * Generate a complete opencode.json with Ciel agent definitions.
 */
function generateOpencodeConfig(configPath: string): void {
  const config = {
    $schema: "https://opencode.ai/config.json",
    instructions: ["AGENTS.md"],
    plugin: ["./.opencode/plugins/ciel.js"],
    permission: {
      edit: "allow",
      bash: "allow",
      webfetch: "allow",
      websearch: "allow",
      question: "allow",
      skill: "allow",
    },
    agent: {
      ciel: {
        description:
          "Ciel v6 — Primary orchestrator. Full pipeline. Dispatch subagents. Depth: Trivial/Standard/Critical.",
        mode: "primary",
        prompt: "{file:./.opencode/agents/ciel.md}",
        temperature: 0.2,
        permission: {
          edit: "allow",
          bash: "allow",
          question: "allow",
          skill: "allow",
          task: {
            "*": "deny",
            "ciel-researcher": "allow",
            "ciel-explorer": "allow",
            "ciel-critic": "allow",
            "ciel-improver": "allow",
          },
        },
      },
      "ciel-researcher": {
        description: "RECHERCHE — docs officielles, anti-patterns. WebFetch + WebSearch.",
        mode: "subagent",
        prompt: "{file:./.opencode/agents/ciel-researcher.md}",
        temperature: 0.1,
        permission: {
          read: "allow",
          glob: "allow",
          grep: "allow",
          bash: "allow",
          webfetch: "allow",
          websearch: "allow",
          write: "deny",
          edit: "deny",
        },
      },
      "ciel-explorer": {
        description: "CODEBASE + FLUX — pattern-fitness, data flow narration.",
        mode: "subagent",
        prompt: "{file:./.opencode/agents/ciel-explorer.md}",
        temperature: 0.1,
        permission: {
          read: "allow",
          glob: "allow",
          grep: "allow",
          bash: "allow",
          write: "deny",
          edit: "deny",
        },
      },
      "ciel-critic": {
        description:
          "RELIRE/CRITIQUER/RCA — hostile review, root-cause analysis.",
        mode: "subagent",
        prompt: "{file:./.opencode/agents/ciel-critic.md}",
        temperature: 0.1,
        permission: {
          read: "allow",
          glob: "allow",
          grep: "allow",
          bash: "allow",
          write: "deny",
          edit: "deny",
        },
      },
      "ciel-improver": {
        description: "Méta-amélioration Ciel — analyse sessions, skill patches.",
        mode: "subagent",
        prompt: "{file:./.opencode/agents/ciel-improver.md}",
        temperature: 0.1,
        permission: {
          read: "allow",
          glob: "allow",
          grep: "allow",
          bash: "allow",
          webfetch: "allow",
          websearch: "allow",
          write: "ask",
          edit: "ask",
        },
      },
    },
  };

  mkdirSync(dirname(configPath), { recursive: true });
  writeFileSync(configPath, JSON.stringify(config, null, 2) + "\n", "utf-8");
}

/**
 * Patch existing opencode.json to add Ciel plugin reference.
 */
function patchOpencodeConfig(configPath: string): void {
  try {
    const raw = readFileSync(configPath, "utf-8");
    const config = JSON.parse(raw);

    // Ensure plugin array contains the local Ciel plugin
    if (!config.plugin) config.plugin = [];
    // Replace old npm reference with local path
    config.plugin = config.plugin.filter((p: string) => p !== "@neikyun/ciel" && p !== "./.opencode/plugins/ciel.ts");
    if (!config.plugin.includes("./.opencode/plugins/ciel.js")) {
      config.plugin.push("./.opencode/plugins/ciel.js");
    }

    // Ensure instructions contain AGENTS.md
    if (!config.instructions) config.instructions = [];
    if (!config.instructions.includes("AGENTS.md")) {
      config.instructions.push("AGENTS.md");
    }

    writeFileSync(configPath, JSON.stringify(config, null, 2) + "\n", "utf-8");
  } catch {
    warn("Could not patch opencode.json — add plugin reference manually");
  }
}

/**
 * Copy file only if destination doesn't exist or force is true.
 * Returns "copied", "skipped", or "missing".
 */
function copyIfNewer(src: string, dest: string, force: boolean): string {
  if (!existsSync(src)) return "missing";
  if (existsSync(dest) && !force) return "skipped";
  try {
    mkdirSync(dirname(dest), { recursive: true });
    copyFileSync(src, dest);
    return "copied";
  } catch {
    return "skipped";
  }
}
