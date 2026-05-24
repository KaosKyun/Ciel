#!/usr/bin/env node
// Ciel CLI — bootstrap entry point
// Vérifie si l'initialisation est nécessaire et détecte les nouvelles plateformes.

const { existsSync, mkdirSync, writeFileSync, readFileSync, copyFileSync, readdirSync, chmodSync, unlinkSync, rmSync } = require("fs");
const { join, delimiter } = require("path");

const PKG_DIR = join(__dirname, "..");
const PKG = JSON.parse(readFileSync(join(PKG_DIR, "package.json"), "utf-8"));
const CIEL_VERSION = PKG.version || "0.0.0";
const ASSETS = join(PKG_DIR, "assets");
const targetDir = process.env.INIT_CWD || process.cwd();
const memPath = join(targetDir, ".ciel", "memory.json");

const c = (code, s) => process.stderr.isTTY ? `\x1b[${code}m${s}\x1b[0m` : s;
const green = (s) => c(32, s);
const cyan = (s) => c(36, s);

// Cherche un exécutable dans le PATH (fiable cross-platform, pas besoin de shell)
function searchPath(name) {
  const pathExt = (process.env.PATHEXT || "").split(";");
  if (!pathExt[0]) pathExt.push("", ".exe", ".cmd", ".bat", ".com");
  const pathDirs = (process.env.PATH || "").split(delimiter);
  for (const dir of pathDirs) {
    for (const ext of pathExt) {
      if (existsSync(join(dir, name + ext))) return true;
    }
  }
  return false;
}

// ---- Helpers ----
function copyDir(src, dest) {
  if (!existsSync(src)) return 0;
  let count = 0;
  mkdirSync(dest, { recursive: true });
  for (const entry of readdirSync(src, { withFileTypes: true })) {
    const s = join(src, entry.name), d = join(dest, entry.name);
    if (entry.isDirectory()) count += copyDir(s, d);
    else { copyFileSync(s, d); if (s.endsWith(".sh")) try { chmodSync(d, 0o755); } catch {} count++; }
  }
  return count;
}

function patchOpencodeJson(targetDir) {
  const cfgPath = join(targetDir, "opencode.json");
  if (!existsSync(cfgPath)) return false;
  try {
    const cfg = JSON.parse(readFileSync(cfgPath, "utf-8"));
    if (!cfg.plugin) cfg.plugin = [];
    cfg.plugin = cfg.plugin.filter(p => p !== "./.opencode/plugins/ciel.ts");
    if (!cfg.plugin.includes("@neikyun/ciel")) cfg.plugin.push("@neikyun/ciel");
    if (!cfg.instructions) cfg.instructions = [];
    if (!cfg.instructions.includes("AGENTS.md")) cfg.instructions.push("AGENTS.md");
    writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + "\n", "utf-8");
    return true;
  } catch { return false; }
}

// ---- Détection des plateformes ----
function detectPlatforms() {
  const platforms = [];
  const hasOC = existsSync(join(targetDir, "opencode.json")) || existsSync(join(targetDir, ".opencode"));
  const hasClaude = existsSync(join(targetDir, ".claude/settings.json")) || existsSync(join(targetDir, ".claude"));

  // Détection CLI
  const hasOC_CLI = searchPath("opencode");
  const hasClaude_CLI = searchPath("claude");

  if (hasOC || hasOC_CLI) platforms.push("OpenCode");
  if (hasClaude || hasClaude_CLI) platforms.push("Claude Code");
  return platforms;
}

// ---- Installer une plateforme ----
function cleanDir(dir) {
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) { try { rmSync(full, { recursive: true, force: true }); } catch {} }
    else { try { unlinkSync(full); } catch {} }
  }
}

function installOpenCode() {
  let total = 0;
  cleanDir(join(targetDir, ".opencode/agents"));
  cleanDir(join(targetDir, ".opencode/commands"));
  cleanDir(join(targetDir, ".opencode/skills"));
  const old = join(targetDir, ".opencode/plugins/ciel.ts");
  if (existsSync(old)) { try { unlinkSync(old); } catch {} }
  total += copyDir(join(ASSETS, "platforms/opencode/.opencode/agents"), join(targetDir, ".opencode/agents"));
  total += copyDir(join(ASSETS, "platforms/opencode/.opencode/commands"), join(targetDir, ".opencode/commands"));
  total += copyDir(join(ASSETS, "skills"), join(targetDir, ".opencode/skills"));
  if (existsSync(join(ASSETS, "platforms/opencode/AGENTS.md"))) {
    copyFileSync(join(ASSETS, "platforms/opencode/AGENTS.md"), join(targetDir, "AGENTS.md"));
    total++;
  }
  if (patchOpencodeJson(targetDir)) total++;
  return total;
}

