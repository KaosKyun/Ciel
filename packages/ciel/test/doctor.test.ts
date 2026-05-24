// doctor command — health check tests
// Verifies: hooks, memory index, assets, rules categories all scored.

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { existsSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { runDoctor } from "../src/cli/doctor";

function setupTempProject(withMemory = false): string {
  const dir = join(tmpdir(), `ciel-doctor-test-${Date.now()}`);
  mkdirSync(join(dir, ".claude", "hooks"), { recursive: true });
  mkdirSync(join(dir, ".claude", "rules"), { recursive: true });
  mkdirSync(join(dir, ".ciel", "memory"), { recursive: true });
  // Write a valid memory index
  if (withMemory) {
    writeFileSync(
      join(dir, ".ciel", "memory", "index.json"),
      JSON.stringify({
        version: 2,
        memories: { mem_x: { id: "mem_x", title: "Test" } },
        by_symbol: { auth: ["mem_x"] },
        by_path: {},
        by_intent: {},
        by_language: {},
      })
    );
  }
  // Write a rule
  writeFileSync(join(dir, ".claude", "rules", "test.md"), "---\npaths:\n  - test\n---\n# Test rule");
  return dir;
}

describe("ciel doctor", () => {
  it("returns a score between 0 and 100", () => {
    const dir = setupTempProject(true);
    const result = runDoctor(dir);
    assert.ok(result.score >= 0 && result.score <= 100, `score ${result.score} should be 0-100`);
    rmSync(dir, { recursive: true, force: true });
  });

  it("returns all 4 categories", () => {
    const dir = setupTempProject(true);
    const result = runDoctor(dir);
    for (const cat of ["hooks", "memory", "assets", "rules"]) {
      assert.ok(cat in result, `should have ${cat} category`);
      assert.ok("ok" in result[cat], `${cat} should have ok`);
      assert.ok("detail" in result[cat], `${cat} should have detail`);
      assert.ok(typeof result[cat].score === "number", `${cat} score should be number`);
    }
    rmSync(dir, { recursive: true, force: true });
  });

  it("reports missing hooks directory as unhealthy", () => {
    const dir = setupTempProject(true);
    rmSync(join(dir, ".claude", "hooks"), { recursive: true, force: true });
    const result = runDoctor(dir);
    assert.equal(result.hooks.ok, false);
    assert.ok(result.score < 100, "score should be < 100 with missing hooks");
    rmSync(dir, { recursive: true, force: true });
  });

  it("reports index with orphans as unhealthy", () => {
    const dir = setupTempProject(false);
    writeFileSync(
      join(dir, ".ciel", "memory", "index.json"),
      JSON.stringify({
        version: 2,
        memories: { mem_good: { id: "mem_good" } },
        by_symbol: { auth: ["mem_good", "mem_orphan"] },
        by_path: {},
        by_intent: {},
        by_language: {},
      })
    );
    const result = runDoctor(dir);
    assert.equal(result.memory.ok, false);
    assert.ok(result.memory.detail.includes("orphan"), "detail should mention orphan");
    rmSync(dir, { recursive: true, force: true });
  });

  it("reports index with empty keys as unhealthy", () => {
    const dir = setupTempProject(false);
    writeFileSync(
      join(dir, ".ciel", "memory", "index.json"),
      JSON.stringify({
        version: 2,
        memories: { mem_good: { id: "mem_good" } },
        by_symbol: { stale: [] },
        by_path: {},
        by_intent: {},
        by_language: {},
      })
    );
    const result = runDoctor(dir);
    assert.equal(result.memory.ok, false);
    assert.ok(result.memory.detail.includes("empty"), "detail should mention empty keys");
    rmSync(dir, { recursive: true, force: true });
  });

  it("reports valid index as healthy", () => {
    const dir = setupTempProject(true);
    const result = runDoctor(dir);
    assert.equal(result.memory.ok, true);
    assert.equal(result.memory.score, 25);
    rmSync(dir, { recursive: true, force: true });
  });

  it("reports missing rules directory", () => {
    const dir = setupTempProject(true);
    rmSync(join(dir, ".claude", "rules"), { recursive: true, force: true });
    const result = runDoctor(dir);
    assert.equal(result.rules.ok, false);
    rmSync(dir, { recursive: true, force: true });
  });

  it("sum of category scores equals total score", () => {
    const dir = setupTempProject(true);
    const result = runDoctor(dir);
    const catSum = result.hooks.score + result.memory.score + result.assets.score + result.rules.score;
    assert.equal(result.score, Math.min(100, catSum));
    rmSync(dir, { recursive: true, force: true });
  });
});
