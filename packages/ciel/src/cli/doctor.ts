// Doctor command — Ciel health check
// Checks hooks presence, memory index integrity, asset sync, rules completeness.
// Scores 0-100. Exits non-zero if score < 100.

import { existsSync, readFileSync, readdirSync } from "fs";
import { join } from "path";
import { execFileSync } from "child_process";
import { say, ok, warn, header } from "./utils";
import { getVersion } from "./version";
import { CIEL_HOOK_FILES } from "./claude";

interface CategoryResult {
  ok: boolean;
  detail: string;
  score: number;
}

interface DoctorResult {
  score: number;
  hooks: CategoryResult;
  memory: CategoryResult;
  assets: CategoryResult;
  rules: CategoryResult;
}

const REQUIRED_HOOKS = CIEL_HOOK_FILES.map((f) => `.claude/hooks/${f}`);
const RULES_DIR = ".claude/rules";

function checkHooks(targetDir: string): CategoryResult {
  const hooksDir = join(targetDir, ".claude", "hooks");
  if (!existsSync(hooksDir)) {
    return { ok: false, detail: "hooks directory missing", score: 0 };
  }

  const missing: string[] = [];
  for (const hook of REQUIRED_HOOKS) {
    const path = join(targetDir, hook);
    if (!existsSync(path)) {
      missing.push(hook);
    }
  }

  if (missing.length > 0) {
    return {
      ok: false,
      detail: `${missing.length} hooks missing: ${missing.join(", ")}`,
      score: Math.max(0, 25 - missing.length * 5),
    };
  }

  return { ok: true, detail: `${REQUIRED_HOOKS.length} hooks present`, score: 25 };
}

function checkMemory(targetDir: string): CategoryResult {
  const index = join(targetDir, ".ciel", "memory", "index.json");
  if (!existsSync(index)) {
    return { ok: true, detail: "no memory index (empty project)", score: 25 };
  }

  try {
    const data = JSON.parse(readFileSync(index, "utf-8"));
    const memIds = new Set(Object.keys(data.memories || {}));
    const indexMaps: Record<string, Record<string, string[]>> = {
      by_path: data.by_path || {},
      by_symbol: data.by_symbol || {},
      by_intent: data.by_intent || {},
      by_language: data.by_language || {},
    };

    let orphanCount = 0;
    let emptyKeys = 0;

    for (const [name, idxMap] of Object.entries(indexMaps)) {
      for (const [key, mids] of Object.entries(idxMap)) {
        if (!Array.isArray(mids) || mids.length === 0) {
          emptyKeys++;
          continue;
        }
        for (const mid of mids) {
          if (!memIds.has(mid)) orphanCount++;
        }
      }
    }

    if (orphanCount > 0 || emptyKeys > 0) {
      const issues: string[] = [];
      if (orphanCount > 0) issues.push(`${orphanCount} orphan references`);
      if (emptyKeys > 0) issues.push(`${emptyKeys} empty keys`);
      return {
        ok: false,
        detail: `index corrupted: ${issues.join(", ")}. Run rebuild-index.`,
        score: Math.max(0, 25 - orphanCount - emptyKeys * 2),
      };
    }

    return {
      ok: true,
      detail: `index valid (${memIds.size} memories, ${Object.keys(indexMaps.by_path || {}).length + Object.keys(indexMaps.by_symbol || {}).length + Object.keys(indexMaps.by_intent || {}).length} index entries)`,
      score: 25,
    };
  } catch {
    return { ok: false, detail: "index.json unreadable", score: 0 };
  }
}

function checkAssets(targetDir: string): CategoryResult {
  // Check if copy-assets would change anything
  const script = join(targetDir, "packages", "ciel", "scripts", "copy-assets.cjs");
  if (!existsSync(script)) {
    // Not the Ciel dev repo — skip asset sync check
    return { ok: true, detail: "not a dev repo (copy-assets not found)", score: 25 };
  }

  try {
    // Run copy-assets and check if it produced changes
    execFileSync("node", [script], { encoding: "utf8", stdio: "pipe" });
    // Check git diff on assets
    const diff = execFileSync("git", ["diff", "--name-only", "--", "packages/ciel/assets/"], {
      cwd: targetDir,
      encoding: "utf8",
      stdio: "pipe",
    });
    if (diff.trim()) {
      const files = diff.trim().split("\n").length;
      return {
        ok: false,
        detail: `${files} assets out of sync. Run copy-assets.cjs.`,
        score: Math.max(0, 25 - files * 3),
      };
    }
    return { ok: true, detail: "assets in sync", score: 25 };
  } catch {
    return { ok: false, detail: "asset sync check failed", score: 0 };
  }
}

function checkRules(targetDir: string): CategoryResult {
  const rulesDir = join(targetDir, RULES_DIR);
  if (!existsSync(rulesDir)) {
    return { ok: false, detail: "rules directory missing", score: 10 };
  }

  const ruleFiles = readdirSync(rulesDir).filter((f) => f.endsWith(".md"));
  if (ruleFiles.length === 0) {
    return { ok: false, detail: "no domain rules found", score: 5 };
  }

  return {
    ok: true,
    detail: `${ruleFiles.length} domain rules`,
    score: 25,
  };
}

export function runDoctor(cwd?: string): DoctorResult {
  const targetDir = cwd || process.cwd();

  const hooks = checkHooks(targetDir);
  const memory = checkMemory(targetDir);
  const assets = checkAssets(targetDir);
  const rules = checkRules(targetDir);

  const score = hooks.score + memory.score + assets.score + rules.score;

  return { score: Math.min(100, score), hooks, memory, assets, rules };
}

export async function doctorMain(args: string[]): Promise<void> {
  const version = getVersion();
  const json = args.includes("--json");
  const quiet = args.includes("--quiet");
  const cwdArg = args.find((a) => a.startsWith("--cwd="));
  const cwd = cwdArg ? cwdArg.slice(6) : undefined;

  const result = runDoctor(cwd);

  if (json) {
    console.log(JSON.stringify(result));
  } else if (!quiet) {
    header(`Ciel v${version} — Health Check`);
    for (const [name, cat] of Object.entries(result)) {
      if (name === "score") continue;
      const c = cat as CategoryResult;
      const icon = c.ok ? "✓" : "✗";
      if (c.ok) ok(`${icon} ${name}: ${c.detail}`);
      else warn(`${icon} ${name}: ${c.detail}`);
    }
    say(`\nScore: ${result.score}/100`);
  }

  if (result.score < 100) process.exit(1);
}
