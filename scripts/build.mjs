#!/usr/bin/env node
// Ciel build — levier A.
// Canonical source of truth: src/. This script regenerates the harness mirrors
// from src/. Targets are GENERATED — never hand-edit them; edit src/ and re-run
// `node scripts/build.mjs`.
//
// Deterministic by construction: sorted directory traversal, byte-faithful copy
// (no re-encoding, no timestamps), full mirror rebuild (stale target files
// cannot survive), python build junk excluded. This is what lets the doctor
// gate rely on a clean, reproducible diff.
import {
  readdirSync,
  statSync,
  readFileSync,
  writeFileSync,
  chmodSync,
  mkdirSync,
  rmSync,
} from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { MIRRORS, excluded } from "./mirrors.mjs";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

// Byte-faithful recursive mirror: wipe the target, then copy src verbatim in
// sorted order. Buffers (not strings) so line endings/encoding are preserved.
function mirrorTree(src, dst) {
  rmSync(dst, { recursive: true, force: true });
  (function rec(s, d) {
    mkdirSync(d, { recursive: true });
    for (const entry of readdirSync(s).sort()) {
      if (excluded(entry)) continue;
      const sp = join(s, entry);
      const dp = join(d, entry);
      const st = statSync(sp);
      if (st.isDirectory()) rec(sp, dp);
      else {
        writeFileSync(dp, readFileSync(sp));
        // Preserve permission bits — hooks (*.sh, *.py) must stay executable or
        // the harness fails with "Permission denied" when it runs them directly.
        chmodSync(dp, st.mode);
      }
    }
  })(src, dst);
}

function countFiles(dir) {
  let n = 0;
  for (const e of readdirSync(dir)) {
    if (excluded(e)) continue;
    const p = join(dir, e);
    if (statSync(p).isDirectory()) n += countFiles(p);
    else n++;
  }
  return n;
}

for (const { src, targets } of MIRRORS) {
  const srcDir = join(ROOT, src);
  const n = countFiles(srcDir);
  for (const t of targets) mirrorTree(srcDir, join(ROOT, t));
  console.log(`[ciel build] ${src} (${n} files) → ${targets.join(", ")}`);
}
