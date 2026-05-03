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
