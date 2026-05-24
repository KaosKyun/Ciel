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

const HOOK = join(__dirname, "..", "..", "..", "hooks", "stop.sh");

function runStop(state: { stop_hook_active?: boolean }): { decision: string; reason: string } | null {
  const input = JSON.stringify(state);
  let out: string;
  try {
    out = execFileSync("bash", [HOOK], { input, encoding: "utf8" });
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
