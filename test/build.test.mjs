// Ciel build — levier A increment 1.
// Asserts: src/skills/ is the canonical flat-domain source, and scripts/build.mjs
// regenerates the harness skill mirrors byte-identical to src. RED before src/ +
// build.mjs exist; GREEN once they do.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SRC_SKILLS = join(ROOT, "src", "skills");
const BUILD = join(ROOT, "scripts", "build.mjs");
const SKILL_MIRRORS = [".claude/skills", ".opencode/skills"];

// Relative paths of every SKILL.md / reference.md under dir, sorted.
function walkSkills(dir) {
  const out = [];
  (function rec(d, base) {
    for (const e of readdirSync(d).sort()) {
      const p = join(d, e);
      if (statSync(p).isDirectory()) rec(p, base ? join(base, e) : e);
      else if (e === "SKILL.md" || e === "reference.md") out.push(base ? join(base, e) : e);
    }
  })(dir, "");
  return out.sort();
}

test("src/skills/ is the canonical flat-domain source (>=99 skills)", () => {
  assert.ok(existsSync(SRC_SKILLS), "src/skills/ must exist");
  const skills = walkSkills(SRC_SKILLS).filter((p) => p.endsWith("SKILL.md"));
  assert.ok(skills.length >= 99, `expected >=99 canonical skills, got ${skills.length}`);
});

// Content-freshness canary. The `ciel` skill drifted across mirrors: some carry
// the stale v6 "Pipeline 16 etapes" body, the v9 source is "thin shell". Seeding
// from a stale mirror silently regresses the live skill — byte-identity alone
// won't catch it, so assert the canonical content is the v9 one.
test("canonical ciel skill is the v9 thin-shell, not the stale v6 pipeline", () => {
  const body = readFileSync(join(SRC_SKILLS, "ciel", "SKILL.md"), "utf8");
  assert.match(body, /thin shell/i, "ciel skill must be the v9 thin-shell body");
  assert.doesNotMatch(body, /Pipeline 16 etapes/i, "ciel skill must not be the stale v6 pipeline body");
});

test("build.mjs regenerates harness mirrors byte-identical to src/skills", () => {
  assert.ok(existsSync(BUILD), "scripts/build.mjs must exist");
  execFileSync("node", [BUILD], { cwd: ROOT, stdio: "pipe" });

  const srcFiles = walkSkills(SRC_SKILLS);
  for (const mirror of SKILL_MIRRORS) {
    const mdir = join(ROOT, mirror);
    assert.ok(existsSync(mdir), `${mirror} must exist after build`);
    for (const rel of srcFiles) {
      const mp = join(mdir, rel);
      assert.ok(existsSync(mp), `${mirror}/${rel} missing after build`);
      assert.equal(
        readFileSync(mp, "utf8"),
        readFileSync(join(SRC_SKILLS, rel), "utf8"),
        `${mirror}/${rel} differs from canonical src`,
      );
    }
  }
});

// Generic recursive lister, excluding python build junk that must never be mirrored.
function walkFiles(dir) {
  const out = [];
  const skip = new Set(["__pycache__"]);
  (function rec(d, base) {
    for (const e of readdirSync(d).sort()) {
      if (skip.has(e) || e.endsWith(".pyc") || e === ".DS_Store") continue;
      const p = join(d, e);
      if (statSync(p).isDirectory()) rec(p, base ? join(base, e) : e);
      else out.push(base ? join(base, e) : e);
    }
  })(dir, "");
  return out.sort();
}

// Build runs, then target must equal src exactly (same files, same bytes).
function assertMirror(srcSub, target) {
  const sdir = join(ROOT, srcSub);
  assert.ok(existsSync(sdir), `${srcSub} must exist`);
  execFileSync("node", [BUILD], { cwd: ROOT, stdio: "pipe" });
  const tdir = join(ROOT, target);
  assert.ok(existsSync(tdir), `${target} must exist after build`);
  const srcFiles = walkFiles(sdir);
  assert.deepEqual(
    walkFiles(tdir),
    srcFiles,
    `${target} file set differs from ${srcSub}`,
  );
  for (const rel of srcFiles) {
    const sp = join(sdir, rel);
    const tp = join(tdir, rel);
    assert.deepEqual(
      readFileSync(tp),
      readFileSync(sp),
      `${target}/${rel} differs from canonical ${srcSub}`,
    );
    // Executable bit must match the source — a naive writeFileSync mirror drops
    // it (0644), leaving hooks non-executable and the harness fails to run them.
    assert.equal(
      statSync(tp).mode & 0o111,
      statSync(sp).mode & 0o111,
      `${target}/${rel} exec-bit differs from canonical ${srcSub}`,
    );
  }
}

test("build mirrors src/hooks → .claude/hooks byte-faithful", () => {
  assertMirror("src/hooks", ".claude/hooks");
});

test("build mirrors src/rules → .claude/rules byte-faithful", () => {
  assertMirror("src/rules", ".claude/rules");
});

