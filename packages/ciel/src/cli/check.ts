// Check command — compare local version against NPM registry
// + verify installation integrity (all expected files present and valid)
// (NPM is the canonical distribution channel for Ciel v6+)

import { get as httpsGet } from "https";
import { existsSync, readFileSync, accessSync, constants } from "fs";
import { join } from "path";
import { ok, err, say, warn, header } from "./utils";
import { getVersion } from "./version";
import { detectOpenCode } from "./opencode";
import { detectClaude } from "./claude";

const NPM_REGISTRY = "https://registry.npmjs.org/@neikyun/ciel/latest";
const CIEL_VERSION = getVersion();

function fetchUrl(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const req = httpsGet(url, {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(10000),
    }, (res) => {
      let data = "";
      res.on("data", (chunk: string) => (data += chunk));
      res.on("end", () => resolve(data));
    });
    req.on("error", reject);
    req.on("timeout", () => {
      req.destroy();
      reject(new Error("Request timed out"));
    });
  });
}

function compareVersions(a: string, b: string): number {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const na = pa[i] || 0;
    const nb = pb[i] || 0;
    if (na > nb) return 1;
    if (na < nb) return -1;
  }
  return 0;
}

// ─── Integrity check ───────────────────────────────────────────────

interface FileSpec {
  path: string;
  label: string;
  /** If true, missing = error; if false, missing = warning */
  required: boolean;
  /** Extra validation: returns error message or null if ok */
  validate?: (targetDir: string) => string | null;
}

const CLAUDE_AGENTS = [
  "ciel-researcher.md",
  "ciel-explorer.md",
  "ciel-critic.md",
  "ciel-improver.md",
];

const CLAUDE_HOOKS = [
  "check-test-first.sh",
  "block-destructive.sh",
  "track-file.sh",
  "meta-critiquer.sh",
  "session-version-check.sh",
  "pre-tool-write.sh",
  "pre-agent-gate.sh",
  "session-start.sh",
  "user-prompt-submit.sh",
  "memory-bootstrap.sh",
  "memory-engine.py",
];

const CLAUDE_COMMANDS = [
  "ciel-init.md",
  "ciel-update.md",
  "ciel-eval.md",
  "ciel-create-skill.md",
  "ciel-audit.md",
  "ciel-status.md",
  "ciel-memory-bootstrap.md",
];

const OPENCODE_AGENTS = [
  "ciel.md",
  "ciel-researcher.md",
  "ciel-explorer.md",
  "ciel-critic.md",
  "ciel-improver.md",
];

const OPENCODE_COMMANDS = [
  "ciel.md",
  "ciel-init.md",
  "ciel-update.md",
  "ciel-improve.md",
  "ciel-eval.md",
  "ciel-create-skill.md",
  "ciel-audit.md",
  "ciel-status.md",
  "ciel-memory-bootstrap.md",
];

function checkFile(targetDir: string, relPath: string): boolean {
  return existsSync(join(targetDir, relPath));
}