function cleanDir(dir) {
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) { try { rmSync(full, { recursive: true, force: true }); } catch {} }
    else { try { unlinkSync(full); } catch {} }
  }
}

function installClaude() {
  let total = 0;
  cleanDir(join(targetDir, ".claude/agents"));
  cleanDir(join(targetDir, ".claude/hooks"));
  cleanDir(join(targetDir, ".claude/commands"));
  cleanDir(join(targetDir, ".claude/skills"));
  total += copyDir(join(ASSETS, ".claude/agents"), join(targetDir, ".claude/agents"));
  total += copyDir(join(ASSETS, ".claude/hooks"), join(targetDir, ".claude/hooks"));
  total += copyDir(join(ASSETS, "commands"), join(targetDir, ".claude/commands"));
  total += copyDir(join(ASSETS, "skills"), join(targetDir, ".claude/skills"));
  if (existsSync(join(ASSETS, ".claude/settings.json"))) {
    copyFileSync(join(ASSETS, ".claude/settings.json"), join(targetDir, ".claude/settings.json"));
  }
  if (existsSync(join(ASSETS, "CLAUDE.md"))) {
    copyFileSync(join(ASSETS, "CLAUDE.md"), join(targetDir, "CLAUDE.md"));
  }
  return total;
}

function ensureCielState() {
  mkdirSync(join(targetDir, ".ciel"), { recursive: true });
  if (!existsSync(join(targetDir, ".ciel/map.json")))
    writeFileSync(join(targetDir, ".ciel/map.json"), JSON.stringify({ modules: [], lastUpdated: "" }), "utf-8");
  if (!existsSync(join(targetDir, ".ciel/parking.md")))
    writeFileSync(join(targetDir, ".ciel/parking.md"), "# Ciel Parking Lot\n\n", "utf-8");
  writeFileSync(memPath, JSON.stringify({ cielVersion: CIEL_VERSION, lastUpdated: new Date().toISOString() }, null, 2), "utf-8");
}

// ===== MAIN BOOT =====
const args = process.argv.slice(2);
const isHelp = args.includes("--help") || args.includes("-h");
const isVersion = args.includes("--version") || args.includes("-v");

if (!isHelp && !isVersion && ASSETS && existsSync(join(ASSETS, "platforms/opencode/.opencode/agents/ciel.md"))) {
  try {
    const storedVersion = (() => { try { return JSON.parse(readFileSync(memPath, "utf-8")).cielVersion; } catch { return null; } })();
    const needsInit = !storedVersion || storedVersion !== CIEL_VERSION;

    // Toujours détecter les plateformes
    const platforms = detectPlatforms();

    // Créer les configs si CLI détectée mais pas de fichiers
    if (platforms.includes("OpenCode") && !existsSync(join(targetDir, "opencode.json"))) {
      writeFileSync(join(targetDir, "opencode.json"), JSON.stringify({ $schema: "https://opencode.ai/config.json", plugin: ["@neikyun/ciel"] }, null, 2) + "\n", "utf-8");
    }
    if (platforms.includes("Claude Code") && !existsSync(join(targetDir, ".claude/settings.json"))) {
      mkdirSync(join(targetDir, ".claude"), { recursive: true });
      writeFileSync(join(targetDir, ".claude/settings.json"), "{}\n", "utf-8");
    }

    // Vérifier ce qui manque pour chaque plateforme détectée
    const opencodeFilesExist = existsSync(join(targetDir, ".opencode/agents/ciel.md"));
    const claudeFilesExist = existsSync(join(targetDir, ".claude/hooks/pre-tool-write.sh"));

    if (needsInit || (platforms.includes("OpenCode") && !opencodeFilesExist) || (platforms.includes("Claude Code") && !claudeFilesExist)) {
      let n = 0;
      console.error(`\n  ⚡ Ciel v${CIEL_VERSION} — Configuration...`);
      ensureCielState();

      if (platforms.includes("OpenCode") && (!opencodeFilesExist || needsInit)) {
        n += installOpenCode();
        console.error(`  ${green("✓")} OpenCode: agents + commands`);
      }
      if (platforms.includes("Claude Code") && (!claudeFilesExist || needsInit)) {
        n += installClaude();
        console.error(`  ${green("✓")} Claude Code: agents + hooks + commands`);
      }
      console.error(`  ${green("✓")} Ciel v${CIEL_VERSION} prêt !\n`);
    }
  } catch {}
}

// Lancer la CLI normalement
require("../dist/cli/index.js");
