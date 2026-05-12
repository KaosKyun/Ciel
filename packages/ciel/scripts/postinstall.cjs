#!/usr/bin/env node
// Ciel postinstall — s'exécute après npm install / npm update
//
// Toujours visible. Détecte les plateformes, configure, ou guide l'utilisateur.
// Désactivable avec CI=true ou --ignore-scripts

const { existsSync, readFileSync, writeFileSync, mkdirSync, copyFileSync, chmodSync, unlinkSync, readdirSync } = require("fs");
const { join, dirname } = require("path");

// ---- Version ----
const PKG = JSON.parse(readFileSync(join(__dirname, "..", "package.json"), "utf-8"));
const CIEL_VERSION = PKG.version || "0.0.0";

// ---- Couleurs ----
const c = (code, s) => process.stdout.isTTY ? `\x1b[${code}m${s}\x1b[0m` : s;
const cyan = (s) => c(36, s);
const green = (s) => c(32, s);
const yellow = (s) => c(33, s);
const bold = (s) => c(1, s);

// ---- Détection de plateforme ----
function detectPlatforms(targetDir) {
  const platforms = [];
  if (existsSync(join(targetDir, "opencode.json")) || existsSync(join(targetDir, ".opencode"))) platforms.push("OpenCode");
  if (existsSync(join(targetDir, ".claude/settings.json")) || existsSync(join(targetDir, ".claude"))) platforms.push("Claude Code");
  return platforms;
}

function resolveAssets() {
  for (const dir of [join(__dirname, "..", "assets"), join(__dirname, "..", "..", "assets")]) {
    if (existsSync(join(dir, "platforms/opencode/.opencode/agents/ciel.md"))) return dir;
  }
  return null;
}

function detectCLI(name) {
  // Cherche l'exécutable dans le PATH directement (fiable cross-platform)
  const pathExt = process.env.PATHEXT ? process.env.PATHEXT.split(";") : ["", ".exe", ".cmd", ".bat", ".com"];
  const pathDirs = (process.env.PATH || "").split(require("path").delimiter);
  for (const dir of pathDirs) {
    for (const ext of pathExt) {
      const fullPath = require("path").join(dir, name + ext);
      if (existsSync(fullPath)) return true;
    }
  }
  return false;
}

// ---- Installation ----
function cleanDir(dir) {
  // Supprime tout le contenu d'un dossier (mais garde le dossier)
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      const { rmSync } = require("fs");
      try { rmSync(full, { recursive: true, force: true }); } catch {}
    } else {
      try { unlinkSync(full); } catch {}
    }
  }
}

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

function installOpenCode(targetDir, assets) {
  let count = 0;
  // Nettoyer les anciens fichiers (pour mise à jour propre)
  cleanDir(join(targetDir, ".opencode/agents"));
  cleanDir(join(targetDir, ".opencode/commands"));
  cleanDir(join(targetDir, ".opencode/skills"));
  // Nettoyer anciens plugins
  for (const old of ["ciel.ts", "ciel.js"]) {
    const p = join(targetDir, ".opencode/plugins", old);
    if (existsSync(p)) { try { unlinkSync(p); count++; } catch {} }
  }
  // Copier le plugin JS compilé (auto-suffisant, pas de node_modules requis)
  const pluginJs = join(__dirname, "..", "dist/plugin/index.js");
  if (existsSync(pluginJs)) {
    mkdirSync(join(targetDir, ".opencode/plugins"), { recursive: true });
    copyFileSync(pluginJs, join(targetDir, ".opencode/plugins/ciel.js"));
    count++;
  }
  // Copier agents
  count += copyDir(join(assets, "platforms/opencode/.opencode/agents"), join(targetDir, ".opencode/agents"));
  // Copier commandes
  count += copyDir(join(assets, "platforms/opencode/.opencode/commands"), join(targetDir, ".opencode/commands"));
  // Copier skills
  count += copyDir(join(assets, "skills"), join(targetDir, ".opencode/skills"));
  // Copier AGENTS.md
  if (existsSync(join(assets, "platforms/opencode/AGENTS.md"))) {
    copyFileSync(join(assets, "platforms/opencode/AGENTS.md"), join(targetDir, "AGENTS.md"));
    count++;
  }
  // Patcher opencode.json (local plugin path)
  try {
    const cfgPath = join(targetDir, "opencode.json");
    if (existsSync(cfgPath)) {
      let cfg = JSON.parse(readFileSync(cfgPath, "utf-8"));
      if (!cfg.plugin) cfg.plugin = [];
      // Remplacer anciennes refs par le chemin local
      cfg.plugin = cfg.plugin.filter(p => p !== "@neikyun/ciel" && p !== "./.opencode/plugins/ciel.ts");
      if (!cfg.plugin.includes("./.opencode/plugins/ciel.js")) cfg.plugin.push("./.opencode/plugins/ciel.js");
      if (!cfg.instructions) cfg.instructions = [];
      if (!cfg.instructions.includes("AGENTS.md")) cfg.instructions.push("AGENTS.md");
      writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + "\n", "utf-8");
      count++;
    }
  } catch {}
  return count;
}

