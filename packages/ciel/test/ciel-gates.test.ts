// ciel-gates — tests for the v9 determinism gates added in the autonomy refactor.
//   - track-verification.sh : records .ciel/last-verification on a test run
//   - track-file.sh         : records .ciel/last-code-edit on a logic-file edit
//   - pre-agent-gate.sh     : writes .ciel/dispatched on a research dispatch
//   - parity                : CIEL_HOOK_FILES === CLAUDE_HOOKS, all shipped in assets/
//
// Strategy: shell out to the real hook with stdin JSON + a throwaway project dir.

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { mkdtempSync, mkdirSync, existsSync, rmSync, readdirSync, readFileSync, writeFileSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";

import { CIEL_HOOK_FILES } from "../src/cli/claude";
import { CLAUDE_HOOKS } from "../src/cli/check";

const HOOKS = join(__dirname, "..", "..", "..", "hooks");
const ASSETS_HOOKS = join(__dirname, "..", "assets", ".claude", "hooks");
const RULES_DIR = join(__dirname, "..", "..", "..", ".claude", "rules");

function tmpProject(): string {
  const dir = mkdtempSync(join(tmpdir(), "ciel-gates-"));
  mkdirSync(join(dir, ".ciel"), { recursive: true });
  return dir;
}

function runHook(name: string, input: object, projectDir?: string): void {
  const env = { ...process.env };
  if (projectDir) env.CLAUDE_PROJECT_DIR = projectDir;
  else delete env.CLAUDE_PROJECT_DIR;
  try {
    execFileSync("bash", [join(HOOKS, name)], { input: JSON.stringify(input), encoding: "utf8", env });
  } catch {
    /* hooks may exit non-zero (e.g. deny); the side effect is what we assert */
  }
}

const hasJq = (() => {
  try { execFileSync("bash", ["-c", "command -v jq"], { encoding: "utf8" }); return true; }
  catch { return false; }
})();

describe("track-verification.sh", () => {
  it("records last-verification when a test runner is observed", () => {
    const dir = tmpProject();
    try {
      runHook("track-verification.sh", { tool_input: { command: "npm test" } }, dir);
      assert.ok(existsSync(join(dir, ".ciel", "last-verification")), "npm test ⇒ marker");
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });

  it("records for pytest / go test / cargo test too", () => {
    for (const cmd of ["pytest -q", "go test ./...", "cargo test"]) {
      const dir = tmpProject();
      try {
        runHook("track-verification.sh", { tool_input: { command: cmd } }, dir);
        assert.ok(existsSync(join(dir, ".ciel", "last-verification")), `${cmd} ⇒ marker`);
      } finally { rmSync(dir, { recursive: true, force: true }); }
    }
  });

  it("records for project-local verification commands (bash test scripts, --check, make, tsx test)", () => {
    for (const cmd of [
      "bash scripts/test-install-coverage.sh",
      "bash scripts/sync-mirrors.sh --check",
      "npx tsx .opencode/test-ciel.ts",
      "make test",
      "make check",
    ]) {
      const dir = tmpProject();
      try {
        runHook("track-verification.sh", { tool_input: { command: cmd } }, dir);
        assert.ok(existsSync(join(dir, ".ciel", "last-verification")), `${cmd} ⇒ marker`);
      } finally { rmSync(dir, { recursive: true, force: true }); }
    }
  });

  it("does NOT record for a non-test command", () => {
    const dir = tmpProject();
    try {
      runHook("track-verification.sh", { tool_input: { command: "ls -la && git status" } }, dir);
      assert.ok(!existsSync(join(dir, ".ciel", "last-verification")), "non-test ⇒ no marker");
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });

  it("is a no-op without CLAUDE_PROJECT_DIR (no crash)", () => {
    runHook("track-verification.sh", { tool_input: { command: "npm test" } });
    assert.ok(true, "ran without throwing");
  });
});

describe("track-file.sh", () => {
  it("records last-code-edit for a logic file", { skip: !hasJq ? "jq not installed" : false }, () => {
    const dir = tmpProject();
    try {
      runHook("track-file.sh", { tool_input: { file_path: "/proj/src/foo.ts" } }, dir);
      assert.ok(existsSync(join(dir, ".ciel", "last-code-edit")), ".ts edit ⇒ marker");
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });

  it("does NOT record last-code-edit for a markdown file", { skip: !hasJq ? "jq not installed" : false }, () => {
    const dir = tmpProject();
    try {
      runHook("track-file.sh", { tool_input: { file_path: "/proj/README.md" } }, dir);
      assert.ok(!existsSync(join(dir, ".ciel", "last-code-edit")), ".md edit ⇒ no marker");
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });
});

describe("pre-agent-gate.sh — dispatch marker", () => {
  it("writes .ciel/dispatched for a ciel-researcher dispatch", () => {
    const dir = tmpProject();
    try {
      runHook("pre-agent-gate.sh", { tool_input: { subagent_type: "ciel-researcher", prompt: "x" } }, dir);
      assert.ok(existsSync(join(dir, ".ciel", "dispatched")), "researcher ⇒ marker");
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });

  it("writes .ciel/dispatched for a ciel-explorer dispatch", () => {
    const dir = tmpProject();
    try {
      runHook("pre-agent-gate.sh", { tool_input: { subagent_type: "ciel-explorer", prompt: "x" } }, dir);
      assert.ok(existsSync(join(dir, ".ciel", "dispatched")), "explorer ⇒ marker");
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });

  it("does NOT write the marker for a non-research ciel agent (e.g. improver)", () => {
    const dir = tmpProject();
    try {
      runHook("pre-agent-gate.sh", { tool_input: { subagent_type: "ciel-improver", prompt: "x" } }, dir);
      assert.ok(!existsSync(join(dir, ".ciel", "dispatched")), "improver ⇒ no marker");
    } finally { rmSync(dir, { recursive: true, force: true }); }
  });
});

describe("hook list parity (guards against the v9 drift)", () => {
  it("CIEL_HOOK_FILES (claude.ts) === CLAUDE_HOOKS (check.ts)", () => {
    assert.deepEqual([...CIEL_HOOK_FILES].sort(), [...CLAUDE_HOOKS].sort());
  });

  it("every installed hook is actually shipped in assets/.claude/hooks/", () => {
    for (const hook of CIEL_HOOK_FILES) {
      assert.ok(existsSync(join(ASSETS_HOOKS, hook)), `${hook} listed for install but missing from assets/`);
    }
  });
});

describe("rules frontmatter validity (a malformed rule silently never fires)", () => {
  const ruleFiles = readdirSync(RULES_DIR).filter((f) => f.endsWith(".md"));

  it("there is at least one rule", () => {
    assert.ok(ruleFiles.length > 0, "no rules found");
  });

  for (const file of ruleFiles) {
    it(`${file} has a closed frontmatter with a non-empty paths: list`, () => {
      const content = readFileSync(join(RULES_DIR, file), "utf8");
      assert.ok(content.startsWith("---\n"), `${file}: must start with YAML frontmatter`);
      const end = content.indexOf("\n---", 4);
      assert.ok(end > 0, `${file}: frontmatter must be closed with ---`);
      const fm = content.slice(4, end);
      assert.ok(/(^|\n)paths:/.test(fm), `${file}: frontmatter must declare paths:`);
      // At least one glob entry under paths: (a list item with a quoted glob).
      assert.ok(/\n\s*-\s+["']?\*?\*?/.test(fm), `${file}: paths: must have at least one glob entry`);
    });
  }
});

// Helper: extract the quoted globs from a rule's paths: frontmatter.
function rulePaths(file: string): string[] {
  const content = readFileSync(join(RULES_DIR, file), "utf8");
  const end = content.indexOf("\n---", 4);
  const fm = content.slice(4, end);
  return [...fm.matchAll(/^\s*-\s+["'](.+?)["']\s*$/gm)].map((m) => m[1]);
}

describe("rule glob collisions are explicit (RELIRE R4 — no accidental cross-rule overlap)", () => {
  // Globs intentionally shared between sibling DB rules (sql.md ⟷ database-design.md):
  // a .sql/migration/repository file legitimately triggers BOTH query-correctness and
  // schema constraints. Any NEW shared glob must be added here deliberately → forces review.
  const ALLOWED_SHARED = new Set([
    // sql.md ⟷ database-design.md: a .sql/migration/repository file triggers both
    // query-correctness and schema constraints.
    "**/*.sql", "**/migrations/**",
    "**/*repository*", "**/*Repository*", "**/*repositories*", "**/*Repositories*",
    // environments.md ⟷ github.md: a workflow file is both a GitHub-Actions surface
    // and a deployment-promotion surface. (Dedup vs cicd-pipeline.md is a deferred
    // design call — RELIRE R4 DEFER.)
    ".github/workflows/**",
  ]);

  it("every glob claimed by 2+ rules is in the allowlist", () => {
    const byGlob = new Map<string, string[]>();
    for (const file of readdirSync(RULES_DIR).filter((f) => f.endsWith(".md"))) {
      for (const g of rulePaths(file)) byGlob.set(g, [...(byGlob.get(g) ?? []), file]);
    }
    const violations: string[] = [];
    for (const [glob, files] of byGlob) {
      if (files.length > 1 && !ALLOWED_SHARED.has(glob)) violations.push(`${glob} ← ${files.join(", ")}`);
    }
    assert.deepEqual(violations, [], `unexpected cross-rule glob overlap:\n${violations.join("\n")}`);
  });

  it("event-driven.md no longer carries the firehose **/*handler* glob (RELIRE R1)", () => {
    assert.ok(!rulePaths("event-driven.md").includes("**/*handler*"), "**/*handler* over-matches React/Express handlers");
  });

  it("sql.md and database-design.md cover repository files in BOTH casings (RELIRE R2)", () => {
    for (const f of ["sql.md", "database-design.md"]) {
      const p = rulePaths(f);
      assert.ok(p.includes("**/*repository*") && p.includes("**/*Repository*"), `${f}: must match repository in both casings`);
    }
  });
});

describe("user-prompt-submit.sh — routing precision (RELIRE R3 guard)", () => {
  const UPS = join(HOOKS, "user-prompt-submit.sh");
  function route(prompt: string): string {
    const env = { ...process.env };
    delete env.CLAUDE_PROJECT_DIR;
    let out = "";
    try { out = execFileSync("bash", [UPS], { input: JSON.stringify({ prompt }), encoding: "utf8", env }); }
    catch (e: any) { out = String(e.stdout ?? ""); }
    try { return JSON.parse(out)?.hookSpecificOutput?.additionalContext ?? ""; } catch { return out; }
  }

  it("does NOT route caching on a benign 'store in the cache' prompt", () => {
    assert.ok(!route("implement code to store this in the cache").includes('Skill("caching")'));
  });
  it("DOES route caching on a real redis/caching prompt", () => {
    assert.ok(route("implement a redis caching layer").includes('Skill("caching")'));
  });
  it("does NOT route performance on 'optimize my react component layout'", () => {
    assert.ok(!route("write code to optimize my react component layout").includes('Skill("performance")'));
  });
  it("DOES route performance on a real latency/bottleneck prompt", () => {
    assert.ok(route("implement a fix for the p95 latency bottleneck").includes('Skill("performance")'));
  });
});

describe("universal defer-guard (prevents global+project double-fire)", () => {
  // Only PROJECT-WIRED hooks carry the guard. Guarding a shipped-but-unwired hook
  // would make a global instance defer to a project copy that never runs (RELIRE R1).
  const WIRED_HOOKS = [
    "block-destructive.sh", "check-dispatch-gate.sh", "pre-agent-gate.sh", "pre-tool-write.sh",
    "session-start.sh", "stop.sh", "track-file.sh", "track-verification.sh", "user-prompt-submit.sh",
  ];

  for (const h of WIRED_HOOKS) {
    it(`${h} carries the CIEL-DEFER-GUARD`, () => {
      assert.ok(readFileSync(join(HOOKS, h), "utf8").includes("CIEL-DEFER-GUARD"), `${h} is missing the defer-guard`);
    });
  }

  it("subagent-stop.sh is NOT guarded (shipped but not project-wired — RELIRE R1)", () => {
    assert.ok(!readFileSync(join(HOOKS, "subagent-stop.sh"), "utf8").includes("CIEL-DEFER-GUARD"),
      "guarding an unwired hook makes a global instance defer to a project copy that never runs");
  });

  it("every guarded hook is actually wired in the shipped settings.json (guarded ⟺ wired)", () => {
    const settings = JSON.parse(readFileSync(join(__dirname, "..", "assets", ".claude", "settings.json"), "utf8"));
    const wired = new Set<string>();
    for (const arr of Object.values<any>(settings.hooks ?? {})) {
      for (const w of arr) for (const hk of (w.hooks ?? [])) {
        for (const m of String(hk.command ?? "").match(/[a-z-]+\.sh/g) ?? []) wired.add(m);
      }
    }
    for (const h of WIRED_HOOKS) {
      assert.ok(wired.has(h), `${h} carries the guard but is not wired in assets/.claude/settings.json`);
    }
  });

  // Behavioral (track-file.sh — observable side effect). RELIRE R3: the project's
  // OWN instance must RUN even when CLAUDE_PROJECT_DIR is presented un-canonically
  // (trailing slash, or asymmetric symlink vs invocation path) — it must never self-defer.
  function deferCounts(setup: (realProj: string) => { envProjectDir: string; invokeDir: string }) {
    const realProj = mkdtempSync(join(tmpdir(), "ciel-proj-"));
    const globalDir = mkdtempSync(join(tmpdir(), "ciel-global-"));
    try {
      mkdirSync(join(realProj, ".claude", "hooks"), { recursive: true });
      mkdirSync(join(realProj, ".ciel"), { recursive: true });
      writeFileSync(join(realProj, ".ciel", "tracked-files.json"), "[]");
      const canonical = readFileSync(join(HOOKS, "track-file.sh"), "utf8");
      writeFileSync(join(realProj, ".claude", "hooks", "track-file.sh"), canonical);
      writeFileSync(join(globalDir, "track-file.sh"), canonical);
      const { envProjectDir, invokeDir } = setup(realProj);
      const env = { ...process.env, CLAUDE_PROJECT_DIR: envProjectDir };
      const input = JSON.stringify({ tool_input: { file_path: "src/x.ts" } });
      const count = () => JSON.parse(readFileSync(join(realProj, ".ciel", "tracked-files.json"), "utf8")).length;
      try { execFileSync("bash", [join(globalDir, "track-file.sh")], { input, encoding: "utf8", env }); } catch {}
      const afterGlobal = count();
      try { execFileSync("bash", [join(invokeDir, ".claude", "hooks", "track-file.sh")], { input, encoding: "utf8", env }); } catch {}
      return { afterGlobal, afterProject: count() };
    } finally {
      rmSync(realProj, { recursive: true, force: true });
      rmSync(globalDir, { recursive: true, force: true });
    }
  }

  it("clean path: global defers, project runs", { skip: !hasJq ? "jq not installed" : false }, () => {
    const { afterGlobal, afterProject } = deferCounts((p) => ({ envProjectDir: p, invokeDir: p }));
    assert.equal(afterGlobal, 0, "global must defer");
    assert.equal(afterProject, 1, "project must run");
  });

  it("trailing-slash CLAUDE_PROJECT_DIR: project still runs (RELIRE R3)", { skip: !hasJq ? "jq not installed" : false }, () => {
    const { afterProject } = deferCounts((p) => ({ envProjectDir: p + "/", invokeDir: p }));
    assert.equal(afterProject, 1, "project instance must RUN despite a trailing slash (must not self-defer)");
  });

  it("symlinked CLAUDE_PROJECT_DIR vs real invocation path: project still runs (RELIRE R3)", { skip: !hasJq ? "jq not installed" : false }, () => {
    const { afterProject } = deferCounts((p) => {
      const link = join(mkdtempSync(join(tmpdir(), "ciel-link-")), "proj");
      symlinkSync(p, link);
      return { envProjectDir: link, invokeDir: p }; // env uses symlink, invocation uses realpath
    });
    assert.equal(afterProject, 1, "project instance must RUN when CLAUDE_PROJECT_DIR is a symlink but invocation is the realpath");
  });
});
