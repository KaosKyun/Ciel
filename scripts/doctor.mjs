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

// The version-consumer set is DERIVED from release-please's config so the two
// can never drift out of parity: add an extra-file in .github/release-please-config.json
// and the doctor tracks it automatically. Tracking a hand-maintained subset is what
// let plugin.json/marketplace.json/install.sh fall behind (6.14.1 / 6.13.0) while
// VERSION was 6.16.0, undetected.
const RP_CONFIG = ".github/release-please-config.json";
const MARKER_RE = /x-release-please-(?:major|minor|patch|version)/;

const jsonGet = (accessor = (o) => o.version) => (raw) => accessor(JSON.parse(raw));
// release-please's `generic` updater rewrites ONLY the line carrying the marker
// comment — key off that line, never the ${CIEL_VERSION} interpolations elsewhere.
const markerGet = (re) => (raw) => {
  const line = raw.split("\n").find((l) => re.test(l));
  const m = line && line.match(/(\d+\.\d+\.\d+(?:[-+.][0-9A-Za-z.-]+)?)/);
  return m ? m[1] : null;
};

// Minimal JSONPath → accessor for the forms release-please uses: $.a, $.a.b, $.a[0].b.
function jsonpathAccessor(jp) {
  const keys = [];
  const re = /\.([A-Za-z_$][\w$]*)|\[(\d+)\]/g;
  let m;
  while ((m = re.exec(jp))) keys.push(m[1] !== undefined ? m[1] : Number(m[2]));
  return (obj) => keys.reduce((o, k) => (o == null ? undefined : o[k]), obj);
}

// Map one release-please extra-files entry to a consumer descriptor (null = skip).
function extraFileToConsumer(ef) {
  if (typeof ef === "string") {
    if (ef === "VERSION") return null; // the authoritative source, not a consumer
    return { file: ef, label: `${ef}#x-release-please`, get: markerGet(MARKER_RE) };
  }
  const jp = ef.jsonpath;
  if (ef.type === "json" || jp) {
    const accessor = jsonpathAccessor(jp || "$.version");
    return { file: ef.path, label: `${ef.path}#${jp || "$.version"}`, get: (raw) => accessor(JSON.parse(raw)) };
  }
  return { file: ef.path, label: `${ef.path}#x-release-please`, get: markerGet(MARKER_RE) };
}

// Version files NOT in release-please's config but still tracked: a gitignored
// Ciel sentinel + release-please's own manifest (its desync produced stale PR #69).
const DOCTOR_EXTRAS = [
  { file: "packages/ciel/.ciel/version", label: "packages/ciel/.ciel/version", get: (raw) => raw.trim() },
  { file: ".github/.release-please-manifest.json", label: ".github/.release-please-manifest.json#['.']", get: (raw) => JSON.parse(raw)["."] },
];

// Derive consumers from release-please-config.json: each node package's own
// package.json (auto-bumped by release-type) + every extra-files entry, plus the
// doctor-specific extras. Deduped by label. Tolerates an absent config (extras only).
export function deriveConsumers(root) {
  const consumers = [];
  const seen = new Set();
  const add = (c) => { if (c && !seen.has(c.label)) { seen.add(c.label); consumers.push(c); } };
  const raw = readRaw(root, RP_CONFIG);
  if (raw) {
    const cfg = JSON.parse(raw);
    for (const [pkgPath, pkg] of Object.entries(cfg.packages || {})) {
      if ((pkg["release-type"] || cfg["release-type"]) === "node") {
        const pj = pkgPath === "." ? "package.json" : `${pkgPath}/package.json`;
        add({ file: pj, label: `${pj}#$.version`, get: jsonGet() });
      }
      for (const ef of pkg["extra-files"] || []) add(extraFileToConsumer(ef));
    }
    for (const ef of cfg["extra-files"] || []) add(extraFileToConsumer(ef));
  }
  for (const c of DOCTOR_EXTRAS) add(c);
  return consumers;
}

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

function readRaw(root, rel) {
  const p = join(root, rel);
  return existsSync(p) ? readFileSync(p, "utf8") : null;
}

// Every tracked version file must equal VERSION (single source of truth). The
// consumer set mirrors release-please's extra-files + manifest, so a partial
// manual bump (the bug that desynced 6.13/6.14/6.16) fails the gate.
export function checkVersions(root) {
  const raw = readRaw(root, "VERSION");
  if (!raw || !raw.trim()) return ["VERSION file missing or empty"];
  const authoritative = raw.trim();
  const failures = [];
  for (const c of deriveConsumers(root)) {
    const body = readRaw(root, c.file);
    if (body === null) continue; // absent ≠ drift
    const label = c.label || c.file;
    let v;
    try {
      v = c.get(body);
    } catch (e) {
      failures.push(`${label}: could not read version (${e.message})`);
      continue;
    }
    if (v == null) {
      failures.push(`${label}: version token not found`);
      continue;
    }
    if (v !== authoritative) {
      failures.push(`${label} = ${v}, expected ${authoritative} (VERSION is the single source)`);
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

  const fail = [...versionF, ...mirrorF, ...labelW];
  if (versionF.length) {
    console.log("✗ version sync:");
    for (const f of versionF) console.log(`  - ${f}`);
  } else console.log("✓ version sync: all version files match VERSION");

  if (mirrorF.length) {
    console.log("✗ mirror drift:");
    for (const f of mirrorF) console.log(`  - ${f}`);
  } else console.log("✓ mirror drift: every mirror matches canonical src/");

  if (labelW.length) {
    console.log(`✗ stale generation labels (${labelW.length}):`);
    for (const w of labelW.slice(0, 10)) console.log(`  - ${w}`);
    if (labelW.length > 10) console.log(`  … +${labelW.length - 10} more`);
  } else console.log("✓ labels: no stale v5/v7/v8 generation labels in src/");

  if (fail.length) {
    console.log(`\nDoctor: ${fail.length} consistency failure(s).`);
    process.exit(1);
  }
  console.log("\nDoctor: consistent ✓");
}