function checkExecutable(targetDir: string, relPath: string): boolean {
  try {
    accessSync(join(targetDir, relPath), constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function validateSettings(targetDir: string): string | null {
  const p = join(targetDir, ".claude/settings.json");
  if (!existsSync(p)) return null; // handled by existence check
  try {
    const raw = readFileSync(p, "utf-8");
    const cfg = JSON.parse(raw);
    if (!cfg || typeof cfg !== "object" || Array.isArray(cfg)) {
      return "not a valid JSON object";
    }
    const hooks = cfg.hooks;
    if (!hooks || typeof hooks !== "object") {
      return "no hooks registered — Ciel hooks not wired";
    }
    // Check for at least one Ciel hook
    let hasCielHook = false;
    for (const event of Object.keys(hooks)) {
      const entries = Array.isArray(hooks[event]) ? hooks[event] : [];
      for (const entry of entries) {
        const inner = Array.isArray(entry?.hooks) ? entry.hooks : [];
        for (const h of inner) {
          if (typeof h?.command === "string" && h.command.includes(".claude/hooks/")) {
            hasCielHook = true;
          }
        }
      }
    }
    if (!hasCielHook) return "no Ciel hooks found in settings.json";
    return null;
  } catch {
    return "invalid JSON: syntax error";
  }
}

function validateOpencodeConfig(targetDir: string): string | null {
  const p = join(targetDir, "opencode.json");
  if (!existsSync(p)) return null;
  try {
    const raw = readFileSync(p, "utf-8");
    const cfg = JSON.parse(raw);
    if (!cfg || typeof cfg !== "object" || Array.isArray(cfg)) {
      return "not a valid JSON object";
    }
    const plugin: string[] = cfg.plugin || [];
    const hasCielPlugin = plugin.some(
      (p: string) => p.includes("ciel.js") || p.includes("ciel.ts")
    );
    if (!hasCielPlugin) return "Ciel plugin not referenced in opencode.json";
    return null;
  } catch {
    return "invalid JSON: syntax error";
  }
}

interface IntegrityResult {
  ok: string[];
  missing: string[];
  warnings: string[];
  errors: string[];
}

export function checkIntegrity(targetDir: string): IntegrityResult {
  const result: IntegrityResult = { ok: [], missing: [], warnings: [], errors: [] };
  const hasOpenCode = detectOpenCode(targetDir);
  const hasClaude = detectClaude(targetDir);

  // ── Shared state files ──
  for (const f of ["map.json", "memory.json", "parking.md"]) {
    const path = `.ciel/${f}`;
    if (checkFile(targetDir, path)) {
      result.ok.push(path);
    } else {
      result.missing.push(path);
    }
  }

  // ── Claude Code ──
  if (hasClaude) {
    // CLAUDE.md
    if (checkFile(targetDir, "CLAUDE.md")) {
      result.ok.push("CLAUDE.md");
    } else {
      result.missing.push("CLAUDE.md");
    }

    // settings.json
    if (checkFile(targetDir, ".claude/settings.json")) {
      const settingErr = validateSettings(targetDir);
      if (settingErr) {
        result.errors.push(`.claude/settings.json: ${settingErr}`);
      } else {
        result.ok.push(".claude/settings.json");
      }
    } else {
      result.missing.push(".claude/settings.json");
    }

    // Agents
    for (const agent of CLAUDE_AGENTS) {
      const path = `.claude/agents/${agent}`;
      if (checkFile(targetDir, path)) {
        result.ok.push(path);
      } else {
        result.missing.push(path);
      }
    }

    // Hooks
    for (const hook of CLAUDE_HOOKS) {
      const path = `.claude/hooks/${hook}`;
      if (checkFile(targetDir, path)) {
        if (checkExecutable(targetDir, path)) {
          result.ok.push(path);
        } else {
          result.warnings.push(`${path}: not executable (chmod +x needed)`);
        }
      } else {
        result.missing.push(path);
      }
    }

    // Commands
    for (const cmd of CLAUDE_COMMANDS) {
      const path = `.claude/commands/${cmd}`;
      if (checkFile(targetDir, path)) {
        result.ok.push(path);
      } else {
        result.warnings.push(`${path}: missing (optional command)`);
      }
    }

    // Skills
    for (const skill of ["SKILL.md", "reference.md"]) {
      const path = `.claude/skills/ciel/${skill}`;
      if (checkFile(targetDir, path)) {
        result.ok.push(path);
      } else {
        result.missing.push(path);
      }
    }
  }

  // ── OpenCode ──
  if (hasOpenCode) {
    // AGENTS.md
    if (checkFile(targetDir, "AGENTS.md")) {
      result.ok.push("AGENTS.md");
    } else {
      result.missing.push("AGENTS.md");
    }

    // opencode.json
    if (checkFile(targetDir, "opencode.json")) {
      const cfgErr = validateOpencodeConfig(targetDir);
      if (cfgErr) {
        result.errors.push(`opencode.json: ${cfgErr}`);
      } else {
        result.ok.push("opencode.json");
      }
    } else {
      result.missing.push("opencode.json");
    }

    // Plugin
    const pluginJs = checkFile(targetDir, ".opencode/plugins/ciel.js");
    const pluginTs = checkFile(targetDir, ".opencode/plugins/ciel.ts");
    if (pluginJs || pluginTs) {
      result.ok.push(pluginJs ? ".opencode/plugins/ciel.js" : ".opencode/plugins/ciel.ts");
    } else {
      result.missing.push(".opencode/plugins/ciel.js (or .ts)");
    }

    // Agents
    for (const agent of OPENCODE_AGENTS) {
      const path = `.opencode/agents/${agent}`;
      if (checkFile(targetDir, path)) {
        result.ok.push(path);
      } else {
        result.missing.push(path);
      }
    }

    // Commands
    for (const cmd of OPENCODE_COMMANDS) {
      const path = `.opencode/commands/${cmd}`;
      if (checkFile(targetDir, path)) {
        result.ok.push(path);
      } else {
        result.warnings.push(`${path}: missing (optional command)`);
      }
    }
  }

  // ── No platform detected ──
  if (!hasOpenCode && !hasClaude) {
    result.errors.push(
      "No Ciel platform detected. Run 'npx ciel-init' from an OpenCode or Claude Code project."
    );
  }

  return result;
}

// ─── Main entry point ──────────────────────────────────────────────

async function checkVersion(): Promise<number> {
  try {
    const raw = await fetchUrl(NPM_REGISTRY);
    const pkg = JSON.parse(raw);
    const remoteVersion: string = pkg.version;

    if (!remoteVersion) {
      err("Could not fetch latest version from NPM registry.");
      err("Check your internet connection.");
      return 2;
    }

    const cmp = compareVersions(CIEL_VERSION, remoteVersion);

    if (cmp === 0) {
      ok(`Ciel v${CIEL_VERSION} is up to date.`);
      return 0;
    }

    if (cmp < 0) {
      console.log(`  Update available: v${CIEL_VERSION} → v${remoteVersion}`);
      console.log("");
      console.log("  If installed globally:");
      console.log("    npm update -g @neikyun/ciel");
      console.log("    npx ciel-init update");
      console.log("");
      console.log("  If installed in project:");
      console.log("    npm update @neikyun/ciel");
      return 0;
    }

    say(`Ciel v${CIEL_VERSION} (ahead of npm v${remoteVersion} — dev mode)`);
    return 0;
  } catch (error: any) {
    err(`Version check failed: ${error.message}`);
    return 0; // version check is non-fatal for exit code
  }
}

export async function checkVersionOnly(): Promise<number> {
  return checkVersion();
}

function runIntegrityCheck(): number {
  const targetDir = process.cwd();
  const result = checkIntegrity(targetDir);

  if (result.ok.length > 0) {
    header(`Ciel v${CIEL_VERSION} — Integrity Check (${result.ok.length} OK)`);
  }

  if (result.errors.length > 0) {
    for (const e of result.errors) err(e);
  }

  if (result.missing.length > 0) {
    console.log("");
    say(`Missing files (${result.missing.length}):`);
    for (const m of result.missing) {
      console.log(`    - ${m}`);
    }
    console.log("");
    say("Run 'npx ciel-init repair' to reinstall missing files.");
  }

  if (result.warnings.length > 0) {
    for (const w of result.warnings) warn(w);
  }

  if (result.missing.length === 0 && result.errors.length === 0 && result.warnings.length === 0) {
    ok("All Ciel files present and valid.");
  }

  // Exit code: non-zero if errors or missing required files
  return result.errors.length > 0 || result.missing.length > 0 ? 1 : 0;
}

export async function runCheck(): Promise<void> {
  const args = process.argv.slice(2);

  // ── Flag parsing ──
  const integrityOnly = args.includes("--integrity-only") || args.includes("--integrity");
  const versionOnly = args.includes("--version-only");

  let exitCode = 0;

  if (!integrityOnly) {
    exitCode = await checkVersion();
  }

  if (!versionOnly) {
    console.log(""); // blank line between version and integrity
    const integrityCode = runIntegrityCheck();
    if (exitCode === 0) exitCode = integrityCode;
  }

  process.exit(exitCode);
}
