#!/usr/bin/env tsx
// sync-skills-to-agents.ts — Keep bundled inline skills in agents in sync with source SKILL.md files.
//
// Usage:
//   tsx scripts/sync-skills-to-agents.ts          # Apply changes
//   tsx scripts/sync-skills-to-agents.ts --check   # Dry run, exit 1 if out of sync

import { readFileSync, writeFileSync, existsSync } from "fs";
import { join, dirname, resolve } from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = resolve(__dirname, "..");

// ─── Sync config: which skills are bundled in which agent ───
// NOTE: OpenCode primary agent (ciel.md) bundles NO inline skills —
// the TS plugin (ciel.ts) injects the full workflow + skills into every system prompt.
// This script is kept for Claude Code / other platforms that use bundled agent files.
const SYNC_CONFIG: Record<string, string[]> = {
  // Claude Code agents (in ~/.claude/plugins/ciel/agents/)
  // "agents/researcher.md": ["skills/research/doc-validator-official/SKILL.md", ...],
  // "agents/explorer.md": ["skills/domain/frontend-mastery/SKILL.md", ...],
};

const SECTION_START = "## Skills invoked (bundled inline)";

function readSkillContent(skillPath: string): string {
  const fullPath = join(ROOT, skillPath);
  if (!existsSync(fullPath)) {
    throw new Error(`Skill not found: ${fullPath}`);
  }
  return readFileSync(fullPath, "utf-8");
}

function buildBundledSection(agentPath: string, skills: string[]): string {
  const lines: string[] = [];
  lines.push("## Skills invoked (bundled inline)");
  lines.push("");
  lines.push("> The following skills are bundled here because OpenCode has no native 'skills' primitive.");
  lines.push("> Each skill below is a complete procedure you invoke by following its 'process' section.");
  lines.push("");

  for (const skillPath of skills) {
    const content = readSkillContent(skillPath);
    const fmEnd = content.indexOf("---", 3);
    const afterFm = fmEnd === -1 ? content : content.slice(fmEnd + 3).trimStart();
    const skillName = skillPath.split("/").pop()?.replace("/SKILL.md", "");
    lines.push(`### Skill: \`${skillName}\``);
    lines.push("");
    lines.push(afterFm);
    lines.push("");
    lines.push("---");
    lines.push("");
  }

  return lines.join("\n");
}

function findSectionBounds(content: string): { start: number; end: number } | null {
  const startIdx = content.indexOf(SECTION_START);
  if (startIdx === -1) return null;

  const afterStart = content.slice(startIdx + SECTION_START.length);
  const lines = afterStart.split("\n");
  let endOffset = afterStart.length;

  for (let i = 1; i < lines.length; i++) {
    if (/^## /.test(lines[i])) {
      endOffset = lines.slice(0, i).join("\n").length;
      break;
    }
  }

  return { start: startIdx, end: startIdx + SECTION_START.length + endOffset };
}

function syncAgent(agentPath: string, skills: string[], checkOnly: boolean): boolean {
  const fullPath = join(ROOT, agentPath);
  if (!existsSync(fullPath)) {
    console.error(`Agent not found: ${fullPath}`);
    return false;
  }

  const content = readFileSync(fullPath, "utf-8");
  const bounds = findSectionBounds(content);

  if (!bounds) {
    console.warn(`⚠  ${agentPath}: no "${SECTION_START}" section found — skipping`);
    return false;
  }

  const newSection = buildBundledSection(agentPath, skills);
  const newContent = content.slice(0, bounds.start) + newSection + content.slice(bounds.end);

  if (content === newContent) {
    console.log(`✓  ${agentPath}: already in sync`);
    return true;
  }

  if (checkOnly) {
    console.log(`✗  ${agentPath}: out of sync (run without --check to fix)`);
    return false;
  }

  writeFileSync(fullPath, newContent, "utf-8");
  console.log(`✓  ${agentPath}: updated bundled skills (${skills.length} skills)`);
  return true;
}

// ─── Main ───
const checkOnly = process.argv.includes("--check");
console.log(checkOnly ? "🔍 Checking sync status..." : "🔄 Syncing skills to agents...");
console.log("");

let allSynced = true;
for (const [agentPath, skills] of Object.entries(SYNC_CONFIG)) {
  const ok = syncAgent(agentPath, skills, checkOnly);
  if (!ok) allSynced = false;
}

console.log("");
if (allSynced) {
  console.log("All agents in sync.");
  process.exit(0);
} else {
  console.log("Some agents are out of sync.");
  process.exit(checkOnly ? 1 : 0);
}
