#!/usr/bin/env node
// Ciel CLI — Copy template assets from repo root to packages/cli/assets/
// Runs during `npm run build` to bundle templates in the npm package.
// Cross-platform: uses only Node.js built-in modules.

const { existsSync, mkdirSync, copyFileSync, readdirSync, statSync } = require("fs");
const { join, relative, dirname } = require("path");

const REPO_ROOT = join(__dirname, "..", "..", "..");
const ASSETS_DIR = join(__dirname, "..", "assets");

// Files to include in the npm package for offline template serving
const TEMPLATE_PATTERNS = [
  // OpenCode platform files
  { src: "platforms/opencode/.opencode/agents/ciel.md", dest: "platforms/opencode/.opencode/agents/ciel.md" },
  { src: "platforms/opencode/.opencode/agents/ciel-researcher.md", dest: "platforms/opencode/.opencode/agents/ciel-researcher.md" },
  { src: "platforms/opencode/.opencode/agents/ciel-explorer.md", dest: "platforms/opencode/.opencode/agents/ciel-explorer.md" },
  { src: "platforms/opencode/.opencode/agents/ciel-critic.md", dest: "platforms/opencode/.opencode/agents/ciel-critic.md" },
  { src: "platforms/opencode/.opencode/agents/ciel-improver.md", dest: "platforms/opencode/.opencode/agents/ciel-improver.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-init.md", dest: "platforms/opencode/.opencode/commands/ciel-init.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-update.md", dest: "platforms/opencode/.opencode/commands/ciel-update.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-refresh.md", dest: "platforms/opencode/.opencode/commands/ciel-refresh.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-improve.md", dest: "platforms/opencode/.opencode/commands/ciel-improve.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-eval.md", dest: "platforms/opencode/.opencode/commands/ciel-eval.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-create-skill.md", dest: "platforms/opencode/.opencode/commands/ciel-create-skill.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-recommend.md", dest: "platforms/opencode/.opencode/commands/ciel-recommend.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-audit.md", dest: "platforms/opencode/.opencode/commands/ciel-audit.md" },
  { src: "platforms/opencode/.opencode/commands/ciel.md", dest: "platforms/opencode/.opencode/commands/ciel.md" },
  { src: "platforms/opencode/AGENTS.md", dest: "platforms/opencode/AGENTS.md" },
  { src: "platforms/opencode/.opencode/plugins/ciel.js", dest: "platforms/opencode/.opencode/plugins/ciel.js" },

  // Claude Code files
  { src: ".claude/agents/ciel-researcher.md", dest: ".claude/agents/ciel-researcher.md" },
  { src: ".claude/agents/ciel-explorer.md", dest: ".claude/agents/ciel-explorer.md" },
  { src: ".claude/agents/ciel-critic.md", dest: ".claude/agents/ciel-critic.md" },
  { src: ".claude/agents/ciel-improver.md", dest: ".claude/agents/ciel-improver.md" },
  { src: ".claude/hooks/check-test-first.sh", dest: ".claude/hooks/check-test-first.sh" },
  { src: ".claude/hooks/block-destructive.sh", dest: ".claude/hooks/block-destructive.sh" },
  { src: ".claude/hooks/track-file.sh", dest: ".claude/hooks/track-file.sh" },
  { src: ".claude/hooks/meta-critiquer.sh", dest: ".claude/hooks/meta-critiquer.sh" },
  { src: ".claude/settings.json", dest: ".claude/settings.json" },
  { src: "CLAUDE.md", dest: "CLAUDE.md" },
  { src: "AGENTS.md", dest: "AGENTS.md" },

  // Generic commands (shared between OpenCode and Claude Code)
  { src: "commands/ciel-init.md", dest: "commands/ciel-init.md" },
  { src: "commands/ciel-update.md", dest: "commands/ciel-update.md" },
  { src: "commands/ciel-refresh.md", dest: "commands/ciel-refresh.md" },
  { src: "commands/ciel-eval.md", dest: "commands/ciel-eval.md" },
  { src: "commands/ciel-create-skill.md", dest: "commands/ciel-create-skill.md" },
  { src: "commands/ciel-recommend.md", dest: "commands/ciel-recommend.md" },
  { src: "commands/ciel-audit.md", dest: "commands/ciel-audit.md" },

  // Ciel skill files (for Claude Code)
  { src: "skills/ciel/SKILL.md", dest: "skills/ciel/SKILL.md" },
  { src: "skills/ciel/reference.md", dest: "skills/ciel/reference.md" },

  // Compiled plugin JS (for local reference, no node_modules needed)
  { src: "packages/ciel/dist/plugin/index.js", dest: "dist/plugin/index.js" },
];

let count = 0;
let errors = 0;

for (const pattern of TEMPLATE_PATTERNS) {
  const srcPath = join(REPO_ROOT, pattern.src);
  const destPath = join(ASSETS_DIR, pattern.dest);

  if (!existsSync(srcPath)) {
    console.error(`  WARN: source not found: ${pattern.src}`);
    errors++;
    continue;
  }

  // Create destination directory
  mkdirSync(dirname(destPath), { recursive: true });

  // Copy file
  try {
    copyFileSync(srcPath, destPath);
    count++;
  } catch (err) {
    console.error(`  ERROR: could not copy ${pattern.src}: ${err.message}`);
    errors++;
  }
}

console.log(`  Copied ${count} template files to assets/`);
if (errors > 0) {
  console.error(`  ${errors} errors during asset copy`);
  process.exit(1);
}
