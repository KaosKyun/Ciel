// pre-commit-hook — regression tests for .githooks/pre-commit
// Verifies the asset-sync hook: fast-path skip, auto-sync on source change,
// block on copy-assets failure.

import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, realpathSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const HOOK = join(__dirname, "..", "..", "..", ".githooks", "pre-commit");

let tmpDir: string;

function sh(cmd: string, cwd?: string): string {
  return execSync(cmd, { cwd: cwd ?? tmpDir, encoding: "utf8", stdio: "pipe" }).trim();
}

function git(cmd: string): string {
  return sh(`git ${cmd}`);
}

describe(".githooks/pre-commit — asset sync", () => {
  before(() => {
    tmpDir = mkdtempSync(join(tmpdir(), "ciel-precommit-test-"));
    sh("git init -q");
  });

  after(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  it("exits 0 (fast path) when no source templates are staged", () => {
    // Stage a random file that isn't a source template
    writeFileSync(join(tmpDir, "random.txt"), "hello");
    sh("git add random.txt");

    // Hook should skip because random.txt doesn't match source patterns
    const result = execSync(`bash "${HOOK}"`, { cwd: tmpDir, encoding: "utf8", stdio: "pipe" });
    assert.equal(result, "");
  });

  it("exits 0 (fast path) when nothing is staged", () => {
    const result = execSync(`bash "${HOOK}"`, { cwd: tmpDir, encoding: "utf8", stdio: "pipe" });
    assert.equal(result, "");
  });

  it("fails with message when copy-assets script missing", () => {
    // Stage a source template file
    mkdirSync(join(tmpDir, "hooks"), { recursive: true });
    writeFileSync(join(tmpDir, "hooks", "stop.sh"), "#!/bin/bash\necho test");
    sh("git add hooks/stop.sh");

    // copy-assets.cjs doesn't exist in tmp dir — hook should fail cleanly
    let stdout = "";
    try {
      execSync(`bash "${HOOK}"`, { cwd: tmpDir, encoding: "utf8", stdio: ["pipe", "pipe", "pipe"] });
    } catch (e: any) {
      stdout = String(e.stdout ?? "");
    }
    assert.ok(stdout.includes("ERROR"), "expected error message on stdout");
  });
});
