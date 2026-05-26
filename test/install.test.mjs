// Ciel `ciel init` install — skills land in the target project.
// Slice B unifies the two installers onto one src-derived asset tree
// (packages/ciel/assets/skills). This integration test runs the real binary
// headless into a temp project and asserts the discoverable skill set ships —
// including environments/github/research, which the old flat-52 tree carried
// and the canonical src/ must not drop.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const BIN = join(ROOT, "packages", "ciel", "bin", "ciel.js");

test("legacy root skills/ tree is removed — src/skills is the only source", () => {
  assert.ok(
    !existsSync(join(ROOT, "skills")),
    "root skills/ must be deleted; all readers now point at src/skills",
  );
});

test("ciel init -y installs the canonical skill set into the project", () => {
  const proj = mkdtempSync(join(tmpdir(), "ciel-init-"));
  // Mark as a Claude Code project so installClaude runs.
  execFileSync("node", ["-e", "require('fs').mkdirSync('.claude',{recursive:true})"], { cwd: proj });

  execFileSync("node", [BIN, "init", "-y", "--quiet"], { cwd: proj, stdio: "pipe" });

  const skillsDir = join(proj, ".claude", "skills");
  assert.ok(existsSync(skillsDir), ".claude/skills must exist after init");
  // Domain skills + the three that only lived in the old flat tree (regression guard).
  for (const s of ["api-design", "backend", "environments", "github", "research", "ciel"]) {
    assert.ok(
      existsSync(join(skillsDir, s, "SKILL.md")),
      `init must install .claude/skills/${s}/SKILL.md`,
    );
  }
});
