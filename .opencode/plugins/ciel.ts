// Ciel -- OpenCode plugin (v5.0.0)
// Full 16-step pipeline: DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE
//   -> RECHERCHE -> SECURITE -> CODEBASE -> EVALUER -> ASK2
//   -> FAIRE -> ADR -> RELIRE -> PROUVER -> MEMOIRE -> META
//
// Injection model:
//   - shell.env -> inject CIEL_SESSION_ID, CIEL_DEPTH, CIEL_MODE
//   - experimental.chat.system.transform -> CIEL WORKFLOW v5 + overlay + state
//   - experimental.chat.messages.transform -> depth classification
//   - session.* events -> tracking, META-CRITIQUER, RELIRE reminders
//   - tool.execute.before -> FAIRE gates reminder + critical file detection
//   - tool.execute.after -> file tracking + RELIRE trigger + map update
//   - experimental.session.compacting -> persist learnings + map
//   - tool helper -> custom ciel-status tool

import type { Plugin } from "@opencode-ai/plugin";
import { tool } from "@opencode-ai/plugin";
import { readFileSync, existsSync, writeFileSync, mkdirSync } from "fs";
import { basename, dirname, join } from "path";

// ----- Constants -----

const CODE_EXT_RE = /\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$/i;
const TEST_FILE_RE = /(\.test\.|\.spec\.|_test\.|_spec\.)(ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte)$/i;
const CRITICAL_FILE_RE = /(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret|Payment|Account|Credential)/;
const CIEL_DIR = ".ciel";
const MAP_FILE = join(CIEL_DIR, "map.json");
const PARKING_FILE = join(CIEL_DIR, "parking.md");
const LEARNINGS_FILE = join(CIEL_DIR, "learnings.md");
const EXPLORATION_FLAG = join(CIEL_DIR, "exploration.active");
const MEMORY_FILE = join(CIEL_DIR, "memory.json");

// ----- V5 WORKFLOW INJECTION -----

const CIEL_WORKFLOW_INSTRUCTION = `
Every response MUST start with depth classification. Then follow the matching pipeline.

CLASSIFY: Trivial / Standard / Critical / Spike

| Depth | Pipeline |
|-------|----------|
| Standard/Critical | DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE -> RECHERCHE -> SECURITE -> CODEBASE -> EVALUER -> ASK2 -> FAIRE -> ADR -> RELIRE -> PROUVER -> MEMOIRE -> META |
| Trivial | QUOI -> FAIRE -> META |
| Spike | QUOI -> ASK -> AVEC QUOI -> DIVERGE -> FAIRE (relaxed) -> META |

USE the question tool for ASK/ASK2. NEVER skip steps. NEVER code on assumptions.
`;

const FAIRE_BEFORE_REMINDER = `
[CIEL FAIRE GATES -- BEFORE WRITE/EDIT]
Before executing this write/edit, verify:
1. TEST-FIRST (RED): Have you written tests FIRST? If this is source code, a corresponding test file must exist or be created first.
2. ALTERNATIVES: Can you justify X over Y? (comment or commit message)
3. IDIOMATIC: Are you using the framework's idiomatic pattern? If bypassing, justify why.
4. QUALITY: complexity < 15, nesting < 4, functions < 50 lines
5. REMOVAL: If deleting code -- who uses it? What replaces it? What degrades?
6. BOY-SCOUT: Did you leave the code better than you found it?
`;

const META_CRITIQUER = `
[CIEL META-CRITIQUER -- 30s POST-TASK REFLECTION]
After completing the task, reflect on:
(1) Depth match -- etait-ce Trivial/Standard/Critical/Spike correct ?
(2) Failure mode -- nouveau mode d'echec decouvert ?
(3) User correction -- l'utilisateur a-t-il corrige quelque chose ? -> persist dans learnings
(4) Stale branches -- branches a nettoyer ?
(5) Uncovered issues -- problemes non resolus ?
(6) Context health -- suggerer /compact si > 50% ?
(7) Dead code -- code mort introduit ?
(8) Map update -- la carte du projet (.ciel/map.json) est-elle a jour ?
(9) Parking -- y a-t-il des decouvertes fortuites a noter dans .ciel/parking.md ?
(10) Boy-scout -- le code est-il meilleur qu'avant ?
`;

// ----- Helpers -----

