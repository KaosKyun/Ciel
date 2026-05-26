// Ciel consistency doctor — levier A.
// Fixture-based: drives checkVersions / checkMirrors on temp dirs so drift can
// be injected without mutating the real repo. RED before scripts/doctor.mjs.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { checkVersions, checkMirrors } from "../scripts/doctor.mjs";

function fixture() {
  const dir = mkdtempSync(join(tmpdir(), "ciel-doctor-"));
  return {
    dir,
    write(rel, content) {
      const p = join(dir, rel);
      mkdirSync(join(p, ".."), { recursive: true });
      writeFileSync(p, content);
    },
    cleanup() {
      rmSync(dir, { recursive: true, force: true });
    },
  };
}

test("checkVersions passes when all version files match VERSION", () => {
  const f = fixture();
  try {
    f.write("VERSION", "6.15.5\n");
    f.write("package.json", JSON.stringify({ version: "6.15.5" }));
    f.write("packages/ciel/package.json", JSON.stringify({ version: "6.15.5" }));
    f.write("packages/ciel/.ciel/version", "6.15.5");
    assert.deepEqual(checkVersions(f.dir), []);
  } finally {
    f.cleanup();
  }
});

test("checkVersions reports every file that drifts from VERSION", () => {
  const f = fixture();
  try {
    f.write("VERSION", "6.15.5\n");
    f.write("package.json", JSON.stringify({ version: "6.14.1" }));
    f.write("packages/ciel/package.json", JSON.stringify({ version: "6.15.5" }));
    f.write("packages/ciel/.ciel/version", "6.13.1");
    const failures = checkVersions(f.dir);
    assert.equal(failures.length, 2, `expected 2 drifts, got ${failures.length}: ${failures}`);
  } finally {
    f.cleanup();
  }
});

test("checkMirrors passes when target equals canonical source", () => {
  const f = fixture();
  try {
    f.write("src/rules/security.md", "rule body\n");
    f.write(".claude/rules/security.md", "rule body\n");
    assert.deepEqual(checkMirrors(f.dir, [{ src: "src/rules", targets: [".claude/rules"] }]), []);
  } finally {
    f.cleanup();
  }
});

test("checkMirrors detects a hand-edited / stale / missing target file", () => {
  const f = fixture();
  try {
    f.write("src/rules/security.md", "canonical body\n");
    f.write(".claude/rules/security.md", "EDITED BY HAND\n"); // content drift
    f.write(".claude/rules/orphan.md", "stale\n"); // not in src
    const failures = checkMirrors(f.dir, [{ src: "src/rules", targets: [".claude/rules"] }]);
    assert.ok(failures.length >= 2, `expected drift+orphan, got: ${failures}`);
  } finally {
    f.cleanup();
  }
});
