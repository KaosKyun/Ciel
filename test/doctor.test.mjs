// Ciel consistency doctor — levier A.
// Fixture-based: drives checkVersions / checkMirrors on temp dirs so drift can
// be injected without mutating the real repo. RED before scripts/doctor.mjs.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { checkVersions, checkMirrors, checkLabels } from "../scripts/doctor.mjs";

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

test("checkVersions catches drift in ALL release-please-managed files", () => {
  // Regression guard: plugin.json + marketplace.json (×2 fields) + install.sh
  // silently drifted (6.14.1 / 6.13.0) while VERSION was 6.16.0 because the
  // doctor only tracked 3 files. The doctor's set must equal release-please's.
  const f = fixture();
  try {
    f.write("VERSION", "6.16.0\n");
    f.write("package.json", JSON.stringify({ version: "6.16.0" }));
    f.write("packages/ciel/package.json", JSON.stringify({ version: "6.16.0" }));
    f.write(".claude-plugin/plugin.json", JSON.stringify({ version: "6.14.1" })); // drift
    f.write(
      ".claude-plugin/marketplace.json",
      JSON.stringify({ version: "6.14.1", plugins: [{ version: "6.13.0" }] }), // 2 drifts
    );
    f.write(
      "scripts/install.sh",
      'CIEL_VERSION="6.13.0" # x-release-please-version\nURL="${CIEL_VERSION}"\n', // 1 drift (marker line)
    );
    const failures = checkVersions(f.dir);
    assert.equal(failures.length, 4, `expected 4 drifts, got ${failures.length}: ${failures.join(" | ")}`);
    assert.ok(failures.some((x) => x.includes("plugin.json")), "must flag plugin.json");
    assert.ok(failures.some((x) => x.includes("plugins[0]")), "must flag marketplace plugins[0].version");
    assert.ok(failures.some((x) => x.includes("install.sh")), "must flag install.sh");
  } finally {
    f.cleanup();
  }
});

test("checkVersions reads install.sh from the x-release-please-version marker line only", () => {
  // release-please's generic updater bumps ONLY the marked line; ${CIEL_VERSION}
  // interpolations and stray version literals must NOT be read as drift.
  const f = fixture();
  try {
    f.write("VERSION", "6.16.0\n");
    f.write(
      "scripts/install.sh",
      'CIEL_VERSION="6.16.0" # x-release-please-version\nRAW="https://example/v6.13.0/${CIEL_VERSION}"\n',
    );
    assert.deepEqual(checkVersions(f.dir), [], "marker line matches VERSION → no drift despite unmarked 6.13.0");
  } finally {
    f.cleanup();
  }
});

test("checkVersions passes when the full release-please set matches VERSION", () => {
  const f = fixture();
  try {
    f.write("VERSION", "6.16.0\n");
    f.write("package.json", JSON.stringify({ version: "6.16.0" }));
    f.write("packages/ciel/package.json", JSON.stringify({ version: "6.16.0" }));
    f.write("packages/ciel/.ciel/version", "6.16.0");
    f.write(".claude-plugin/plugin.json", JSON.stringify({ version: "6.16.0" }));
    f.write(
      ".claude-plugin/marketplace.json",
      JSON.stringify({ version: "6.16.0", plugins: [{ version: "6.16.0" }] }),
    );
    f.write("scripts/install.sh", 'CIEL_VERSION="6.16.0" # x-release-please-version\n');
    f.write(".github/.release-please-manifest.json", JSON.stringify({ ".": "6.16.0" }));
    assert.deepEqual(checkVersions(f.dir), []);
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

test("checkLabels flags stale v5/v7/v8 generation labels in src/, passes when clean", () => {
  const f = fixture();
  try {
    f.write("src/skills/x/SKILL.md", "# X\nUsed in Ciel v5 pipeline.\n");
    assert.equal(checkLabels(f.dir).length, 1, "must flag a Ciel v5 label");
    f.write("src/skills/x/SKILL.md", "# X\nA standalone Ciel technique.\n");
    assert.deepEqual(checkLabels(f.dir), [], "clean src must produce no label findings");
  } finally {
    f.cleanup();
  }
});