function getTestPathForSource(sourcePath: string): string[] {
  const base = basename(sourcePath);
  const dir = dirname(sourcePath);
  const nameWithoutExt = base.replace(/\.[^.]+$/, "");
  const ext = base.match(/\.[^.]+$/)?.[0] ?? "";

  const candidates = [
    join(dir, `${nameWithoutExt}.test${ext}`),
    join(dir, `${nameWithoutExt}.spec${ext}`),
    join(dir, `${nameWithoutExt}_test${ext}`),
    join(dir, `${nameWithoutExt}_spec${ext}`),
    join(dir, "__tests__", `${nameWithoutExt}${ext}`),
    join(dir, "test", `${nameWithoutExt}${ext}`),
    join(dir, "tests", `${nameWithoutExt}${ext}`),
  ];

  if (ext === ".ts" || ext === ".tsx") {
    candidates.push(join(dir, `${nameWithoutExt}.test.js`));
    candidates.push(join(dir, `${nameWithoutExt}.spec.js`));
  }

  return candidates;
}

function sourceFileHasTest(sourcePath: string): boolean {
  const candidates = getTestPathForSource(sourcePath);
  for (const candidate of candidates) {
    if (existsSync(candidate)) return true;
  }
  return false;
}

function isTestFile(filePath: string): boolean {
  return TEST_FILE_RE.test(filePath);
}

function isSourceFile(filePath: string): boolean {
  return CODE_EXT_RE.test(filePath) && !isTestFile(filePath);
}

function isSpikeMode(): boolean {
  return existsSync(EXPLORATION_FLAG);
}

function ensureCielDir(): void {
  if (!existsSync(CIEL_DIR)) {
    mkdirSync(CIEL_DIR, { recursive: true });
  }
}

function writeParkingEntry(entry: string): void {
  ensureCielDir();
  const timestamp = new Date().toISOString().split("T")[0];
  const formatted = `- [${timestamp}] ${entry}\n`;
  try {
    const existing = existsSync(PARKING_FILE) ? readFileSync(PARKING_FILE, "utf-8") : "";
    const header = "# Ciel Parking Lot -- Decouvertes fortuites\n\n";
    const content = existing.startsWith("#") ? existing : header + existing;
    writeFileSync(PARKING_FILE, content + formatted, "utf-8");
  } catch {
    // silent
  }
}

// ----- Plugin -----

