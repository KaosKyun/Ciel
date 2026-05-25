#!/usr/bin/env node
// Ciel CLI — bootstrap entry point
// Global install default → use `ciel init` / `ciel update` in your project.

const { existsSync, mkdirSync, writeFileSync, readFileSync } = require("fs");
const { join } = require("path");

const PKG_DIR = join(__dirname, "..");
const PKG = JSON.parse(readFileSync(join(PKG_DIR, "package.json"), "utf-8"));
const CIEL_VERSION = PKG.version || "0.0.0";

const args = process.argv.slice(2);
const isHelp = args.includes("--help") || args.includes("-h");
const isVersion = args.includes("--version") || args.includes("-v");

if (isHelp) {
  console.log(`
Ciel v${CIEL_VERSION} — Deep-reasoning pipeline

USAGE:
  ciel <command> [options]

COMMANDS:
  init          Install Ciel in the current project (interactive)
  update        Update Ciel + reinstall project files
  repair        Repair missing/broken files (alias for update)
  uninstall     Remove all Ciel files from the project
  check         Check version + verify installation integrity
  doctor        Health check (score 0-100)
  memory        Query and manage cued-recall memory

GLOBAL OPTIONS:
  -y, --yes     Skip prompts (non-interactive)
  -q, --quiet   Suppress progress output
  --help        Show this help message
  --version     Show version

EXAMPLES:
  ciel init                   Install interactively in this project
  ciel init -y                Install headless (CI / Claude session)
  ciel update                 Update Ciel to latest version
  ciel check                  Verify installation integrity
  ciel uninstall               Remove Ciel from this project
`);
  process.exit(0);
}

if (isVersion) {
  console.log(CIEL_VERSION);
  process.exit(0);
}

// Write global version sentinel for cross-session tracking
try {
  const userCielDir = join(require("os").homedir(), ".ciel");
  mkdirSync(userCielDir, { recursive: true });
  writeFileSync(join(userCielDir, "version"), CIEL_VERSION + "\n", "utf-8");
} catch {}

// Load the CLI
require("../dist/cli/index.js");
