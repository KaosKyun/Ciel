// Single source of truth for the build topology: which canonical src/ subtree
// maps to which generated targets, and which files are build junk never mirrored.
// Imported by BOTH build.mjs and doctor.mjs so they can never disagree on scope —
// a divergence would let the doctor silently gate a different set than the build
// produces (the exact drift this lever exists to kill).
export const MIRRORS = [
  // skills also feed the COMMITTED npm assets (the single tree both installers
  // ship); gated by `git diff --exit-code` in CI like hooks/rules.
  { src: "src/skills", targets: [".claude/skills", ".opencode/skills", "packages/ciel/assets/skills"] },
  // hooks + rules also feed the COMMITTED npm assets (packages/ciel/assets/…),
  // which are gated by `git diff --exit-code` in CI — the real published-content
  // drift gate. copy-assets.cjs no longer owns these (build.mjs does).
  { src: "src/hooks", targets: [".claude/hooks", "packages/ciel/assets/.claude/hooks"] },
  { src: "src/rules", targets: [".claude/rules", "packages/ciel/assets/.claude/rules"] },
];

export function excluded(name) {
  return name === "__pycache__" || name === ".DS_Store" || name.endsWith(".pyc");
}
