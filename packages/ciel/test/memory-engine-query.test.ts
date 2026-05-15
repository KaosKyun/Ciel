// memory-engine query — regression tests for case-insensitive cue matching.
// Reproduces the v6.10.1 bug: a memory tagged `symbols: [OkHttp]` or with
// a free-form intent `[okhttp]` did not fire on natural-language prompts
// mentioning "okhttp" in lowercase. score_memory's matching was strict
// exact-string against extracted cues that preserve case + use a fixed
// vocabulary for intents.

import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const ENGINE = join(__dirname, "..", "..", "..", "hooks", "memory-engine.py");

interface FixtureMemory {
  id: string;
  title: string;
  languages?: string[];
  path_patterns?: string[];
  symbols?: string[];
  intents?: string[];
  captured_at?: string;
  trigger_count?: number;
  last_triggered?: string | null;
  stale?: boolean;
  stale_after_days?: number;
}

function makeCorpus(memories: FixtureMemory[]): string {
  const dir = join(tmpdir(), `ciel-engine-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`);
  mkdirSync(join(dir, ".ciel", "memory", "episodes"), { recursive: true });
  mkdirSync(join(dir, ".ciel", "memory", "concepts"), { recursive: true });
  mkdirSync(join(dir, ".ciel", "memory", "guards"), { recursive: true });

  const idx: Record<string, unknown> = {
    version: 2,
    memories: {},
    by_path: {},
    by_symbol: {},
    by_intent: {},
    by_language: {},
  };
  const memMap = idx.memories as Record<string, FixtureMemory>;
  for (const m of memories) {
    memMap[m.id] = {
      captured_at: "2026-05-01T00:00:00Z",
      trigger_count: 0,
      last_triggered: null,
      stale: false,
      stale_after_days: 90,
      ...m,
    };
  }
  writeFileSync(join(dir, ".ciel", "memory", "index.json"), JSON.stringify(idx, null, 2));
  return dir;
}

function query(corpusDir: string, prompt: string): string {
  try {
    return execFileSync("python3", [ENGINE, "query", "--prompt", prompt, "--cwd", corpusDir, "--depth", "standard"], { encoding: "utf8" });
  } catch (e: any) {
    return String(e.stdout ?? "") + String(e.stderr ?? "");
  }
}

describe("memory-engine query — case-insensitive symbol matching", () => {
  it("PascalCase symbol memory fires on lowercase prompt mention", () => {
    // Bug repro: memory tagged symbols: [OkHttp] never fired when the user
    // typed "the okhttp cookiejar override" because score_memory did exact
    // case-sensitive `sym in symbols` and extract_symbol_cues never produced
    // "okhttp" (no case transitions in pure lowercase).
    const dir = makeCorpus([
      { id: "mem_okhttp", title: "OkHttp cookiejar override", symbols: ["OkHttp", "PersistentCookieJar"] },
    ]);
    const out = query(dir, "the okhttp cookiejar override is a Neiyomi-specific quirk");
    assert.match(out, /mem_okhttp/, "memory must fire on lowercase 'okhttp' for PascalCase symbol [OkHttp]");
    rmSync(dir, { recursive: true, force: true });
  });

  it("snake_case symbol still matches exactly (regression-free)", () => {
    const dir = makeCorpus([
      { id: "mem_snake", title: "user_admin table semantics", symbols: ["user_admin"] },
    ]);
    const out = query(dir, "fix migration on user_admin table");
    assert.match(out, /mem_snake/, "snake_case symbol must still match");
    rmSync(dir, { recursive: true, force: true });
  });

  it("PascalCase symbol still matches PascalCase mention", () => {
    const dir = makeCorpus([
      { id: "mem_pascal", title: "PersistentCookieJar override", symbols: ["PersistentCookieJar"] },
    ]);
    const out = query(dir, "PersistentCookieJar fires before BridgeInterceptor");
    assert.match(out, /mem_pascal/, "PascalCase mention must still match PascalCase symbol");
    rmSync(dir, { recursive: true, force: true });
  });
});

describe("memory-engine query — free-form intent matching against prompt words", () => {
  it("memory with free-form intent tag fires on word-boundary match in prompt", () => {
    // Bug repro: memory tagged intents: [okhttp] never fired because
    // extract_intent_cues only produces labels from the hardcoded
    // INTENT_KEYWORDS list — "okhttp" was never produced as an intent label.
    const dir = makeCorpus([
      { id: "mem_intent", title: "okhttp diagnostics", intents: ["okhttp", "diagnostics"] },
    ]);
    const out = query(dir, "investigate okhttp network behavior");
    assert.match(out, /mem_intent/, "free-form intent 'okhttp' must match prompt word 'okhttp'");
    rmSync(dir, { recursive: true, force: true });
  });

  it("word-boundary prevents 'test' intent from firing on 'contest'", () => {
    // Without word boundaries, intent "test" would fire on "contest" or
    // "protest", polluting recall. Verify boundaries hold.
    const dir = makeCorpus([
      { id: "mem_test", title: "test intent guard", intents: ["test"] },
    ]);
    const out = query(dir, "the contest protest happened yesterday");
    assert.doesNotMatch(out, /mem_test/, "intent 'test' must NOT fire on 'contest'/'protest' (word boundary required)");
    rmSync(dir, { recursive: true, force: true });
  });

  it("fixed-vocabulary intent (e.g. schema-change via 'migration') still works", () => {
    // INTENT_KEYWORDS['migration'] → label 'schema-change'. Memory tagged
    // intents: [schema-change] should still fire on prompts mentioning
    // "migration", per the pre-existing label-based path.
    const dir = makeCorpus([
      { id: "mem_schema", title: "schema migration semantics", intents: ["schema-change"] },
    ]);
    const out = query(dir, "preparing the migration for the users table");
    assert.match(out, /mem_schema/, "INTENT_KEYWORDS-derived intent label must still match");
    rmSync(dir, { recursive: true, force: true });
  });
});

describe("memory-engine query — guards preserved", () => {
  it("language gate still excludes mismatched-language memories", () => {
    const dir = makeCorpus([
      { id: "mem_kotlin", title: "Kotlin-only", languages: ["kotlin"], symbols: ["okhttp"] },
    ]);
    const out = query(dir, "the okhttp interceptor in src/foo.ts");
    assert.doesNotMatch(out, /mem_kotlin/, "Kotlin memory must NOT fire on TypeScript prompt (language gate)");
    rmSync(dir, { recursive: true, force: true });
  });

  it("memory with zero cue match is excluded (no free recall)", () => {
    const dir = makeCorpus([
      { id: "mem_unrelated", title: "Stripe payment flow", symbols: ["StripeCheckout"], intents: ["payment"] },
    ]);
    const out = query(dir, "rebuild the test pyramid for vitest");
    assert.doesNotMatch(out, /mem_unrelated/, "memory with no cue match must NOT fire");
    rmSync(dir, { recursive: true, force: true });
  });
});
