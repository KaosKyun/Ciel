#!/usr/bin/env node
// Ciel consistency doctor — dev-repo gate (NOT the shipped `ciel doctor`).
// Read-only. Fails CI on drift between canonical src/ and its generated mirrors,
// or on version desync. Run: node scripts/doctor.mjs
//
// Why a separate doctor: src/ only exists in the Ciel dev repo. The shipped
// `ciel doctor` (packages/ciel/src/cli/doctor.ts) checks an INSTALLED project
// (hooks present, memory index, rules) and must not assume src/.
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { MIRRORS, excluded } from "./mirrors.mjs";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..");

// Tracked files whose version must equal the authoritative VERSION file.
// .ciel/version is gitignored (local sentinel) so it is not checked here.
const VERSION_CONSUMERS = [
  "packages/ciel/package.json",
  "package.json",
  "packages/ciel/.ciel/version",
];

function walk(dir) {
  const out = [];
  (function rec(d, base) {
    for (const e of readdirSync(d).sort()) {
      if (excluded(e)) continue;
      const p = join(d, e);
      if (statSync(p).isDirectory()) rec(p, base ? join(base, e) : e);
      else out.push(base ? join(base, e) : e);
    }
  })(dir, "");
  return out.sort();
}

function readVersion(root, rel) {
  const p = join(root, rel);
  if (!existsSync(p)) return null;
  if (rel.endsWith(".json")) return JSON.parse(readFileSync(p, "utf8")).version;
  return readFileSync(p, "utf8").trim();
}

// Every tracked version file must equal VERSION (single source of truth).
export function checkVersions(root) {
  const authoritative = readVersion(root, "VERSION");
  if (!authoritative) return ["VERSION file missing or empty"];
  const failures = [];
  for (const rel of VERSION_CONSUMERS) {
    const v = readVersion(root, rel);
    if (v === null) continue; // absent ≠ drift
    if (v !== authoritative) {
      failures.push(`${rel} = ${v}, expected ${authoritative} (VERSION is the single source)`);
    }
  }
  return failures;
}

// Each generated mirror must equal its canonical source exactly: same file set,
// same bytes, same executable bit. Detects hand-edits and forgotten rebuilds.
export function checkMirrors(root, mirrors = MIRRORS) {
  const failures = [];
  for (const { src, targets } of mirrors) {
    const sdir = join(root, src);
    if (!existsSync(sdir)) {
      failures.push(`canonical source ${src} is missing`);
      continue;
    }
    const srcFiles = walk(sdir);
    const srcSet = new Set(srcFiles);
    for (const target of targets) {
      const tdir = join(root, target);
      if (!existsSync(tdir)) {
        failures.push(`${target} is missing — run: node scripts/build.mjs`);
        continue;
      }
      const tFiles = walk(tdir);
      for (const f of tFiles) {
        if (!srcSet.has(f)) failures.push(`${target}/${f} is stale (not in ${src}) — run build`);
      }
      for (const f of srcFiles) {
        const tp = join(tdir, f);
        if (!existsSync(tp)) {
          failures.push(`${target}/${f} is missing — run build`);
          continue;
        }
        const sp = join(sdir, f);
        if (!readFileSync(tp).equals(readFileSync(sp))) {
          failures.push(`${target}/${f} differs from ${src} (hand-edited or stale) — edit src/ and run build`);
        } else if ((statSync(tp).mode & 0o111) !== (statSync(sp).mode & 0o111)) {
          failures.push(`${target}/${f} exec-bit differs from ${src} — run build`);
        }
      }
    }
  }
  return failures;
}

// Stale paradigm-generation labels in canonical source. Current generation is v9;
// v5/v7 are stale. Warning only (not a hard failure) — full label cleanup is separate.
export function checkLabels(root) {
  const warnings = [];
  const srcDir = join(root, "src");
  if (!existsSync(srcDir)) return warnings;
  const stale = /Ciel v[578]\b/;
  for (const f of walk(srcDir)) {
    if (!f.endsWith(".md")) continue;
    const body = readFileSync(join(srcDir, f), "utf8");
    const m = body.match(stale);
    if (m) warnings.push(`src/${f} carries stale label "${m[0]}"`);
  }
  return warnings;
}

// CLI entry — only runs when invoked directly, not when imported by tests.
if (process.argv[1] && process.argv[1].endsWith("doctor.mjs")) {
  const mirrorF = checkMirrors(REPO);
  const versionF = checkVersions(REPO);
  const labelW = checkLabels(REPO);

  const fail = [...versionF, ...mirrorF];
  if (versionF.length) {
    console.log("✗ version sync:");
    for (const f of versionF) console.log(`  - ${f}`);
  } else console.log("✓ version sync: all version files match VERSION");

  if (mirrorF.length) {
    console.log("✗ mirror drift:");
    for (const f of mirrorF) console.log(`  - ${f}`);
  } else console.log("✓ mirror drift: every mirror matches canonical src/");

  if (labelW.length) {
    console.log(`⚠ stale labels (${labelW.length}, non-blocking):`);
    for (const w of labelW.slice(0, 10)) console.log(`  - ${w}`);
    if (labelW.length > 10) console.log(`  … +${labelW.length - 10} more`);
  }

  if (fail.length) {
    console.log(`\nDoctor: ${fail.length} consistency failure(s).`);
    process.exit(1);
  }
  console.log("\nDoctor: consistent ✓");
}
