// memory-bootstrap — regression tests for the scan command.
// Locks in the behavior added in v6.9.3 that /ciel-memory-bootstrap also
// detects Claude Code auto-memory entries at ~/.claude/projects/<slug>/memory/,
// without which the Neiyomi incident user had no Ciel command to migrate
// their 10 auto-memory entries into the cued-recall corpus.

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const HOOK = join(__dirname, "..", "..", "..", "hooks", "memory-bootstrap.sh");

function scan(projectDir: string, autoMemoryDir?: string): string {
  const env: Record<string, string> = {
    ...process.env,
    CLAUDE_PROJECT_DIR: projectDir,
  };
  if (autoMemoryDir) env.CIEL_AUTO_MEMORY_DIR = autoMemoryDir;
  try {
    return execFileSync("bash", [HOOK, "scan"], { env, encoding: "utf8" });
  } catch (e: any) {
    return String(e.stdout ?? "") + String(e.stderr ?? "");
  }
}

function makeFixture(): { projectDir: string; autoMemDir: string; cleanup: () => void } {
  const root = join(tmpdir(), `ciel-bootstrap-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`);
  const projectDir = join(root, "project");
  const autoMemDir = join(root, "auto-memory");
  mkdirSync(projectDir, { recursive: true });
  mkdirSync(autoMemDir, { recursive: true });
  return { projectDir, autoMemDir, cleanup: () => rmSync(root, { recursive: true, force: true }) };
}

describe("memory-bootstrap.sh scan — Claude Code auto-memory detection", () => {
  it("detects auto-memory entries when CIEL_AUTO_MEMORY_DIR is set", () => {
    const { projectDir, autoMemDir, cleanup } = makeFixture();
    writeFileSync(join(autoMemDir, "feedback_one.md"), "---\nname: f1\ndescription: foo\n---\nbody");
    writeFileSync(join(autoMemDir, "project_two.md"), "---\nname: p2\ndescription: bar\n---\nbody");

    const out = scan(projectDir, autoMemDir);

    assert.match(out, /Claude Code auto-memory entries/, "must mention auto-memory in scan output");
    assert.match(out, /\(2 Claude Code auto-memory entries/, "must report count = 2");
    assert.ok(out.includes(autoMemDir), "must surface the resolved auto-memory dir");
    cleanup();
  });

  it("excludes MEMORY.md (the index file) from the count", () => {
    // The auto-memory MEMORY.md is just a TOC and would inflate the count
    // without representing migratable content.
    const { projectDir, autoMemDir, cleanup } = makeFixture();
    writeFileSync(join(autoMemDir, "MEMORY.md"), "# Index\n- [link](feedback_one.md)");
    writeFileSync(join(autoMemDir, "feedback_one.md"), "---\nname: f1\n---\n");

    const out = scan(projectDir, autoMemDir);

    assert.match(out, /\(1 Claude Code auto-memory entries/, "MEMORY.md must not be counted; only 1 real entry");
    cleanup();
  });

  it("stays silent when the auto-memory dir has only MEMORY.md (no real entries)", () => {
    const { projectDir, autoMemDir, cleanup } = makeFixture();
    writeFileSync(join(autoMemDir, "MEMORY.md"), "# Index");
    // No other files.

    const out = scan(projectDir, autoMemDir);

    assert.doesNotMatch(out, /Claude Code auto-memory entries/, "no row for auto-memory when there's nothing to migrate");
    assert.match(out, /No ingestable sources found/, "should report empty result");
    cleanup();
  });

  it("stays silent when the auto-memory dir does not exist", () => {
    const { projectDir, autoMemDir, cleanup } = makeFixture();
    rmSync(autoMemDir, { recursive: true, force: true });

    const out = scan(projectDir, autoMemDir);

    assert.doesNotMatch(out, /Claude Code auto-memory/, "no false-positive when the dir is absent");
    cleanup();
  });

  it("derives the default slug from cwd when CIEL_AUTO_MEMORY_DIR is unset", () => {
    // Use a synthetic project path under the user's $HOME with a matching
    // auto-memory dir created by hand. Verifies the sed-based slug derivation.
    const home = process.env.HOME!;
    const projectDir = join(tmpdir(), `ciel-slug-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`);
    mkdirSync(projectDir, { recursive: true });
    // Slug: cwd with `/` replaced by `-` — same logic as the script
    const slug = projectDir.replace(/\//g, "-");
    const autoMemDir = join(home, ".claude", "projects", slug, "memory");
    mkdirSync(autoMemDir, { recursive: true });
    writeFileSync(join(autoMemDir, "feedback_slug.md"), "---\nname: fs\n---\n");

    // Don't pass CIEL_AUTO_MEMORY_DIR — force the script to derive the slug itself.
    const env: Record<string, string> = { ...process.env, CLAUDE_PROJECT_DIR: projectDir };
    delete env.CIEL_AUTO_MEMORY_DIR;
    const out = execFileSync("bash", [HOOK, "scan"], { env, encoding: "utf8" });

    assert.match(out, /\(1 Claude Code auto-memory entries/, "default slug derivation must locate the dir");

    rmSync(projectDir, { recursive: true, force: true });
    rmSync(autoMemDir, { recursive: true, force: true });
  });
});

describe("memory-bootstrap.sh scan — existing behavior preserved", () => {
  it("still finds .claude/rules/ entries (regression-free)", () => {
    const { projectDir, cleanup } = makeFixture();
    const rulesDir = join(projectDir, ".claude", "rules");
    mkdirSync(rulesDir, { recursive: true });
    writeFileSync(join(rulesDir, "testing.md"), "## Testing rules");
    writeFileSync(join(rulesDir, "deploy.md"), "## Deploy rules");

    // No auto-memory dir for this test — pass a non-existent path to suppress that branch.
    const out = scan(projectDir, "/nonexistent/auto-memory");

    assert.match(out, /\(2 rule files\)/, "rules count must include both rule files");
    cleanup();
  });
});
