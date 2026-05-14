// hooks-regex — regression tests for user-prompt-submit.sh capture regexes.
// Reproduces Risk 1 from the v6.9.x RELIRE on the Neiyomi memory-routing
// incident: an earlier draft used `remember (this|that|it|to)` as a trigger,
// which fired on every casual English prompt containing "remember to X" and
// polluted the cued-recall corpus.
//
// Strategy: shell out to bash with the prompt as $PROMPT, capture stdout/JSON,
// and check whether `CAPTURE GATE:` appears in the additionalContext. This
// exercises the real hook script, not a mock — drift-proof.

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { join } from "node:path";

const HOOK = join(__dirname, "..", "..", "..", "hooks", "user-prompt-submit.sh");

function runHook(prompt: string): { fired: boolean; gateLabel: string | null } {
  const input = JSON.stringify({ prompt });
  let out: string;
  try {
    out = execFileSync("bash", [HOOK], { input, encoding: "utf8" });
  } catch (e: any) {
    out = String(e.stdout ?? "");
  }
  // Parse the JSON the hook prints and look at additionalContext for CAPTURE GATE.
  let context = "";
  try {
    const parsed = JSON.parse(out);
    context = parsed?.hookSpecificOutput?.additionalContext ?? "";
  } catch {
    context = out;
  }
  const fired = /CAPTURE GATE:/.test(context);
  const labelMatch = context.match(/CAPTURE GATE: ([^—]+) —/);
  return { fired, gateLabel: labelMatch ? labelMatch[1].trim() : null };
}

describe("user-prompt-submit.sh — explicit save-request regex (MUST match)", () => {
  const cases = [
    "save this to memory",
    "save that to the memory",
    "save it in memory",
    "put it in memory",
    "put this in the memory",
    "put it in the memory of ciel",        // The literal Neiyomi user phrase
    "garde ça en mémoire",
    "garde cela en memoire",
    "mets ça en mémoire",
    "enregistre ça en mémoire",
    "enregistre cela dans la mémoire",
    "sauvegarde ça à la mémoire",
    "mémorise ça",
    "memorise this",
    "memorise that",
  ];
  for (const prompt of cases) {
    it(`fires CAPTURE GATE on: "${prompt}"`, () => {
      const { fired, gateLabel } = runHook(prompt);
      assert.ok(fired, `expected CAPTURE GATE for "${prompt}", got: ${JSON.stringify({ fired, gateLabel })}`);
    });
  }
});

describe("user-prompt-submit.sh — intervention regex (MUST match)", () => {
  // Bucket 1 — sanity-check that the v6.2 patterns still fire after refactor.
  const cases = [
    "non en fait c'est pas ça",
    "tu as oublié de gérer le cas null",
    "you forgot to handle the null case",
    "don't forget that the API returns 204",
    "no, actually we use the v2 endpoint",
    "wait, no don't refactor this",
  ];
  for (const prompt of cases) {
    it(`fires CAPTURE GATE on: "${prompt}"`, () => {
      const { fired } = runHook(prompt);
      assert.ok(fired, `expected CAPTURE GATE for intervention: "${prompt}"`);
    });
  }
});

describe("user-prompt-submit.sh — false-positive guard (MUST NOT match)", () => {
  // These are real-world casual phrasings the v6.3 first draft over-matched on.
  // If this list ever fires, the corpus pollution returns.
  const cases = [
    "I'll remember to do that later",
    "Please remember to add a test",
    "remember this is just a draft",
    "remember it's experimental",
    "if I remember correctly this works",
    "I remember this code from last week",
    "let's memorise these steps",
    "the memory leak is in module X",
    "this caches memory usage stats",
    "save the file",
    "put it in the queue",
    "store this in the cache",
  ];
  for (const prompt of cases) {
    it(`does NOT fire CAPTURE GATE on: "${prompt}"`, () => {
      const { fired, gateLabel } = runHook(prompt);
      assert.equal(fired, false, `unexpected CAPTURE GATE on "${prompt}" (label: ${gateLabel})`);
    });
  }
});
