// merge-settings — regression tests for the settings.json merge logic.
// Reproduces three risks identified in the v6.9.x RELIRE on the Neiyomi
// memory-routing incident:
//   1. autoMemoryEnabled must be propagated from template on --force.
//   2. Legacy Ciel hook basenames must be evicted on --force.
//   3. User-owned custom hooks with non-Ciel basenames must be preserved.
// Each test arranges a worst-case existing settings.json, runs the merge, and
// asserts the post-merge shape — behavior-level, no implementation coupling.

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

import {
  mergeSettings,
  CIEL_HOOK_FILES,
  CIEL_LEGACY_HOOK_FILES,
  CIEL_OWNED_SETTINGS_KEYS,
} from "../src/cli/claude";

function makeFixture(existing: object, template: object): { existingPath: string; templatePath: string; cleanup: () => void } {
  const dir = join(tmpdir(), `ciel-merge-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`);
  mkdirSync(dir, { recursive: true });
  const existingPath = join(dir, "existing.json");
  const templatePath = join(dir, "template.json");
  writeFileSync(existingPath, JSON.stringify(existing));
  writeFileSync(templatePath, JSON.stringify(template));
  return { existingPath, templatePath, cleanup: () => rmSync(dir, { recursive: true, force: true }) };
}

describe("mergeSettings — Ciel-owned top-level keys", () => {
  it("overwrites autoMemoryEnabled from template when user has it enabled", () => {
    // RISK 3 reproduction: a user with autoMemoryEnabled: true would keep
    // that value forever without this propagation.
    const { existingPath, templatePath, cleanup } = makeFixture(
      { autoMemoryEnabled: true, permissions: { allow: ["Bash(ls)"] } },
      { autoMemoryEnabled: false, hooks: {} },
    );
    const merged = mergeSettings(existingPath, templatePath) as Record<string, unknown>;
    assert.equal(merged.autoMemoryEnabled, false, "template autoMemoryEnabled must overwrite existing");
    assert.deepEqual(merged.permissions, { allow: ["Bash(ls)"] }, "non-owned keys must be preserved from existing");
    cleanup();
  });

  it("propagates autoMemoryEnabled even when existing settings has no such key", () => {
    const { existingPath, templatePath, cleanup } = makeFixture(
      { permissions: {} },
      { autoMemoryEnabled: false, hooks: {} },
    );
    const merged = mergeSettings(existingPath, templatePath) as Record<string, unknown>;
    assert.equal(merged.autoMemoryEnabled, false);
    cleanup();
  });

  it("leaves non-Ciel-owned keys untouched even when template specifies them", () => {
    const { existingPath, templatePath, cleanup } = makeFixture(
      { customKey: "user-value", autoMemoryEnabled: true },
      { customKey: "template-value", autoMemoryEnabled: false, hooks: {} },
    );
    const merged = mergeSettings(existingPath, templatePath) as Record<string, unknown>;
    assert.equal(merged.customKey, "user-value", "non-owned key must come from existing, not template");
    assert.equal(merged.autoMemoryEnabled, false, "owned key still propagates");
    cleanup();
  });

  it("CIEL_OWNED_SETTINGS_KEYS exposes autoMemoryEnabled (lockdown test)", () => {
    // Lockdown: if someone removes autoMemoryEnabled from the owned-keys list,
    // this test fails and forces a deliberate review of the consequence.
    assert.ok(
      (CIEL_OWNED_SETTINGS_KEYS as readonly string[]).includes("autoMemoryEnabled"),
      "autoMemoryEnabled must remain in CIEL_OWNED_SETTINGS_KEYS",
    );
  });
});

