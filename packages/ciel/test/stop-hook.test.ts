// stop-hook — regression tests for stop.sh v9.
// Verifies the 4-gate thin-shell: stop hook delivers 3 META reflection
// questions and respects the "block once per session" guard.
//
// Strategy: shell out to bash with stdin JSON, capture stdout JSON,
// assert decision and reason. Exercises the real hook, not a mock.

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { join } from "node:path";
import { mkdtempSync, mkdirSync, writeFileSync, utimesSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";

const HOOK = join(__dirname, "..", "..", "..", "hooks", "stop.sh");

function runStopRaw(
  state: { stop_hook_active?: boolean },
  env: NodeJS.ProcessEnv,
): { decision: string; reason: string } | null {
  let out: string;
  try {
    out = execFileSync("bash", [HOOK], { input: JSON.stringify(state), encoding: "utf8", env });
  } catch (e: any) {
    out = String(e.stdout ?? "");
  }
  if (!out.trim()) return null;
  try {
    return JSON.parse(out.trim());
  } catch {
    return null;
  }
}

// Default runner: isolate from the verification gate by removing the project dir,
// so these tests exercise only the META-reflection path.
function runStop(state: { stop_hook_active?: boolean }): { decision: string; reason: string } | null {
  const env = { ...process.env };
  delete env.CLAUDE_PROJECT_DIR;
  return runStopRaw(state, env);
}

// Build a throwaway project whose .ciel markers encode whether code was edited
// after the last verification. mtimes are set 10s apart so bash `-nt` is reliable.
function makeProject(opts: { codeEdit?: number; verification?: number }): string {
  const dir = mkdtempSync(join(tmpdir(), "ciel-stop-"));
  mkdirSync(join(dir, ".ciel"), { recursive: true });
  const base = Math.floor(Date.now() / 1000);
  if (opts.verification !== undefined) {
    const f = join(dir, ".ciel", "last-verification");
    writeFileSync(f, "ts\n");
    utimesSync(f, base + opts.verification, base + opts.verification);
  }
  if (opts.codeEdit !== undefined) {
    const f = join(dir, ".ciel", "last-code-edit");
    writeFileSync(f, "ts\n");
    utimesSync(f, base + opts.codeEdit, base + opts.codeEdit);
  }
  return dir;
}

describe("stop.sh — v9 META reflection", () => {
  it("outputs decision:block when stop_hook_active is false", () => {
    const result = runStop({ stop_hook_active: false });
    assert.ok(result, "expected JSON output when stop_hook_active is false");
    assert.equal(result!.decision, "block");
  });

  it("outputs decision:block when stop_hook_active is absent", () => {
    const result = runStop({});
    assert.ok(result, "expected JSON output when key is absent");
    assert.equal(result!.decision, "block");
  });

  it("reason contains the 3 META reflection questions", () => {
    const result = runStop({ stop_hook_active: false });
    assert.ok(result, "expected JSON output");
    assert.ok(result!.reason.includes("Qu'ai-je manque"));
    assert.ok(result!.reason.includes("Quelle decision ou decouverte"));
    assert.ok(result!.reason.includes("Si je devais refaire"));
  });

  it("does NOT block again when stop_hook_active is true", () => {
    const result = runStop({ stop_hook_active: true });
    assert.strictEqual(result, null, "expected no output when already blocked once");
  });

  it("handles non-JSON input gracefully (no block)", () => {
    let out = "";
    try {
      out = execFileSync("bash", [HOOK], { input: "not-json", encoding: "utf8" });
    } catch (e: any) {
      out = String(e.stdout ?? "");
    }
    const trimmed = out.trim();
    if (trimmed) {
      const parsed = JSON.parse(trimmed);
      assert.equal(parsed.decision, "block");
    }
    // If no output, that's fine too — the hook handled the bad input gracefully.
  });
});

describe("stop.sh — verification gate (autonomy keystone)", () => {
  function runInProject(dir: string, state: { stop_hook_active?: boolean }) {
    const env = { ...process.env, CLAUDE_PROJECT_DIR: dir };
    return runStopRaw(state, env);
  }

  it("blocks with VERIFICATION GATE when code was edited after last verification", () => {
    const dir = makeProject({ verification: 0, codeEdit: 10 }); // edit newer than verif
    try {
      const result = runInProject(dir, { stop_hook_active: false });
      assert.ok(result, "expected block output");
      assert.equal(result!.decision, "block");
      assert.ok(result!.reason.includes("VERIFICATION GATE"), "expected verification clause");
      assert.ok(result!.reason.includes("Qu'ai-je manque"), "META questions still present");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("blocks with VERIFICATION GATE when code edited but never verified", () => {
    const dir = makeProject({ codeEdit: 0 }); // no last-verification at all
    try {
      const result = runInProject(dir, { stop_hook_active: false });
      assert.ok(result, "expected block output");
      assert.ok(result!.reason.includes("VERIFICATION GATE"), "missing verif ⇒ gate fires");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("does NOT add the verification clause when verification is newer than the edit", () => {
    const dir = makeProject({ codeEdit: 0, verification: 10 }); // verified after edit
    try {
      const result = runInProject(dir, { stop_hook_active: false });
      assert.ok(result, "still blocks once for META");
      assert.ok(!result!.reason.includes("VERIFICATION GATE"), "verified ⇒ no clause");
      assert.ok(result!.reason.includes("Qu'ai-je manque"), "META still present");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("does NOT add the verification clause when no code was edited", () => {
    const dir = makeProject({}); // no markers at all
    try {
      const result = runInProject(dir, { stop_hook_active: false });
      assert.ok(result, "still blocks once for META");
      assert.ok(!result!.reason.includes("VERIFICATION GATE"), "no edit ⇒ no clause");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });

  it("never blocks twice (stop_hook_active short-circuits the gate)", () => {
    const dir = makeProject({ codeEdit: 10, verification: 0 }); // would block if active=false
    try {
      const result = runInProject(dir, { stop_hook_active: true });
      assert.strictEqual(result, null, "stop_hook_active=true ⇒ allow, no loop");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
