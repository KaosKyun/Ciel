// Ciel `ciel memory save` — stdin write path.
// The CLI read stdin via a synchronous process.stdin.read() loop that returns
// null before data is buffered, so piped content was lost ("No content on
// stdin"). This integration test pipes a body to the real binary and asserts
// the memory is persisted. RED against the buggy dist, GREEN after the fix
// (readFileSync(0)) + rebuild.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, existsSync, readdirSync, mkdirSync, copyFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const BIN = join(ROOT, "packages", "ciel", "bin", "ciel.js");
const ENGINE = join(ROOT, "hooks", "memory-engine.py");

test("ciel memory save reads the body from stdin and persists a memory", () => {
  const proj = mkdtempSync(join(tmpdir(), "ciel-memsave-"));
  try {
    // The CLI resolves memory-engine.py at <cwd>/.claude/hooks/ — give the
    // fixture project a copy, then init the empty memory structure.
    mkdirSync(join(proj, ".claude", "hooks"), { recursive: true });
    copyFileSync(ENGINE, join(proj, ".claude", "hooks", "memory-engine.py"));
    execFileSync("python3", [ENGINE, "init", "--cwd", proj], { stdio: "pipe" });

    const out = execFileSync(
      "node",
      [BIN, "memory", "save", "--cwd=" + proj, "--title", "stdin smoke test", "--intents", "test"],
      { input: "BODY FROM STDIN\n", encoding: "utf8" },
    );
    assert.match(out, /Memory saved/, `expected save confirmation, got: ${out}`);

    let files = [];
    for (const sub of ["episodes", "guards", "concepts"]) {
      const d = join(proj, ".ciel", "memory", sub);
      if (existsSync(d)) files = files.concat(readdirSync(d));
    }
    assert.ok(
      files.some((f) => f.endsWith(".md")),
      `expected a persisted memory file, got: ${JSON.stringify(files)}`,
    );
  } finally {
    rmSync(proj, { recursive: true, force: true });
  }
});
