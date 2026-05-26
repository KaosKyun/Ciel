// Single source of truth for the build topology: which canonical src/ subtree
// maps to which generated targets, and which files are build junk never mirrored.
// Imported by BOTH build.mjs and doctor.mjs so they can never disagree on scope —
// a divergence would let the doctor silently gate a different set than the build
// produces (the exact drift this lever exists to kill).
export const MIRRORS = [
  { src: "src/skills", targets: [".claude/skills", ".opencode/skills"] },
  { src: "src/hooks", targets: [".claude/hooks"] },
  { src: "src/rules", targets: [".claude/rules"] },
];

export function excluded(name) {
  return name === "__pycache__" || name === ".DS_Store" || name.endsWith(".pyc");
}
