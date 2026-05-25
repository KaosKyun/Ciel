#!/usr/bin/env node
// Ciel CLI
// Usage: ciel [command] [options]
//
// Commands:
//   init        Install Ciel in the current project (default)
//   update      Update Ciel + reinstall project files
//   uninstall   Remove Ciel from the current project
//   check       Check version + verify installation integrity

import { runInit } from "./init";
import { runUninstall } from "./uninstall";
import { runCheck, checkVersionOnly } from "./check";
import { doctorMain } from "./doctor";
import { memoryMain } from "./memory";
import { getVersion } from "./version";
import { say, warn } from "./utils";

function usage(): void {
  const v = getVersion();
  console.log(`
Ciel v${v} — CLI

Auto-detects OpenCode or Claude Code and installs plugins, agents,
hooks, and commands into your project.

USAGE:
  ciel [command] [options]
  npx @neikyun/ciel [command] [options]   (if not installed globally)

COMMANDS:
  init          Install Ciel in the current project (interactive)
  update        Update Ciel + reinstall project files
  repair        Repair missing/broken Ciel files (alias for update)
  uninstall     Remove all Ciel files from the project
  check         Check version + verify all Ciel files are installed
  doctor        Health check: hooks, memory index, assets, rules (score 0-100)
  memory        Query and manage cued-recall memory (query, list, show, stats, save, rebuild)

OPTIONS:
  -y, --yes     Skip confirmation prompt (non-interactive)
  -q, --quiet   Suppress progress output
  --check       (with update) Only check for newer version, don't install
  --help        Show this help message
  --version     Show version

EXAMPLES:
  ciel init                   Install interactively in this project
  ciel init -y                Install headless (CI / Claude session)
  ciel update                 Update Ciel to latest version
  ciel update --check         Check for newer version only
  ciel check                  Verify installation integrity
  ciel uninstall               Remove Ciel from this project
  ciel repair                 Reinstall missing/broken files
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
      // Update the npm package itself first, then reinstall project files.
      // --skip-npm-update prevents infinite re-exec loop (set on re-spawn).
      if (!args.includes("--skip-npm-update")) {
        const { execSync } = await import("child_process");
        say("Updating @neikyun/ciel via npm...");
        let updated = false;
        try {
          execSync("npm update -g @neikyun/ciel", { stdio: "inherit" });
          updated = true;
        } catch {
          try {
            execSync("npm update @neikyun/ciel", { stdio: "inherit" });
            updated = true;
          } catch {
            warn("npm update failed, continuing with installed version");
          }
        }
        if (updated) {
          // Re-exec with the freshly updated binary to run init
          const passthrough = [...process.argv.slice(1).filter(a => a !== "update" && a !== "repair"), "update", "--skip-npm-update", "--yes"];
          // Prefer `ciel` (global install), fallback to npx
          const runner = (() => {
            try { execSync("which ciel 2>/dev/null || where ciel 2>nul", { stdio: "pipe" }); return "ciel"; } catch { return `npx @neikyun/ciel`; }
          })();
          try {
            execSync(`${runner} ${passthrough.map(a => `"${a}"`).join(" ")}`, { stdio: "inherit" });
          } catch {
            warn(`${runner} re-exec failed, falling back to in-process init`);
            await runInit({ ...options, force: true, yes: true });
          }
          process.exit(0);
        }
      }
      await runInit({ ...options, force: true });
      break;
    case "uninstall":
      await runUninstall(options);
      break;
    case "check":
      await runCheck();
      break;
    case "doctor":
      await doctorMain(args);
      break;
    case "memory":
      await memoryMain(args);
      break;
    default:
      console.error(`Unknown command: ${command}`);
      console.error(`Run 'ciel --help' for usage.`);
      process.exit(1);
  }
}

main().catch((err) => {
  console.error("Fatal error:", err.message);
  process.exit(1);
});
