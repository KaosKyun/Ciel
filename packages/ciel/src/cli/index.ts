#!/usr/bin/env node
// Ciel CLI — @ciel/cli
// Usage: npx ciel-init [command] [options]
//
// Commands:
//   init        Install Ciel in the current project (default)
//   update      Force reinstall / update
//   uninstall   Remove Ciel from the current project
//   check       Check version + verify installation integrity

import { runInit } from "./init";
import { runUninstall } from "./uninstall";
import { runCheck, checkVersionOnly } from "./check";
import { getVersion } from "./version";

function usage(): void {
  const v = getVersion();
  console.log(`
Ciel v${v} — CLI

Auto-detects OpenCode or Claude Code and installs plugins, agents,
hooks, and commands into your project.

USAGE:
  npx ciel-init [command] [options]

COMMANDS:
  init          Install Ciel in the current project (default)
  update        Force reinstall (run after npm update -g @neikyun/ciel)
  repair        Repair missing/broken Ciel files (alias for update)
  uninstall     Remove all Ciel files from the project
  check         Check version + verify all Ciel files are installed

OPTIONS:
  -y, --yes     Skip confirmation prompt (non-interactive)
  -q, --quiet   Suppress progress output
  --check       (with update) Only check for newer version, don't install
  --help        Show this help message
  --version     Show version

EXAMPLES:
  npx ciel-init                   Install interactively
  npx ciel-init -y                Install in CI without prompt
  npx ciel-init update            Force reinstall
  npx ciel-init update --check    Check for newer version only
  npx ciel-init uninstall         Remove Ciel
  npx ciel-init check             Check version + installation integrity
  npx ciel-init check --integrity  Verify installation files only
  npx ciel-init check --version-only  Check NPM version only
  npx ciel-init repair            Reinstall missing/broken files
`);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.includes("--help") || args.includes("-h")) {
    usage();
    process.exit(0);
  }

  if (args.includes("--version") || args.includes("-v")) {
    console.log(getVersion());
    process.exit(0);
  }

  const command = args.find((a) => !a.startsWith("-")) || "init";
  const options = {
    yes: args.includes("--yes") || args.includes("-y"),
    quiet: args.includes("--quiet") || args.includes("-q"),
  };

  switch (command) {
    case "init":
      await runInit(options);
      break;
    case "update":
    case "repair":
      if (args.includes("--check")) {
        await checkVersionOnly();
        process.exit(0);
      }
      await runInit({ ...options, force: true });
      break;
    case "uninstall":
      await runUninstall(options);
      break;
    case "check":
      await runCheck();
      break;
    default:
      console.error(`Unknown command: ${command}`);
      console.error(`Run 'npx ciel-init --help' for usage.`);
      process.exit(1);
  }
}

main().catch((err) => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