const ciel: Plugin = async ({ client }) => {
  const writtenFiles = new Set<string>();
  const MAX_TRACKED_FILES = 100;
  let relireSticky = false;
  let lastDepthHint: string | null = null;
  let overlayContent: string | null = null;
  let faireBlocked: { filePath: string; gate: string; candidates: string[] } | null = null;
  let sessionId: string = "unknown";
  let taskCount: number = 0;
  let readDocsAttempted: boolean = false;
  let askWindowUsed: boolean = false;

  return {
    // ----- CUSTOM TOOLS -----
    tool: {
      "ciel-status": tool({
        description: "Shows current Ciel session state: depth classification, files changed, RELIRE status, FAIRE gate state, spike mode. Use when user asks 'what is the Ciel status' or 'show Ciel state'.",
        args: {},
        async execute(_args, _context) {
          const changed = Array.from(writtenFiles);
          return JSON.stringify({
            sessionId,
            depthHint: lastDepthHint,
            filesChanged: changed.length,
            files: changed.slice(0, 10),
            relireRequired: relireSticky,
            spikeMode: isSpikeMode(),
            taskCount,
            askWindowUsed,
            readDocsAttempted,
            faireBlocked: faireBlocked ? {
              file: faireBlocked.filePath,
              gate: faireBlocked.gate,
            } : null,
            overlayLoaded: overlayContent != null,
          }, null, 2);
        },
      }),
    },

    // ----- SHELL ENV -----
    "shell.env": async (_input, output) => {
      output.env.CIEL_SESSION_ID = sessionId;
      output.env.CIEL_DEPTH = lastDepthHint ?? "unclassified";
      output.env.CIEL_MODE = isSpikeMode() ? "spike" : "standard";
    },

    // ----- EVENTS -----
    event: async ({ event }) => {
      // Log all event types for debugging session ID detection
      if (event.type && !event.type.startsWith("tool.") && event.type !== "session.diff") {
        await client.app.log({
          body: { service: "ciel", level: "debug", message: `Event: ${event.type}` },
        });
      }

      if (event.type === "session.created" || event.type === "session.updated" || event.type === "session.status") {
        // Try multiple locations for session ID
        const evt = event as any;
        const rawId = evt?.info?.id ?? evt?.sessionID ?? evt?.sessionId ?? evt?.id ?? evt?.session?.id ?? `s-${Date.now().toString(36)}`;
        sessionId = typeof rawId === "string" ? rawId.slice(0, 8) : "unknown";
        taskCount = 0;
      }

      // Always ensure .ciel/ directory exists (runs on ANY session event)
      if (event.type === "session.created" || event.type === "session.updated" || event.type === "session.status" || event.type === "session.diff") {
        // Initialize .ciel/ directory if missing
        ensureCielDir();
        if (!existsSync(MAP_FILE)) {
          writeFileSync(MAP_FILE, JSON.stringify({ modules: [], lastUpdated: new Date().toISOString() }, null, 2), "utf-8");
        }
        if (!existsSync(MEMORY_FILE)) {
          writeFileSync(MEMORY_FILE, "{}", "utf-8");
        }
        if (!existsSync(PARKING_FILE)) {
          writeFileSync(PARKING_FILE, "# Ciel Parking Lot -- Decouvertes fortuites\n\n", "utf-8");
        }

        await client.app.log({
          body: { service: "ciel", level: "info", message: `Session ${sessionId} started` },
        });

        // Load overlay
        if (existsSync("./ciel-overlay.md")) {
          try {
            const rawOverlay = readFileSync("./ciel-overlay.md", "utf-8");
            overlayContent = rawOverlay.replace(
              /##\s*\S*sensitive[:\s]*true\S*\s*\n([\s\S]*?)(?=\n##\s|\n*$)/gi,
              "## [REDACTED -- sensitive section]\n"
            );
          } catch {
            // silent
          }
        }

        writtenFiles.clear();
        relireSticky = false;
        lastDepthHint = null;
        faireBlocked = null;
        readDocsAttempted = false;
        askWindowUsed = false;
      }

      if (event.type === "session.diff") {
        const diffs = (event as any).diff ?? [];
        for (const fileDiff of diffs) {
          const path = fileDiff?.path ?? "";
          if (CODE_EXT_RE.test(path)) {
            if (writtenFiles.size >= MAX_TRACKED_FILES) {
              const firstKey = writtenFiles.values().next().value!;
              writtenFiles.delete(firstKey);
            }
            writtenFiles.add(path);
            if (writtenFiles.size >= 5 || CRITICAL_FILE_RE.test(path)) {
              relireSticky = true;
            }
          }
        }
      }

      if (event.type === "session.idle") {
        taskCount++;
        lastDepthHint = `CIEL STOP -- META-CRITIQUER: (1) depth match? (2) failure mode? (3) user correction -> learnings? (4) stale branches? (8) map update? (9) parking note?`;
        relireSticky = true;
        faireBlocked = null;
      }

      if (event.type === "session.deleted") {
        const rawId = (event as any).sessionID ?? (event as any).info?.id ?? "unknown";
        const sid = typeof rawId === "string" ? rawId.slice(0, 8) : "unknown";
        const isChild = (event as any).parentSessionId != null;
        await client.app.log({
          body: { service: "ciel", level: "info", message: `Session ${sid} deleted${isChild ? " (subagent child)" : ""}` },
        });
      }

      if (event.type === "session.error") {
        const errorName = (event as any).error?.name ?? "UnknownError";
        const errorMessage = (event as any).error?.message ?? "";
        if (errorName === "ProviderAuthError" || errorName === "MessageAbortedError") {
          await client.app.log({
            body: { service: "ciel", level: "error", message: `${errorName}: ${errorMessage}` },
          });
        }
      }

      if (event.type === "session.compacted") {
        await client.app.log({
          body: { service: "ciel", level: "info", message: `Session ${sessionId} compacted -- state preserved` },
        });
      }
    },

    // ----- SYSTEM TRANSFORM -----
    "experimental.chat.system.transform": async (_input, output) => {
      if (!Array.isArray(output?.system)) return;

      // Mandatory workflow injection (first -- highest priority)
      output.system.push(CIEL_WORKFLOW_INSTRUCTION);

      // Overlay injection
      if (overlayContent) {
        output.system.push(`Project Overlay:\n${overlayContent}`);
      }

      // Load .ciel/map.json if it exists
      if (existsSync(MAP_FILE)) {
        try {
          const mapContent = readFileSync(MAP_FILE, "utf-8");
          output.system.push(`Project Map (.ciel/map.json):\n${mapContent}`);
        } catch {
          // silent
        }
      }

      // Load .ciel/memory.json if it exists
      if (existsSync(MEMORY_FILE)) {
        try {
          const memoryContent = readFileSync(MEMORY_FILE, "utf-8");
          output.system.push(`Session Memory (.ciel/memory.json):\n${memoryContent}`);
        } catch {
          // silent
        }
      }

      // SPIKE mode indicator
      if (isSpikeMode()) {
        output.system.push(
          "[CIEL SPIKE MODE] Exploration/prototype mode active. Quality gates are ASSOUPLIES.\n" +
          "This code is experimental. FIXME/TODO markers required. Must be refactored properly after.\n" +
          "To exit spike mode, remove .ciel/exploration.active"
        );
      }

      // Depth hint
      if (lastDepthHint) {
        output.system.push(lastDepthHint);
      }

      // META-CRITIQUER always injected
      output.system.push(META_CRITIQUER);

      // FAIRE gate blocked
      if (faireBlocked) {
        output.system.push(
          `[CIEL FAIRE GATE TRIGGERED] You just wrote ${faireBlocked.filePath} without a corresponding test file.\n\n` +
          `This means you skipped the Ciel workflow. You MUST now:\n` +
          `1. Classify depth (Trivial/Standard/Critical/Spike)\n` +
          `2. Follow the pipeline: DOCS -> QUOI -> ASK -> AVEC QUOI -> ... -> FAIRE -> RELIRE -> PROUVER -> MEMOIRE -> META\n` +
          `3. Dispatch subagents if required (@ciel-researcher, @ciel-explorer)\n` +
          `4. Write the test file FIRST, then implement\n\n` +
          `Candidates checked: ${faireBlocked.candidates.slice(0, 3).join(", ")}\n\n` +
          `Do NOT continue writing source code until tests exist. Follow the full Ciel pipeline.`
        );
      }

      // RELIRE sticky notice
      if (relireSticky) {
        const changed = Array.from(writtenFiles);
        output.system.push(
          `[CIEL RELIRE REQUIRED] ${changed.length} files changed. Dispatch @ciel-critic MODE=RELIRE -- 3 RISQUES + FIX/ACCEPT/DEFER.`
        );
      }
    },

    // ----- MESSAGES TRANSFORM (model-driven depth classification) -----
    // The model classifies depth based on the pipeline instruction in the system prompt.
    // No regex keyword matching -- the model reasons about the task and decides.
    // This hint is injected so the pipeline instruction remains visible after compaction.
    "experimental.chat.messages.transform": async (_input, output) => {
      const msgs = output?.messages;
      if (!Array.isArray(msgs) || msgs.length === 0) return;

      // Check if there's a user message (any content -- the model classifies it)
      let hasUserMessage = false;
      for (let i = msgs.length - 1; i >= 0 && !hasUserMessage; i--) {
        const m = msgs[i];
        if (m?.info?.role === "user") hasUserMessage = true;
      }
      if (!hasUserMessage) return;

      // Let the model decide the depth based on the pipeline instruction
      lastDepthHint = "[CIEL] Classify depth from the pipeline instruction above.";
    },

    // ----- COMPACTING (cross-session memory -- persist automatically) -----
    "experimental.session.compacting": async (_input, output) => {
      // Persist .ciel/memory.json with current state
      try {
        ensureCielDir();
        const memory = {
          sessionId,
          depthHint: lastDepthHint,
          filesChanged: Array.from(writtenFiles).slice(-20),
          taskCount,
          timestamp: new Date().toISOString(),
        };
        writeFileSync(MEMORY_FILE, JSON.stringify(memory, null, 2), "utf-8");
      } catch {
        // silent
      }

      // Inject context for the LLM to update learnings, map, and parking
      output.context.push(
        "CIEL PRE-COMPACT -- Persist if needed: (1) user corrections -> .ciel/learnings.md, " +
        "(2) project map updates -> .ciel/map.json, " +
        "(3) fortuitous discoveries -> .ciel/parking.md. " +
        "Memory already saved at .ciel/memory.json"
      );
    },

    // ----- BEFORE HOOK -- FAIRE gates -----
    "tool.execute.before": async (input: any, output: any) => {
      if (!["write", "edit"].includes(input.tool)) return;
      const filePath: string = output?.args?.filePath ?? "";
      if (!filePath || !CODE_EXT_RE.test(filePath)) return;

      // Skip for the plugin itself and test files
      if (filePath.includes("ciel.ts") || isTestFile(filePath)) return;

      // Gate 1: TEST-FIRST (RED) -- only block if NOT in SPIKE mode
      if (isSourceFile(filePath) && !sourceFileHasTest(filePath) && !isSpikeMode()) {
        const testCandidates = getTestPathForSource(filePath);
        faireBlocked = { filePath, gate: "test-first", candidates: testCandidates };
      } else {
        faireBlocked = null;
      }

      // Gate 2: CRITICAL FILE WARNING
      if (CRITICAL_FILE_RE.test(filePath)) {
        await client.app.log({
          body: { service: "ciel", level: "warn", message: `CRITICAL FILE: ${filePath} -- stride-analyzer + security-regression-check required` },
        });
      }

      // Gate 3: PARKING LOT -- detect if this is a tangential discovery
      if (filePath.includes("parking") || filePath.includes("FIXME") || filePath.includes("TODO")) {
        writeParkingEntry(`Tangential file noted during task: ${filePath}`);
      }

      // Inject FAIRE reminder into the tool output
      const faireReminder = FAIRE_BEFORE_REMINDER.trim();
      if (typeof output?.output === "string") {
        output.output = faireReminder + "\n" + output.output;
      } else if (output) {
        output.output = faireReminder;
      }
    },

    // ----- AFTER HOOK -- file tracking + map update -----
    "tool.execute.after": async (input: any, output: any) => {
      const toolName: string = input?.tool ?? "";

      // Track ASK window usage for any question tool call
      if (toolName === "question") {
        askWindowUsed = true;
        return; // question tool has no file path, nothing else to do
      }

      // Only process write/edit tools for file tracking
      if (!["write", "edit"].includes(toolName)) return;

      const filePath: string =
        output?.metadata?.filepath ??
        output?.metadata?.filediff?.file ??
        output?.args?.filePath ??
        "";
      if (!filePath || !CODE_EXT_RE.test(filePath)) return;

      if (writtenFiles.size >= MAX_TRACKED_FILES) {
        const firstKey = writtenFiles.values().next().value!;
        writtenFiles.delete(firstKey);
      }
      writtenFiles.add(filePath);
      if (writtenFiles.size >= 5 || CRITICAL_FILE_RE.test(filePath)) {
        relireSticky = true;
      }

      const isCritical = CRITICAL_FILE_RE.test(filePath);
      const spike = isSpikeMode();

      const reminder = isCritical
        ? `\n\n[CIEL CRITIQUE] ${filePath} -- FAIRE gates + stride-analyzer + test-first (RED). Dispatch @ciel-critic MODE=RELIRE.`
        : spike
        ? `\n\n[CIEL SPIKE] ${filePath} -- gates assouplies. Marquer comme experimental (FIXME/TODO).`
        : `\n\n[CIEL] ${filePath} -- FAIRE gates: alternatives, idiomatic, test-first, boy-scout.`;

      if (typeof output?.output === "string") {
        output.output += reminder;
      } else if (output) {
        output.output = reminder.trimStart();
      }

      // Track DOCS phase attempt
      if (!readDocsAttempted && (filePath.endsWith("README.md") || filePath.endsWith("AGENTS.md") || filePath.endsWith("CLAUDE.md") || filePath.includes("ciel-overlay") || filePath.endsWith("docs/"))) {
        readDocsAttempted = true;
      }

      // Update .ciel/map.json with modules discovered during exploration
      if (filePath.endsWith(".ts") || filePath.endsWith(".tsx") || filePath.endsWith(".js") || filePath.endsWith(".py") || filePath.endsWith(".go") || filePath.endsWith(".rs")) {
        try {
          ensureCielDir();
          let map: any = { modules: [], lastUpdated: new Date().toISOString() };
          if (existsSync(MAP_FILE)) {
            map = JSON.parse(readFileSync(MAP_FILE, "utf-8"));
          }
          // Simple heuristic: the directory 2 levels deep is a module
          const parts = filePath.replace(/^\.\//, "").split("/");
          if (parts.length >= 2) {
            const moduleName = parts[parts.length - 2];
            const existingModule = map.modules?.find((m: any) => m.name === moduleName);
            if (!existingModule) {
              map.modules = map.modules || [];
              map.modules.push({
                name: moduleName,
                path: parts.slice(0, -1).join("/"),
                key_files: [{ path: filePath, responsibility: "auto-detected" }],
              });
            } else {
              const existingFile = existingModule.key_files?.find((f: any) => f.path === filePath);
              if (!existingFile) {
                existingModule.key_files = existingModule.key_files || [];
                existingModule.key_files.push({ path: filePath, responsibility: "auto-detected" });
              }
            }
            map.lastUpdated = new Date().toISOString();
            writeFileSync(MAP_FILE, JSON.stringify(map, null, 2), "utf-8");
          }
        } catch {
          // silent
        }
      }
    },
  };
};

export default ciel;
