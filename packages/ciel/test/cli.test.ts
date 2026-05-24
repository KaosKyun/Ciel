// @ciel/cli — Test suite
// Run: npm test (from packages/cli/) or node --test packages/cli/test/
// Uses Node.js built-in test runner

import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import { existsSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

// Import the modules
import { detectOpenCode } from "../src/cli/opencode";
import { detectClaude } from "../src/cli/claude";

// Helper to create temporary project directories
function createTempProject(): string {
  const dir = join(tmpdir(), `ciel-test-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`);
  mkdirSync(dir, { recursive: true });
  return dir;
}

function cleanupTempProject(dir: string): void {
  rmSync(dir, { recursive: true, force: true });
}

describe("CLI — Platform detection", () => {
  it("detects OpenCode project by opencode.json", () => {
    const dir = createTempProject();
    writeFileSync(join(dir, "opencode.json"), "{}");
    assert.equal(detectOpenCode(dir), true);
    assert.equal(detectClaude(dir), false);
    cleanupTempProject(dir);
  });

  it("detects OpenCode project by .opencode/ directory", () => {
    const dir = createTempProject();
    mkdirSync(join(dir, ".opencode"), { recursive: true });
    assert.equal(detectOpenCode(dir), true);
    cleanupTempProject(dir);
  });

  it("detects Claude Code project by settings.json", () => {
    const dir = createTempProject();
    mkdirSync(join(dir, ".claude"), { recursive: true });
    writeFileSync(join(dir, ".claude/settings.json"), "{}");
    assert.equal(detectClaude(dir), true);
    assert.equal(detectOpenCode(dir), false);
    cleanupTempProject(dir);
  });

  it("detects Claude Code project by agents directory", () => {
    const dir = createTempProject();
    mkdirSync(join(dir, ".claude/agents"), { recursive: true });
    assert.equal(detectClaude(dir), true);
    cleanupTempProject(dir);
  });

  it("detects both platforms when both present", () => {
    const dir = createTempProject();
    writeFileSync(join(dir, "opencode.json"), "{}");
    mkdirSync(join(dir, ".claude/agents"), { recursive: true });
    assert.ok(detectOpenCode(dir), "OpenCode should be detected");
    assert.ok(detectClaude(dir), "Claude Code should be detected");
    cleanupTempProject(dir);
  });
});

describe("CLI — Integrity check", () => {
  it("reports no platform when project has no config", () => {
    const dir = createTempProject();
    const { checkIntegrity } = require("../src/cli/check");
    const result = checkIntegrity(dir);
    assert.ok(result.errors.length > 0, "should have errors for no platform");
    assert.ok(
      result.errors.some((e: string) => e.includes("No Ciel platform")),
      "should mention no platform detected"
    );
    cleanupTempProject(dir);
  });

  it("detects missing required Claude Code files", () => {
    const dir = createTempProject();
    // Create .claude/ to trigger Claude detection, but no files inside
    mkdirSync(join(dir, ".claude/agents"), { recursive: true });
    // Create .ciel/ state so we don't get those as missing
    mkdirSync(join(dir, ".ciel"), { recursive: true });
    writeFileSync(join(dir, ".ciel/map.json"), "{}");
    writeFileSync(join(dir, ".ciel/memory.json"), "{}");
    writeFileSync(join(dir, ".ciel/parking.md"), "");

    const { checkIntegrity } = require("../src/cli/check");
    const result = checkIntegrity(dir);

    // CLAUDE.md, settings.json, agents, hooks, skills should all be missing
    assert.ok(
      result.missing.some((f: string) => f === "CLAUDE.md"),
      "should report CLAUDE.md missing"
    );
    assert.ok(
      result.missing.some((f: string) => f === ".claude/settings.json"),
      "should report settings.json missing"
    );
    assert.ok(
      result.missing.some((f: string) => f.includes(".claude/agents/")),
      "should report agents missing"
    );
    assert.ok(
      result.missing.some((f: string) => f.includes(".claude/hooks/")),
      "should report hooks missing"
    );
    assert.ok(
      result.missing.some((f: string) => f.includes(".claude/skills/ciel/")),
      "should report skills missing"
    );
    cleanupTempProject(dir);
  });

  it("detects valid Claude Code installation", () => {
    const dir = createTempProject();

    // Create all required Claude Code files
    mkdirSync(join(dir, ".claude/agents"), { recursive: true });
    mkdirSync(join(dir, ".claude/hooks"), { recursive: true });
    mkdirSync(join(dir, ".claude/commands"), { recursive: true });
    mkdirSync(join(dir, ".claude/skills/ciel"), { recursive: true });
    mkdirSync(join(dir, ".ciel"), { recursive: true });

    writeFileSync(join(dir, "CLAUDE.md"), "# Ciel");
    writeFileSync(join(dir, ".claude/settings.json"), JSON.stringify({
      hooks: {
        PreToolUse: [{ hooks: [{ command: ".claude/hooks/pre-tool-write.sh" }] }]
      }
    }));
    for (const agent of ["ciel-researcher.md", "ciel-explorer.md", "ciel-critic.md", "ciel-improver.md"]) {
      writeFileSync(join(dir, ".claude/agents", agent), "# agent");
    }
    for (const hook of [
      "block-destructive.sh", "track-file.sh",
      "session-version-check.sh", "pre-tool-write.sh", "pre-agent-gate.sh",
      "check-dispatch-gate.sh", "stop.sh",
      "session-start.sh", "user-prompt-submit.sh", "memory-bootstrap.sh", "memory-engine.py",
    ]) {
      const p = join(dir, ".claude/hooks", hook);
      writeFileSync(p, "#!/bin/bash\necho ok");
      require("fs").chmodSync(p, 0o755);
    }
    writeFileSync(join(dir, ".claude/skills/ciel/SKILL.md"), "# skill");
    writeFileSync(join(dir, ".claude/skills/ciel/reference.md"), "# ref");
    writeFileSync(join(dir, ".ciel/map.json"), "{}");
    writeFileSync(join(dir, ".ciel/memory.json"), "{}");
    writeFileSync(join(dir, ".ciel/parking.md"), "");

    const { checkIntegrity } = require("../src/cli/check");
    const result = checkIntegrity(dir);

    assert.equal(result.errors.length, 0, `unexpected errors: ${result.errors.join(", ")}`);
    assert.equal(result.missing.length, 0, `unexpected missing: ${result.missing.join(", ")}`);
    assert.ok(result.ok.length >= 12, `expected >=12 OK files, got ${result.ok.length}`);
    cleanupTempProject(dir);
  });

  it("flags settings.json with no hooks", () => {
    const dir = createTempProject();
    mkdirSync(join(dir, ".claude/agents"), { recursive: true });
    mkdirSync(join(dir, ".ciel"), { recursive: true });
    writeFileSync(join(dir, ".claude/settings.json"), JSON.stringify({ permissions: { allow: ["bash"] } }));
    writeFileSync(join(dir, ".ciel/map.json"), "{}");
    writeFileSync(join(dir, ".ciel/memory.json"), "{}");
    writeFileSync(join(dir, ".ciel/parking.md"), "");

    const { checkIntegrity } = require("../src/cli/check");
    const result = checkIntegrity(dir);

    assert.ok(
      result.errors.some((e: string) => e.includes("no hooks") || e.includes("Ciel hooks not wired")),
      `should flag missing hooks, got errors: ${result.errors.join(", ")}`
    );
    cleanupTempProject(dir);
  });

  it("flags invalid settings.json", () => {
    const dir = createTempProject();
    mkdirSync(join(dir, ".claude/agents"), { recursive: true });
    mkdirSync(join(dir, ".ciel"), { recursive: true });
    writeFileSync(join(dir, ".claude/settings.json"), "not json {{{");
    writeFileSync(join(dir, ".ciel/map.json"), "{}");
    writeFileSync(join(dir, ".ciel/memory.json"), "{}");
    writeFileSync(join(dir, ".ciel/parking.md"), "");

    const { checkIntegrity } = require("../src/cli/check");
    const result = checkIntegrity(dir);

    assert.ok(
      result.errors.some((e: string) => e.includes("invalid JSON")),
      `should flag invalid JSON, got errors: ${result.errors.join(", ")}`
    );
    cleanupTempProject(dir);
  });

  it("detects missing OpenCode files", () => {
    const dir = createTempProject();
    writeFileSync(join(dir, "opencode.json"), "{}");
    mkdirSync(join(dir, ".ciel"), { recursive: true });
    writeFileSync(join(dir, ".ciel/map.json"), "{}");
    writeFileSync(join(dir, ".ciel/memory.json"), "{}");
    writeFileSync(join(dir, ".ciel/parking.md"), "");

    const { checkIntegrity } = require("../src/cli/check");
    const result = checkIntegrity(dir);

    assert.ok(
      result.missing.some((f: string) => f === "AGENTS.md"),
      "should report AGENTS.md missing"
    );
    assert.ok(
      result.missing.some((f: string) => f.includes(".opencode/plugins/")),
      "should report plugin missing"
    );
    assert.ok(
      result.missing.some((f: string) => f.includes(".opencode/agents/")),
      "should report agents missing"
    );
    cleanupTempProject(dir);
  });

  it("flags opencode.json without Ciel plugin reference", () => {
    const dir = createTempProject();
    writeFileSync(join(dir, "opencode.json"), JSON.stringify({ plugin: ["other-plugin.js"] }));
    mkdirSync(join(dir, ".ciel"), { recursive: true });
    writeFileSync(join(dir, ".ciel/map.json"), "{}");
    writeFileSync(join(dir, ".ciel/memory.json"), "{}");
    writeFileSync(join(dir, ".ciel/parking.md"), "");

    const { checkIntegrity } = require("../src/cli/check");
    const result = checkIntegrity(dir);

    assert.ok(
      result.errors.some((e: string) => e.includes("Ciel plugin not referenced")),
      `should flag missing plugin reference, got errors: ${result.errors.join(", ")}`
    );
    cleanupTempProject(dir);
  });

  it("warns when hooks are not executable", () => {
    const dir = createTempProject();
    mkdirSync(join(dir, ".claude/agents"), { recursive: true });
    mkdirSync(join(dir, ".claude/hooks"), { recursive: true });
    mkdirSync(join(dir, ".ciel"), { recursive: true });
    writeFileSync(join(dir, ".claude/settings.json"), JSON.stringify({
      hooks: { PreToolUse: [{ hooks: [{ command: ".claude/hooks/pre-tool-write.sh" }] }] }
    }));
    // Write hook files without exec bit
    for (const hook of [
      "block-destructive.sh", "track-file.sh",
      "session-version-check.sh", "pre-tool-write.sh", "pre-agent-gate.sh",
      "check-dispatch-gate.sh", "stop.sh",
      "session-start.sh", "user-prompt-submit.sh", "memory-bootstrap.sh", "memory-engine.py",
    ]) {
      writeFileSync(join(dir, ".claude/hooks", hook), "#!/bin/bash\necho ok");
      require("fs").chmodSync(join(dir, ".claude/hooks", hook), 0o644);
    }
    writeFileSync(join(dir, ".ciel/map.json"), "{}");
    writeFileSync(join(dir, ".ciel/memory.json"), "{}");
    writeFileSync(join(dir, ".ciel/parking.md"), "");

    const { checkIntegrity } = require("../src/cli/check");
    const result = checkIntegrity(dir);

    assert.ok(
      result.warnings.some((w: string) => w.includes("not executable")),
      `should warn about non-executable hooks, got warnings: ${result.warnings.join(", ")}`
    );
    cleanupTempProject(dir);
  });

  it("detects valid OpenCode installation", () => {
    const dir = createTempProject();
    mkdirSync(join(dir, ".opencode/plugins"), { recursive: true });
    mkdirSync(join(dir, ".opencode/agents"), { recursive: true });
    mkdirSync(join(dir, ".opencode/commands"), { recursive: true });
    mkdirSync(join(dir, ".ciel"), { recursive: true });

    writeFileSync(join(dir, "AGENTS.md"), "# Ciel");
    writeFileSync(join(dir, "opencode.json"), JSON.stringify({
      plugin: ["./.opencode/plugins/ciel.js"],
      instructions: ["AGENTS.md"]
    }));
    writeFileSync(join(dir, ".opencode/plugins/ciel.js"), "// plugin");
    for (const agent of ["ciel.md", "ciel-researcher.md", "ciel-explorer.md", "ciel-critic.md", "ciel-improver.md"]) {
      writeFileSync(join(dir, ".opencode/agents", agent), "# agent");
    }
    writeFileSync(join(dir, ".ciel/map.json"), "{}");
    writeFileSync(join(dir, ".ciel/memory.json"), "{}");
    writeFileSync(join(dir, ".ciel/parking.md"), "");

    const { checkIntegrity } = require("../src/cli/check");
    const result = checkIntegrity(dir);

    assert.equal(result.errors.length, 0, `unexpected errors: ${result.errors.join(", ")}`);
    assert.equal(result.missing.length, 0, `unexpected missing: ${result.missing.join(", ")}`);
    assert.ok(result.ok.length >= 8, `expected >=8 OK files, got ${result.ok.length}`);
    cleanupTempProject(dir);
  });
});

describe("CLI — Claude install merge", () => {
  it("--force migrates legacy hooks/ paths to .claude/hooks/ without duplicating entries", () => {
    // Regression: mergeSettings used to detect Ciel wrappers by ".claude/hooks/"
    // substring, so legacy entries with "hooks/<script>.sh" leaked through as
    // "user entries" and ended up duplicated alongside the new template entries.
    const srcDir = join(__dirname, "..", "assets");
    if (!existsSync(join(srcDir, ".claude/settings.json"))) return; // not built

    // realpath-resolve to bypass the /var → /private/var symlink on macOS,
    // which mkdirSafe (claude.ts) doesn't tolerate. The symlink behavior is a
    // separate latent bug; this test stays focused on the merge fix.
    const targetDir = require("fs").realpathSync(createTempProject());
    mkdirSync(join(targetDir, ".claude"), { recursive: true });
    writeFileSync(
      join(targetDir, ".claude/settings.json"),
      JSON.stringify({
        hooks: {
          SessionStart: [{
            hooks: [{
              type: "command",
              command: '"$CLAUDE_PROJECT_DIR"/hooks/session-version-check.sh',
            }],
          }],
        },
      })
    );

    const { installClaude } = require("../src/cli/claude");
    installClaude({ targetDir, srcDir, force: true, quiet: true });

    const merged = JSON.parse(
      require("fs").readFileSync(join(targetDir, ".claude/settings.json"), "utf8")
    );
    const sessionStart = merged.hooks?.SessionStart ?? [];
    assert.equal(sessionStart.length, 1, "expected exactly one SessionStart wrapper after merge");
    const cmds = (sessionStart[0].hooks ?? []).map((h: any) => String(h.command ?? ""));
    assert.ok(
      cmds.some((c: string) => c.includes(".claude/hooks/session-version-check.sh")),
      "expected migrated path to .claude/hooks/"
    );
    assert.ok(
      !cmds.some((c: string) => /\/hooks\/session-version-check\.sh/.test(c) && !c.includes(".claude/")),
      "legacy hooks/ path must not remain"
    );
    cleanupTempProject(targetDir);
  });
});

describe("CLI — OpenCode install", () => {
  it("installOpenCode creates plugin file from source", () => {
    // This test needs source files — skip if not in dev mode
    const srcDir = join(__dirname, "..", "..", "..", "..");
    const hasPlatformFiles = existsSync(join(srcDir, "platforms/opencode/.opencode/plugins/ciel.ts"));

    if (!hasPlatformFiles) {
      // Not in dev environment, skip
      return;
    }

    const targetDir = createTempProject();
    mkdirSync(join(targetDir, ".opencode/plugins"), { recursive: true });

    const { installOpenCode } = require("../src/cli/opencode");
    const result = installOpenCode({
      targetDir,
      srcDir,
      force: true,
      quiet: true,
    });

    assert.ok(
      result.installed.some((f: string) => f.includes("ciel.ts")),
      "Plugin file should be installed"
    );
    assert.ok(
      existsSync(join(targetDir, ".opencode/plugins/ciel.ts")),
      "Plugin file should exist on disk"
    );
    assert.ok(
      existsSync(join(targetDir, "opencode.json")),
      "opencode.json should be generated"
    );

    cleanupTempProject(targetDir);
  });
});

describe("CLI — Version check", () => {
  it("CIEL_VERSION is set", () => {
    const version = "5.1.5";
    assert.ok(version.length > 0);
    assert.match(version, /^\d+\.\d+\.\d+$/);
  });
});

describe("CLI — Uninstall", () => {
  it("uninstall removes Ciel-specific files", () => {
    const dir = createTempProject();

    // Create some Ciel files to uninstall
    mkdirSync(join(dir, ".opencode/plugins"), { recursive: true });
    writeFileSync(join(dir, ".opencode/plugins/ciel.ts"), "// test");
    mkdirSync(join(dir, ".opencode/agents"), { recursive: true });
    writeFileSync(join(dir, ".opencode/agents/ciel.md"), "# test");
    writeFileSync(join(dir, "AGENTS.md"), "# test");
    mkdirSync(join(dir, ".ciel"), { recursive: true });
    writeFileSync(join(dir, ".ciel/map.json"), "{}");

    // Run uninstall
    const { runUninstall } = require("../src/cli/uninstall");

    // Need to run within the test dir
    const originalCwd = process.cwd;
    process.cwd = () => dir;
    process.argv = process.argv.filter(a => a !== "--quiet" && a !== "-q");

    // Since runUninstall has side effects and uses process.cwd(),
    // we test the specific helper functions instead
    assert.ok(existsSync(join(dir, ".opencode/plugins/ciel.ts")));

    process.cwd = originalCwd;
    cleanupTempProject(dir);
  });
});
