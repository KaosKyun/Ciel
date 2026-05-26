#!/usr/bin/env node
// Ciel CLI — Copy template assets from repo root to packages/cli/assets/
// Runs during `npm run build` to bundle templates in the npm package.
// Cross-platform: uses only Node.js built-in modules.

const { existsSync, mkdirSync, copyFileSync, readFileSync, writeFileSync, readdirSync, statSync } = require("fs");
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
  { src: "platforms/opencode/.opencode/commands/ciel-improve.md", dest: "platforms/opencode/.opencode/commands/ciel-improve.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-eval.md", dest: "platforms/opencode/.opencode/commands/ciel-eval.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-create-skill.md", dest: "platforms/opencode/.opencode/commands/ciel-create-skill.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-status.md", dest: "platforms/opencode/.opencode/commands/ciel-status.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-memory-init.md", dest: "platforms/opencode/.opencode/commands/ciel-memory-init.md" },
  { src: "platforms/opencode/.opencode/commands/ciel-audit.md", dest: "platforms/opencode/.opencode/commands/ciel-audit.md" },
  { src: "platforms/opencode/.opencode/commands/ciel.md", dest: "platforms/opencode/.opencode/commands/ciel.md" },
  { src: "platforms/opencode/AGENTS.md", dest: "platforms/opencode/AGENTS.md" },
  { src: "platforms/opencode/.opencode/plugins/ciel.ts", dest: "platforms/opencode/.opencode/plugins/ciel.ts" },

  // Claude Code files
  { src: ".claude/agents/ciel-researcher.md", dest: ".claude/agents/ciel-researcher.md" },
  { src: ".claude/agents/ciel-explorer.md", dest: ".claude/agents/ciel-explorer.md" },
  { src: ".claude/agents/ciel-critic.md", dest: ".claude/agents/ciel-critic.md" },
  { src: ".claude/agents/ciel-improver.md", dest: ".claude/agents/ciel-improver.md" },
  { src: "hooks/block-destructive.sh", dest: ".claude/hooks/block-destructive.sh" },
  { src: "hooks/track-file.sh", dest: ".claude/hooks/track-file.sh" },
  { src: "hooks/track-verification.sh", dest: ".claude/hooks/track-verification.sh" },
  { src: "hooks/pre-tool-write.sh", dest: ".claude/hooks/pre-tool-write.sh" },
  { src: "hooks/pre-agent-gate.sh", dest: ".claude/hooks/pre-agent-gate.sh" },
  { src: "hooks/check-dispatch-gate.sh", dest: ".claude/hooks/check-dispatch-gate.sh" },
  { src: "hooks/stop.sh", dest: ".claude/hooks/stop.sh" },
  { src: "hooks/subagent-stop.sh", dest: ".claude/hooks/subagent-stop.sh" },
  // Cued-recall memory hooks
  { src: "hooks/session-start.sh", dest: ".claude/hooks/session-start.sh" },
  { src: "hooks/user-prompt-submit.sh", dest: ".claude/hooks/user-prompt-submit.sh" },
  { src: "hooks/memory-bootstrap.sh", dest: ".claude/hooks/memory-bootstrap.sh" },
  { src: "hooks/memory-engine.py", dest: ".claude/hooks/memory-engine.py" },
  { src: ".claude/settings.json", dest: ".claude/settings.json" },
  { src: "CLAUDE.md", dest: "CLAUDE.md" },
  { src: "AGENTS.md", dest: "AGENTS.md" },

  // Generic commands (shared between OpenCode and Claude Code)
  { src: "commands/ciel-init.md", dest: "commands/ciel-init.md" },
  { src: "commands/ciel-update.md", dest: "commands/ciel-update.md" },
  { src: "commands/ciel-eval.md", dest: "commands/ciel-eval.md" },
  { src: "commands/ciel-create-skill.md", dest: "commands/ciel-create-skill.md" },
  { src: "commands/ciel-status.md", dest: "commands/ciel-status.md" },
  { src: "commands/ciel-audit.md", dest: "commands/ciel-audit.md" },
  { src: "commands/ciel-memory-init.md", dest: "commands/ciel-memory-init.md" },
  { src: "commands/ciel-memory.md", dest: "commands/ciel-memory.md" },
  { src: "commands/ciel-compile.md", dest: "commands/ciel-compile.md" },

  // Ciel skill files (for Claude Code)
  { src: "skills/ciel/SKILL.md", dest: "skills/ciel/SKILL.md" },
  { src: "skills/ciel/reference.md", dest: "skills/ciel/reference.md" },

  // Compiled plugin JS (for local reference, no node_modules needed)
  { src: "packages/ciel/dist/plugin/index.js", dest: "dist/plugin/index.js" },
];

