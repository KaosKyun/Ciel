// Ciel v5 — Test suite
// Run: npx tsx test-ciel.ts
// These test the plugin infrastructure, NOT the LLM behavior.

import { existsSync, readFileSync, writeFileSync, mkdirSync, rmSync } from "fs";
import { basename, dirname, join } from "path";

let passed = 0;
let failed = 0;

function assert(condition: boolean, label: string): void {
  if (condition) {
    passed++;
    console.log(`  PASS  ${label}`);
  } else {
    failed++;
    console.error(`  FAIL  ${label}`);
  }
}

// ----- Helpers (copied from ciel.ts for testability) -----

const CODE_EXT_RE = /\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$/i;
const TEST_FILE_RE = /(\.test\.|\.spec\.|_test\.|_spec\.)(ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte)$/i;

function getTestPathForSource(sourcePath: string): string[] {
  const base = basename(sourcePath);
  const dir = dirname(sourcePath);
  const nameWithoutExt = base.replace(/\.[^.]+$/, "");
  const ext = base.match(/\.[^.]+$/)?.[0] ?? "";
  return [
    join(dir, `${nameWithoutExt}.test${ext}`),
    join(dir, `${nameWithoutExt}.spec${ext}`),
    join(dir, "__tests__", `${nameWithoutExt}${ext}`),
  ];
}

function isTestFile(filePath: string): boolean {
  return TEST_FILE_RE.test(filePath);
}

function isSourceFile(filePath: string): boolean {
  return CODE_EXT_RE.test(filePath) && !isTestFile(filePath);
}

function extractSessionId(event: any): string {
  const rawId = event?.info?.id ?? event?.sessionID ?? event?.sessionId ?? event?.id ?? `s-${Date.now().toString(36)}`;
  return typeof rawId === "string" ? rawId.slice(0, 8) : "unknown";
}

// ----- Tests -----

console.log("\nCiel v5 Test Suite\n");

// Read plugin source once for all content checks
const pluginSource = readFileSync(".opencode/plugins/ciel.ts", "utf-8");

console.log("--- Model-Driven Depth Classification ---");
console.log("  (Depth is classified by the model via pipeline instruction, not regex.)");
console.log("");

// Verify the pipeline instruction contains the depth guidance
assert(pluginSource.includes("classify depth"), "Pipeline instruction mentions depth classification");
assert(pluginSource.includes("Standard"), "Pipeline instruction mentions Standard depth");
assert(pluginSource.includes("Critical"), "Pipeline instruction mentions Critical depth");
assert(pluginSource.includes("Trivial"), "Pipeline instruction mentions Trivial depth");
assert(pluginSource.includes("Spike"), "Pipeline instruction mentions Spike depth");

console.log("\n--- Helper Functions ---");

assert(isTestFile("auth.test.ts"), "isTestFile: .test.ts");
assert(isTestFile("auth.spec.ts"), "isTestFile: .spec.ts");
assert(isTestFile("__tests__/auth.test.go"), "isTestFile: .test.go");
assert(isTestFile("auth_test.go"), "isTestFile: _test.go");
assert(!isTestFile("auth.ts"), "isTestFile: auth.ts is NOT test");
assert(!isTestFile("test.ts"), "isTestFile: test.ts alone is NOT test");

assert(isSourceFile("auth.ts"), "isSourceFile: auth.ts");
assert(isSourceFile("service.ts"), "isSourceFile: service.ts");
assert(!isSourceFile("auth.test.ts"), "isSourceFile: .test.ts is NOT source");
assert(!isSourceFile("README.md"), "isSourceFile: .md is NOT source");

const candidates = getTestPathForSource("src/auth.ts");
assert(candidates.length === 3, "getTestPathForSource: 3 candidates");
assert(candidates[0].endsWith("auth.test.ts"), "getTestPathForSource: first candidate ends with .test.ts");
assert(candidates[1].endsWith("auth.spec.ts"), "getTestPathForSource: second candidate ends with .spec.ts");

console.log("\n--- Session ID Extraction ---");

assert(extractSessionId({ info: { id: "abc12345" } }) === "abc12345", "session ID from info.id");
assert(extractSessionId({ sessionID: "xyz78901" }) === "xyz78901", "session ID from sessionID");
assert(extractSessionId({ sessionId: "def45678" }) === "def45678", "session ID from sessionId");
assert(extractSessionId({}) !== "unknown", "session ID fallback generates value");
assert(typeof extractSessionId({}) === "string", "session ID fallback is string");
assert(extractSessionId({}).length <= 8, "session ID max 8 chars");

console.log("\n--- Plugin Compilation ---");
// Check the plugin source exists and has minimum length
assert(existsSync(".opencode/plugins/ciel.ts"), "Plugin file exists");
assert(pluginSource.length > 10000, "Plugin source > 10KB");
assert(pluginSource.includes("experimental.chat.system.transform"), "Plugin has system.transform");
assert(pluginSource.includes("experimental.chat.messages.transform"), "Plugin has messages.transform");
assert(pluginSource.includes("tool.execute.before"), "Plugin has tool.execute.before");
assert(pluginSource.includes("tool.execute.after"), "Plugin has tool.execute.after");
assert(pluginSource.includes("experimental.session.compacting"), "Plugin has session.compacting");
assert(pluginSource.includes("CIEL MANDATORY WORKFLOW v5"), "Plugin contains v5 pipeline");
assert(pluginSource.includes("META-CRITIQUER"), "Plugin contains META-CRITIQUER");
assert(pluginSource.includes("SPIKE MODE"), "Plugin contains SPIKE mode");
assert(pluginSource.includes("ASK"), "Plugin contains ASK window");

console.log("\n--- Agent Definitions ---");
const agentFiles = [
  ".opencode/agents/ciel.md",
  ".opencode/agents/ciel-researcher.md",
  ".opencode/agents/ciel-explorer.md",
  ".opencode/agents/ciel-critic.md",
  ".opencode/agents/ciel-improver.md",
];
for (const f of agentFiles) {
  assert(existsSync(f), `Agent file exists: ${f}`);
  const content = readFileSync(f, "utf-8");
  assert(content.includes("Ciel"), `Agent mentions Ciel: ${f}`);
}

console.log("\n--- Skills Count ---");
import { readdirSync } from "fs";
function countSkills(dir: string): number {
  if (!existsSync(dir)) return 0;
  let count = 0;
  const entries = readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      try {
        const subFiles = readdirSync(fullPath);
        if (subFiles.includes("SKILL.md")) count++;
      } catch { /* skip */ }
    }
  }
  return count;
}

const workflowSkills = countSkills("skills/workflow");
assert(workflowSkills >= 25, `Workflow skills >= 25 (found: ${workflowSkills})`);

const opencodeSkills = countSkills(".opencode/skills/workflow");
assert(opencodeSkills >= 25, `OpenCode workflow skills >= 25 (found: ${opencodeSkills})`);

const claudeSkills = countSkills(".claude/skills/workflow");
assert(claudeSkills >= 25, `Claude Code workflow skills >= 25 (found: ${claudeSkills})`);

// ----- Summary -----
console.log(`\n${"=".repeat(40)}`);
console.log(`Results: ${passed} passed, ${failed} failed`);
console.log(`${"=".repeat(40)}\n`);

process.exit(failed > 0 ? 1 : 0);