describe("mergeSettings — hook eviction", () => {
  const cielHookEvent = (basename: string) => ({
    matcher: "Edit|Write",
    hooks: [{ type: "command", command: `"$CLAUDE_PROJECT_DIR"/.claude/hooks/${basename}` }],
  });
  const userHookEvent = (path: string) => ({
    matcher: "Edit|Write",
    hooks: [{ type: "command", command: `bash ${path}` }],
  });

  it("evicts legacy Ciel hooks (pre-write-gate.sh, post-write-relire.sh) on merge", () => {
    // RISK from CHANGELOG.md: users with v2.x settings.json carry references
    // to renamed hooks. The merge must drop these so they don't fail at runtime.
    const { existingPath, templatePath, cleanup } = makeFixture(
      {
        hooks: {
          PreToolUse: [
            cielHookEvent("pre-write-gate.sh"),     // legacy — must be evicted
            cielHookEvent("post-write-relire.sh"),  // legacy — must be evicted
          ],
        },
      },
      {
        hooks: {
          PreToolUse: [cielHookEvent("pre-tool-write.sh")],
        },
      },
    );
    const merged = mergeSettings(existingPath, templatePath) as Record<string, unknown>;
    const preToolUse = (merged.hooks as Record<string, unknown[]>).PreToolUse as Array<Record<string, unknown>>;
    const commands = preToolUse.flatMap((e) => (e.hooks as Array<Record<string, string>>).map((h) => h.command));
    assert.equal(commands.length, 1, "only the template entry survives");
    assert.ok(commands[0].includes("pre-tool-write.sh"), "template hook is present");
    assert.ok(!commands.some((c) => c.includes("pre-write-gate.sh")), "legacy hook is evicted");
    assert.ok(!commands.some((c) => c.includes("post-write-relire.sh")), "legacy hook is evicted");
    cleanup();
  });

  it("preserves user custom hooks with non-Ciel basenames (e.g. post-edit-check.sh)", () => {
    // RISK 2 reproduction: post-edit-check.sh is documented as a user-owned
    // custom hook basename. Adding it to CIEL_HOOK_FILES would silently delete
    // it on --force upgrade. This test locks in that we do NOT own it.
    const userPath = "/opt/Neiyomi/scripts/hooks/post-edit-check.sh";
    const { existingPath, templatePath, cleanup } = makeFixture(
      {
        hooks: {
          PostToolUse: [
            cielHookEvent("track-file.sh"),  // Ciel — will be replaced by template
            userHookEvent(userPath),         // user — must survive
          ],
        },
      },
      {
        hooks: {
          PostToolUse: [cielHookEvent("track-file.sh")],
        },
      },
    );
    const merged = mergeSettings(existingPath, templatePath) as Record<string, unknown>;
    const postToolUse = (merged.hooks as Record<string, unknown[]>).PostToolUse as Array<Record<string, unknown>>;
    const commands = postToolUse.flatMap((e) => (e.hooks as Array<Record<string, string>>).map((h) => h.command));
    assert.ok(commands.some((c) => c === `bash ${userPath}`), "user's post-edit-check.sh must be preserved");
    assert.ok(commands.some((c) => c.includes("track-file.sh")), "Ciel track-file.sh from template");
  cleanup();
  });

  it("CIEL_LEGACY_HOOK_FILES does NOT contain user-owned basenames", () => {
    // Lockdown: ensures nobody re-adds post-edit-check.sh to the legacy list.
    // If someone does, data loss on --force upgrade for users with that custom
    // hook — and this test fails to flag the regression.
    const forbidden = ["post-edit-check.sh"];
    for (const name of forbidden) {
      assert.ok(
        !(CIEL_LEGACY_HOOK_FILES as readonly string[]).includes(name),
        `${name} must NOT be in CIEL_LEGACY_HOOK_FILES — it is a user-owned basename`,
      );
      assert.ok(
        !(CIEL_HOOK_FILES as readonly string[]).includes(name),
        `${name} must NOT be in CIEL_HOOK_FILES — it has never been a Ciel-shipped hook`,
      );
    }
  });
});

describe("mergeSettings — robustness", () => {
  it("returns null when existing settings.json is invalid JSON", () => {
    const dir = join(tmpdir(), `ciel-merge-bad-${Date.now()}`);
    mkdirSync(dir, { recursive: true });
    const existingPath = join(dir, "bad.json");
    const templatePath = join(dir, "template.json");
    writeFileSync(existingPath, "{ not json");
    writeFileSync(templatePath, JSON.stringify({ autoMemoryEnabled: false }));
    assert.equal(mergeSettings(existingPath, templatePath), null);
    rmSync(dir, { recursive: true, force: true });
  });
});