// Auto-discover workflow skills (skills/workflow/<name>/SKILL.md). Avoids the
// 28-entry hardcoded list — every new workflow skill gets shipped automatically.
const workflowDir = join(REPO_ROOT, "skills", "workflow");
if (existsSync(workflowDir)) {
  for (const entry of readdirSync(workflowDir)) {
    const skillPath = join("skills", "workflow", entry, "SKILL.md");
    if (existsSync(join(REPO_ROOT, skillPath))) {
      TEMPLATE_PATTERNS.push({ src: skillPath, dest: skillPath });
    }
    // Some workflow skills carry a reference.md sidecar.
    const refPath = join("skills", "workflow", entry, "reference.md");
    if (existsSync(join(REPO_ROOT, refPath))) {
      TEMPLATE_PATTERNS.push({ src: refPath, dest: refPath });
    }
  }
}

// Auto-discover meta skills (skills/meta/<name>/SKILL.md).
const metaDir = join(REPO_ROOT, "skills", "meta");
if (existsSync(metaDir)) {
  for (const entry of readdirSync(metaDir)) {
    const skillPath = join("skills", "meta", entry, "SKILL.md");
    if (existsSync(join(REPO_ROOT, skillPath))) {
      TEMPLATE_PATTERNS.push({ src: skillPath, dest: skillPath });
    }
  }
}

// Auto-discover domain skills (.claude/skills/*/SKILL.md) and their sidecars.
const domainSkillsDir = join(REPO_ROOT, ".claude", "skills");
if (existsSync(domainSkillsDir)) {
  for (const entry of readdirSync(domainSkillsDir)) {
    const skillPath = join(".claude", "skills", entry, "SKILL.md");
    if (existsSync(join(REPO_ROOT, skillPath))) {
      TEMPLATE_PATTERNS.push({ src: skillPath, dest: skillPath });
    }
    const refPath = join(".claude", "skills", entry, "reference.md");
    if (existsSync(join(REPO_ROOT, refPath))) {
      TEMPLATE_PATTERNS.push({ src: refPath, dest: refPath });
    }
  }
}

// Auto-discover domain rules (.claude/rules/*.md).
const rulesDir = join(REPO_ROOT, ".claude", "rules");
if (existsSync(rulesDir)) {
  for (const entry of readdirSync(rulesDir)) {
    if (entry.endsWith(".md")) {
      const rulePath = join(".claude", "rules", entry);
      if (existsSync(join(REPO_ROOT, rulePath))) {
        TEMPLATE_PATTERNS.push({ src: rulePath, dest: rulePath });
      }
    }
  }
}

let count = 0;
let errors = 0;

// Read the package version for {{VERSION}} substitution in templates
const pkgVersion = JSON.parse(readFileSync(join(__dirname, '..', 'package.json'), 'utf8')).version;

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

  // Copy file with {{VERSION}} substitution
  try {
    let content = readFileSync(srcPath, 'utf8');
    content = content.replace(/\{\{VERSION\}\}/g, pkgVersion);
    writeFileSync(destPath, content, 'utf8');
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
