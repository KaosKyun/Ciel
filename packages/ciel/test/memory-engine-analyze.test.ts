// memory-engine analyze — pattern-mining + memory-health tests.
//
// Covers the new `analyze` subcommand that scans .ciel/memory/index.json
// and produces .ciel/memory/INSIGHTS.md (human) + .ciel/memory/insights.json
// (machine, consumed by ciel-audit Dim 10).
//
// Behaviors under test:
//   - Output files are created on every run.
//   - Episodes with trigger_count >= 5 surface as promotion candidates.
//   - Episodes whose path_patterns resolve to no file surface as dead anchors.
//   - Intent clusters respect a min_support floor of 3.
//   - 7 health metrics are emitted in insights.json.
//
// Each test is self-contained (DAMP) — the corpus fixture is rebuilt per case.

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync, readFileSync, rmSync } from "node:fs";
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
  file?: string; // override default "episodes/<id>.md"
}

function makeCorpus(memories: FixtureMemory[]): string {
  const dir = join(tmpdir(), `ciel-engine-analyze-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`);
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
      file: m.file ?? `episodes/${m.id}.md`,
      ...m,
    };
    for (const p of m.path_patterns ?? []) (idx.by_path as Record<string, string[]>)[p] ??= [], (idx.by_path as Record<string, string[]>)[p].push(m.id);
    for (const s of m.symbols ?? []) (idx.by_symbol as Record<string, string[]>)[s] ??= [], (idx.by_symbol as Record<string, string[]>)[s].push(m.id);
    for (const i of m.intents ?? []) (idx.by_intent as Record<string, string[]>)[i] ??= [], (idx.by_intent as Record<string, string[]>)[i].push(m.id);
    for (const l of m.languages ?? []) (idx.by_language as Record<string, string[]>)[l] ??= [], (idx.by_language as Record<string, string[]>)[l].push(m.id);
  }
  writeFileSync(join(dir, ".ciel", "memory", "index.json"), JSON.stringify(idx, null, 2));
  return dir;
}

function analyze(corpusDir: string): { stdout: string; insightsJson: any; insightsMd: string } {
  const stdout = execFileSync("python3", [ENGINE, "analyze", "--cwd", corpusDir], { encoding: "utf8" });
  const insightsJson = JSON.parse(readFileSync(join(corpusDir, ".ciel", "memory", "insights.json"), "utf8"));
  const insightsMd = readFileSync(join(corpusDir, ".ciel", "memory", "INSIGHTS.md"), "utf8");
  return { stdout, insightsJson, insightsMd };
}

describe("memory-engine analyze — output files", () => {
  it("creates insights.json and INSIGHTS.md even on an empty corpus", () => {
    const dir = makeCorpus([]);
    const result = analyze(dir);
    assert.ok(result.insightsJson, "insights.json must parse as JSON");
    assert.ok(result.insightsMd.length > 0, "INSIGHTS.md must be written and non-empty");
    rmSync(dir, { recursive: true, force: true });
  });
});

describe("memory-engine analyze — promotion candidates", () => {
  it("lists an episode with trigger_count >= 5 as a promotion candidate", () => {
    const dir = makeCorpus([
      { id: "mem_hot", title: "Always check stderr in PreToolUse hooks", intents: ["hook"], trigger_count: 7 },
    ]);
    const result = analyze(dir);
    assert.ok(
      Array.isArray(result.insightsJson.promotion_candidates) &&
        result.insightsJson.promotion_candidates.includes("mem_hot"),
      "trigger_count=7 episode must surface as promotion candidate",
    );
    rmSync(dir, { recursive: true, force: true });
  });

  it("does not list an episode with trigger_count below 5", () => {
    const dir = makeCorpus([
      { id: "mem_cold", title: "Cold memory", intents: ["hook"], trigger_count: 2 },
    ]);
    const result = analyze(dir);
    const candidates = result.insightsJson.promotion_candidates ?? [];
    assert.ok(!candidates.includes("mem_cold"), "trigger_count=2 must not be a promotion candidate (threshold is 5)");
    rmSync(dir, { recursive: true, force: true });
  });
});

describe("memory-engine analyze — dead anchors", () => {
  it("flags a memory whose path_patterns resolve to no file", () => {
    const dir = makeCorpus([
      {
        id: "mem_dead",
        title: "References a deleted module",
        path_patterns: ["src/legacy/deleted-module-xyz.ts"],
        intents: ["legacy"],
      },
    ]);
    const result = analyze(dir);
    const dead = result.insightsJson.dead_anchors ?? [];
    assert.ok(dead.includes("mem_dead"), "memory whose every path_pattern resolves to nothing must be a dead anchor");
    rmSync(dir, { recursive: true, force: true });
  });

  it("does not flag a memory whose path_patterns resolve to existing files", () => {
    const dir = makeCorpus([
      {
        id: "mem_alive",
        title: "References the index file (which exists in the corpus dir)",
        path_patterns: [".ciel/memory/index.json"],
        intents: ["memory-system"],
      },
    ]);
    const result = analyze(dir);
    const dead = result.insightsJson.dead_anchors ?? [];
    assert.ok(!dead.includes("mem_alive"), "memory pointing to an existing file must NOT be flagged dead");
    rmSync(dir, { recursive: true, force: true });
  });
});