function installClaude(targetDir, assets) {
  let count = 0;
  // Nettoyer les anciens fichiers
  cleanDir(join(targetDir, ".claude/agents"));
  cleanDir(join(targetDir, ".claude/hooks"));
  cleanDir(join(targetDir, ".claude/commands"));
  cleanDir(join(targetDir, ".claude/skills"));
  count += copyDir(join(assets, ".claude/agents"), join(targetDir, ".claude/agents"));
  count += copyDir(join(assets, ".claude/hooks"), join(targetDir, ".claude/hooks"));
  count += copyDir(join(assets, "commands"), join(targetDir, ".claude/commands"));
  count += copyDir(join(assets, "skills"), join(targetDir, ".claude/skills"));
  // Settings — only copy if missing (preserves user config on update)
  const settings = join(assets, ".claude/settings.json");
  const settingsDest = join(targetDir, ".claude/settings.json");
  if (existsSync(settings) && !existsSync(settingsDest)) {
    copyFileSync(settings, settingsDest);
    count++;
  }
  const claudeMd = join(assets, "CLAUDE.md");
  if (existsSync(claudeMd)) { copyFileSync(claudeMd, join(targetDir, "CLAUDE.md")); count++; }
  return count;
}

// ---- MAIN ----
async function main() {
  if (process.env.CI || process.env.NO_CIEL_POSTINSTALL) return;

  // INIT_CWD = répertoire où l'utilisateur a lancé npm install
  // (npm lance les lifecycle scripts dans node_modules/<pkg>/, pas dans le projet)
  const targetDir = process.env.INIT_CWD || process.cwd();

  // Skip si on installe dans le repo source Ciel lui-même (évite les doublons
  // quand le développeur travaille dans le repo et que .claude/commands/ est déjà committé)
  const selfPkgPath = join(targetDir, "packages/ciel/package.json");
  if (existsSync(selfPkgPath)) {
    try {
      const selfPkg = JSON.parse(readFileSync(selfPkgPath, "utf-8"));
      if (selfPkg.name === "@neikyun/ciel") {
        console.error(`  ${cyan("→")} Source repo détecté — installation ignorée (fichiers déjà dans .claude/).\n`);
        return;
      }
    } catch {}
  }

  const platforms = detectPlatforms(targetDir);
  const assetsDir = resolveAssets();

  // TOUJOURS chercher les CLI, même si des plateformes sont déjà détectées
  const hasClaudeCLI = detectCLI("claude");
  const hasOpenCodeCLI = detectCLI("opencode");
  if (hasClaudeCLI && !platforms.includes("Claude Code")) platforms.push("Claude Code");
  if (hasOpenCodeCLI && !platforms.includes("OpenCode")) platforms.push("OpenCode");

  // Toujours afficher le message Ciel (sur stderr pour être visible via npm)
  console.error(`\n  ${bold("✦ Ciel v" + CIEL_VERSION)}`);

  if (!assetsDir) {
    console.error(`  ${yellow("~")} Templates non trouvés (package corrompu ?)\n`);
    return;
  }

  if (platforms.length === 0) {
    // Aucune plateforme détectée (ni config, ni CLI)
    console.error(`  ${yellow("~")} Aucune plateforme détectée.`);
    console.error(`    Installez ${cyan("opencode")} ou ${cyan("claude")} puis relancez.`);
    console.error(`    Ou: ${green("npx ciel init")}\n`);
    return;
  }

  // Demander confirmation (sauter si non-TTY)
  let ok = true;
  if (process.stdin.isTTY) {
    try {
      const readline = require("readline");
      const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
      ok = await new Promise(r => rl.question(`  ${yellow("?")} Configurer Ciel pour ${cyan(platforms.join(" + "))} ? ${green("(Y/n)")} `, a => { rl.close(); r(a.trim().toLowerCase() !== "n"); }));
    } catch { ok = true; }
  }

  if (!ok) {
    console.error(`  ${cyan("→")} Annulé.\n`);
    return;
  }

  // Créer .ciel/
  mkdirSync(join(targetDir, ".ciel"), { recursive: true });
  if (!existsSync(join(targetDir, ".ciel/map.json")))
    writeFileSync(join(targetDir, ".ciel/map.json"), JSON.stringify({ modules: [], lastUpdated: "" }), "utf-8");
  if (!existsSync(join(targetDir, ".ciel/parking.md")))
    writeFileSync(join(targetDir, ".ciel/parking.md"), "# Ciel Parking Lot\n\n", "utf-8");
  // Cued-recall memory directories
  mkdirSync(join(targetDir, ".ciel/memory/episodes"), { recursive: true });
  mkdirSync(join(targetDir, ".ciel/memory/concepts"), { recursive: true });
  mkdirSync(join(targetDir, ".ciel/memory/guards"), { recursive: true });

  // Installer
  let total = 0;
  for (const p of platforms) {
    const n = p === "OpenCode" ? installOpenCode(targetDir, assetsDir) : installClaude(targetDir, assetsDir);
    total += n;
    console.error(`  ${green("✓")} ${p}: ${n} fichiers`);
  }

  // Sauvegarder version
  writeFileSync(join(targetDir, ".ciel/memory.json"), JSON.stringify({ cielVersion: CIEL_VERSION, lastUpdated: new Date().toISOString() }, null, 2), "utf-8");
  // Version sentinel — read by hooks/session-start.sh at runtime (no hardcoded MSG to drift).
  writeFileSync(join(targetDir, ".ciel/version"), CIEL_VERSION + "\n", "utf-8");
  try {
    const userCielDir = join(require("os").homedir(), ".ciel");
    mkdirSync(userCielDir, { recursive: true });
    writeFileSync(join(userCielDir, "version"), CIEL_VERSION + "\n", "utf-8");
  } catch {}

  console.error(`\n  ${green("✓")} Ciel v${CIEL_VERSION} installé !`);
  if (platforms.includes("OpenCode")) console.error(`    → plugin ${cyan("@neikyun/ciel")} ajouté à opencode.json`);
  if (platforms.includes("Claude Code")) console.error(`    → redémarrez ${cyan("claude .")}`);
  console.error();
}

main().catch(() => {});