describe("memory-engine analyze — absolute path patterns (Python 3.13+ NotImplementedError repro)", () => {
  it("does not crash when a memory carries an absolute path that does not exist", () => {
    // Bug repro: Path.glob raises NotImplementedError for absolute patterns on
    // Python 3.13+, which the original try/except (ValueError, OSError) did not
    // catch — the analyzer crashed before writing insights.json.
    const dir = makeCorpus([
      { id: "mem_abs_dead", title: "absolute pattern to nowhere",
        path_patterns: ["/tmp/ciel-definitely-does-not-exist-xyz-99999"], intents: ["legacy"] },
    ]);
    const result = analyze(dir); // must not throw
    assert.ok(result.insightsJson.dead_anchors.includes("mem_abs_dead"),
      "absolute path that resolves to nothing must be flagged as dead anchor (and not crash the engine)");
    rmSync(dir, { recursive: true, force: true });
  });

  it("does not flag a memory whose absolute path exists", () => {
    // /tmp exists on macOS/Linux. The engine must recognise an existing
    // absolute path even though Path.glob can't handle absolute patterns.
    const dir = makeCorpus([
      { id: "mem_abs_alive", title: "absolute pattern to /tmp",
        path_patterns: ["/tmp"], intents: ["fs"] },
    ]);
    const result = analyze(dir);
    const dead = result.insightsJson.dead_anchors ?? [];
    assert.ok(!dead.includes("mem_abs_alive"), "absolute path that exists must NOT be flagged dead");
    rmSync(dir, { recursive: true, force: true });
  });
});

describe("memory-engine analyze — health metrics", () => {
  it("emits the 7 documented health dimensions in insights.json", () => {
    const dir = makeCorpus([
      { id: "mem_a", title: "A", intents: ["install"] },
      { id: "mem_b", title: "B", intents: ["install"] },
      { id: "mem_c", title: "C", intents: ["testing"] },
    ]);
    const result = analyze(dir);
    const h = result.insightsJson.health;
    assert.ok(h, "insights.json must include a 'health' object");
    for (const key of [
      "recency_30d_ratio",
      "intent_diversity_entropy",
      "dead_anchor_ratio",
      "max_generation_depth",
      "tag_specificity",
      "promotion_ratio",
      "capture_correction_ratio",
    ]) {
      assert.ok(key in h, `health metric '${key}' must be present in insights.json.health`);
    }
    rmSync(dir, { recursive: true, force: true });
  });
});

describe("memory-engine analyze — INSIGHTS.md cap on large corpus", () => {
  it("does not cap a small corpus (<= 150 memories)", () => {
    // 5 promotion candidates with corpus size 5 → all listed, no "more" footer.
    const memories = [];
    for (let i = 0; i < 5; i++) {
      memories.push({ id: `mem_small_${i}`, title: `small-${i}`, intents: ["hook"], trigger_count: 7 });
    }
    const dir = makeCorpus(memories);
    const result = analyze(dir);
    assert.equal(result.insightsJson.corpus_size.total, 5, "fixture corpus has 5 memories");
    assert.ok(!/more, see insights\.json/.test(result.insightsMd),
      "small corpus must not emit a '+N more' footer");
    for (let i = 0; i < 5; i++) {
      assert.ok(result.insightsMd.includes(`mem_small_${i}`),
        `small-corpus INSIGHTS.md must list every promotion candidate (missing mem_small_${i})`);
    }
    rmSync(dir, { recursive: true, force: true });
  });

  it("caps each section at top-10 with a '+N more' footer when corpus > 150", () => {
    // 200 promotion candidates → only top 10 listed in INSIGHTS.md, but
    // insights.json keeps all 200.
    const memories = [];
    for (let i = 0; i < 200; i++) {
      memories.push({
        id: `mem_large_${String(i).padStart(3, "0")}`,
        title: `large-${i}`,
        intents: ["hook"],
        // All entries above the promotion threshold (5); mem_large_000 ranks highest.
        trigger_count: 205 - i,
      });
    }
    const dir = makeCorpus(memories);
    const result = analyze(dir);
    assert.equal(result.insightsJson.corpus_size.total, 200, "fixture has 200 memories");
    assert.equal(result.insightsJson.promotion_candidates.length, 200,
      "insights.json keeps all 200 candidates (machine consumer is uncapped)");

    const promotionSection = result.insightsMd.split("## Promotion candidates")[1] ?? "";
    const candidateLines = (promotionSection.match(/^- `mem_large_/gm) ?? []).length;
    assert.equal(candidateLines, 10, "INSIGHTS.md must cap promotion candidates at top 10 when corpus > 150");
    assert.match(result.insightsMd, /\+\d+ more, see insights\.json/,
      "INSIGHTS.md must emit a '+N more, see insights.json' footer when capping");
    assert.ok(result.insightsMd.includes("mem_large_000"),
      "highest-support entry (mem_large_000) must be in the top-10 slice");
    rmSync(dir, { recursive: true, force: true });
  });
});

describe("memory-engine analyze — min-support floor", () => {
  it("does not emit an intent cluster supported by fewer than 3 episodes", () => {
    const dir = makeCorpus([
      { id: "mem_x", title: "X", intents: ["rare-intent"] },
      { id: "mem_y", title: "Y", intents: ["rare-intent"] },
    ]);
    const result = analyze(dir);
    const clusters = result.insightsJson.intent_clusters ?? {};
    assert.ok(!("rare-intent" in clusters), "intent supported by 2 episodes must not produce a cluster (min_support=3)");
    rmSync(dir, { recursive: true, force: true });
  });

  it("emits an intent cluster when at least 3 episodes share the intent", () => {
    const dir = makeCorpus([
      { id: "mem_p", title: "P", intents: ["common-intent"] },
      { id: "mem_q", title: "Q", intents: ["common-intent"] },
      { id: "mem_r", title: "R", intents: ["common-intent"] },
    ]);
    const result = analyze(dir);
    const clusters = result.insightsJson.intent_clusters ?? {};
    assert.ok("common-intent" in clusters, "intent shared by 3 episodes must yield a cluster (min_support=3)");
    rmSync(dir, { recursive: true, force: true });
  });
});
