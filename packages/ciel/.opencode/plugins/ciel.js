"use strict";
// Ciel -- OpenCode plugin (v6)
// Full 16-step pipeline: DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE
//   -> RECHERCHE -> SECURITE -> CODEBASE -> EVALUER -> ASK2
//   -> FAIRE -> ADR -> RELIRE -> PROUVER -> MEMOIRE -> META
//
// Injection model:
//   - shell.env -> inject CIEL_SESSION_ID, CIEL_DEPTH, CIEL_MODE
//   - experimental.chat.system.transform -> CIEL WORKFLOW v6 + overlay + state
//   - experimental.chat.messages.transform -> depth classification
//   - session.* events -> tracking, META-CRITIQUER, RELIRE reminders
//   - tool.execute.before -> FAIRE gates reminder + critical file detection
//   - tool.execute.after -> file tracking + RELIRE trigger + map update
//   - experimental.session.compacting -> persist learnings + map
//   - tool helper -> custom ciel-status tool
Object.defineProperty(exports, "__esModule", { value: true });
const plugin_1 = require("@opencode-ai/plugin");
const fs_1 = require("fs");
const path_1 = require("path");
// ----- Constants -----
const CODE_EXT_RE = /\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$/i;
const TEST_FILE_RE = /(\.test\.|\.spec\.|_test\.|_spec\.)(ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte)$/i;
const CRITICAL_FILE_RE = /(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret|Payment|Account|Credential)/;
const CRITICAL_KEYWORD_RE = /\b(auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration.*schema|2fa|mfa|encryption|credential|cookie.*security)\b/i;
const TRIVIAL_KEYWORD_RE = /\b(rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling)\b/i;
const CIEL_DIR = ".ciel";
const MAP_FILE = (0, path_1.join)(CIEL_DIR, "map.json");
const PARKING_FILE = (0, path_1.join)(CIEL_DIR, "parking.md");
const LEARNINGS_FILE = (0, path_1.join)(CIEL_DIR, "learnings.md");
const EXPLORATION_FLAG = (0, path_1.join)(CIEL_DIR, "exploration.active");
const MEMORY_FILE = (0, path_1.join)(CIEL_DIR, "memory.json");
// ----- V5 WORKFLOW INJECTION -----
const CIEL_WORKFLOW_INSTRUCTION = `
Classify depth internally (Trivial / Standard / Critical / Spike). Follow the matching pipeline.
Do NOT output depth classification in the visible response — track it in your reasoning.
Keep responses concise: only what the user needs to see.

Standard/Critical: DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE -> RECHERCHE -> SECURITE -> CODEBASE -> EVALUER -> ASK2 -> FAIRE -> ADR -> RELIRE -> PROUVER -> MEMOIRE -> META
Trivial: QUOI -> FAIRE -> META
Spike: QUOI -> ASK -> AVEC QUOI -> DIVERGE -> FAIRE (relaxed) -> META

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
function getTestPathForSource(sourcePath) {
    const base = (0, path_1.basename)(sourcePath);
    const dir = (0, path_1.dirname)(sourcePath);
    const nameWithoutExt = base.replace(/\.[^.]+$/, "");
    const ext = base.match(/\.[^.]+$/)?.[0] ?? "";
    const candidates = [
        (0, path_1.join)(dir, `${nameWithoutExt}.test${ext}`),
        (0, path_1.join)(dir, `${nameWithoutExt}.spec${ext}`),
        (0, path_1.join)(dir, `${nameWithoutExt}_test${ext}`),
        (0, path_1.join)(dir, `${nameWithoutExt}_spec${ext}`),
        (0, path_1.join)(dir, "__tests__", `${nameWithoutExt}${ext}`),
        (0, path_1.join)(dir, "test", `${nameWithoutExt}${ext}`),
        (0, path_1.join)(dir, "tests", `${nameWithoutExt}${ext}`),
    ];
    if (ext === ".ts" || ext === ".tsx") {
        candidates.push((0, path_1.join)(dir, `${nameWithoutExt}.test.js`));
        candidates.push((0, path_1.join)(dir, `${nameWithoutExt}.spec.js`));
    }
    return candidates;
}
function sourceFileHasTest(sourcePath) {
    const candidates = getTestPathForSource(sourcePath);
    for (const candidate of candidates) {
        if ((0, fs_1.existsSync)(candidate))
            return true;
    }
    return false;
}
function isTestFile(filePath) {
    return TEST_FILE_RE.test(filePath);
}
function isSourceFile(filePath) {
    return CODE_EXT_RE.test(filePath) && !isTestFile(filePath);
}
function isSpikeMode() {
    return (0, fs_1.existsSync)(EXPLORATION_FLAG);
}
function ensureCielDir() {
    if (!(0, fs_1.existsSync)(CIEL_DIR)) {
        (0, fs_1.mkdirSync)(CIEL_DIR, { recursive: true });
    }
}
function writeParkingEntry(entry) {
    ensureCielDir();
    const timestamp = new Date().toISOString().split("T")[0];
    const formatted = `- [${timestamp}] ${entry}\n`;
    try {
        const existing = (0, fs_1.existsSync)(PARKING_FILE) ? (0, fs_1.readFileSync)(PARKING_FILE, "utf-8") : "";
        const header = "# Ciel Parking Lot -- Decouvertes fortuites\n\n";
        const content = existing.startsWith("#") ? existing : header + existing;
        (0, fs_1.writeFileSync)(PARKING_FILE, content + formatted, "utf-8");
    }
    catch {
        // silent
    }
}
// ----- Plugin -----
const ciel = async ({ client }) => {
    const writtenFiles = new Set();
    const MAX_TRACKED_FILES = 100;
    let relireSticky = false;
    let lastDepthHint = null;
    let overlayContent = null;
    let faireBlocked = null;
    let sessionId = "unknown";
    let taskCount = 0;
    let readDocsAttempted = false;
    let askWindowUsed = false;
    return {
        // ----- CUSTOM TOOLS -----
        tool: {
            "ciel-status": (0, plugin_1.tool)({
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
                const evt = event;
                const rawId = evt?.info?.id ?? evt?.sessionID ?? evt?.sessionId ?? evt?.id ?? evt?.session?.id ?? `s-${Date.now().toString(36)}`;
                sessionId = typeof rawId === "string" ? rawId.slice(0, 8) : "unknown";
                taskCount = 0;
            }
            // Always ensure .ciel/ directory exists (runs on ANY session event)
            if (event.type === "session.created" || event.type === "session.updated" || event.type === "session.status" || event.type === "session.diff") {
                // Initialize .ciel/ directory if missing
                ensureCielDir();
                if (!(0, fs_1.existsSync)(MAP_FILE)) {
                    (0, fs_1.writeFileSync)(MAP_FILE, JSON.stringify({ modules: [], lastUpdated: new Date().toISOString() }, null, 2), "utf-8");
                }
                if (!(0, fs_1.existsSync)(MEMORY_FILE)) {
                    (0, fs_1.writeFileSync)(MEMORY_FILE, "{}", "utf-8");
                }
                if (!(0, fs_1.existsSync)(PARKING_FILE)) {
                    (0, fs_1.writeFileSync)(PARKING_FILE, "# Ciel Parking Lot -- Decouvertes fortuites\n\n", "utf-8");
                }
                await client.app.log({
                    body: { service: "ciel", level: "info", message: `Session ${sessionId} started` },
                });
                // Load overlay
                if ((0, fs_1.existsSync)("./ciel-overlay.md")) {
                    try {
                        const rawOverlay = (0, fs_1.readFileSync)("./ciel-overlay.md", "utf-8");
                        overlayContent = rawOverlay.replace(/##\s*\S*sensitive[:\s]*true\S*\s*\n([\s\S]*?)(?=\n##\s|\n*$)/gi, "## [REDACTED -- sensitive section]\n");
                    }
                    catch {
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
                const diffs = event.diff ?? [];
                for (const fileDiff of diffs) {
                    const path = fileDiff?.path ?? "";
                    if (CODE_EXT_RE.test(path)) {
                        if (writtenFiles.size >= MAX_TRACKED_FILES) {
                            const firstKey = writtenFiles.values().next().value;
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
                const rawId = event.sessionID ?? event.info?.id ?? "unknown";
                const sid = typeof rawId === "string" ? rawId.slice(0, 8) : "unknown";
                const isChild = event.parentSessionId != null;
                await client.app.log({
                    body: { service: "ciel", level: "info", message: `Session ${sid} deleted${isChild ? " (subagent child)" : ""}` },
                });
            }
            if (event.type === "session.error") {
                const errorName = event.error?.name ?? "UnknownError";
                const errorMessage = event.error?.message ?? "";
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
            if (!Array.isArray(output?.system))
                return;
            // Mandatory workflow injection (first -- highest priority)
            output.system.push(CIEL_WORKFLOW_INSTRUCTION);
            // Overlay injection
            if (overlayContent) {
                output.system.push(`Project Overlay:\n${overlayContent}`);
            }
            // Load .ciel/map.json if it exists
            if ((0, fs_1.existsSync)(MAP_FILE)) {
                try {
                    const mapContent = (0, fs_1.readFileSync)(MAP_FILE, "utf-8");
                    output.system.push(`Project Map (.ciel/map.json):\n${mapContent}`);
                }
                catch {
                    // silent
                }
            }
            // Load .ciel/memory.json if it exists
            if ((0, fs_1.existsSync)(MEMORY_FILE)) {
                try {
                    const memoryContent = (0, fs_1.readFileSync)(MEMORY_FILE, "utf-8");
                    output.system.push(`Session Memory (.ciel/memory.json):\n${memoryContent}`);
                }
                catch {
                    // silent
                }
            }
            // SPIKE mode indicator
            if (isSpikeMode()) {
                output.system.push("[CIEL SPIKE MODE] Exploration/prototype mode active. Quality gates are ASSOUPLIES.\n" +
                    "This code is experimental. FIXME/TODO markers required. Must be refactored properly after.\n" +
                    "To exit spike mode, remove .ciel/exploration.active");
            }
            // Depth hint
            if (lastDepthHint) {
                output.system.push(lastDepthHint);
            }
            // META-CRITIQUER always injected
            output.system.push(META_CRITIQUER);
            // FAIRE gate blocked
            if (faireBlocked) {
                output.system.push(`[CIEL FAIRE GATE TRIGGERED] You just wrote ${faireBlocked.filePath} without a corresponding test file.\n\n` +
                    `This means you skipped the Ciel workflow. You MUST now:\n` +
                    `1. Classify depth (Trivial/Standard/Critical/Spike)\n` +
                    `2. Follow the pipeline: DOCS -> QUOI -> ASK -> AVEC QUOI -> ... -> FAIRE -> RELIRE -> PROUVER -> MEMOIRE -> META\n` +
                    `3. Dispatch subagents if required (@ciel-researcher, @ciel-explorer)\n` +
                    `4. Write the test file FIRST, then implement\n\n` +
                    `Candidates checked: ${faireBlocked.candidates.slice(0, 3).join(", ")}\n\n` +
                    `Do NOT continue writing source code until tests exist. Follow the full Ciel pipeline.`);
            }
            // RELIRE sticky notice
            if (relireSticky) {
                const changed = Array.from(writtenFiles);
                output.system.push(`[CIEL RELIRE REQUIRED] ${changed.length} files changed. Dispatch @ciel-critic MODE=RELIRE -- 3 RISQUES + FIX/ACCEPT/DEFER.`);
            }
        },
        // ----- MESSAGES TRANSFORM (depth classification) -----
        // Read the most recent user message and classify depth.
        // Does NOT modify the messages array -- splicing synthetic messages
        // causes "U.parts.length undefined" crashes in the OpenCode SDK
        // (the injected message lacks the expected message shape).
        // Depth hints are injected via experimental.chat.system.transform instead.
        "experimental.chat.messages.transform": async (_input, output) => {
            const msgs = output?.messages;
            if (!Array.isArray(msgs) || msgs.length === 0)
                return;
            // Find the most recent user text part.
            let prompt = "";
            for (let i = msgs.length - 1; i >= 0 && !prompt; i--) {
                const m = msgs[i];
                if (m?.info?.role !== "user")
                    continue;
                const parts = m?.parts;
                if (!Array.isArray(parts))
                    continue;
                for (let j = parts.length - 1; j >= 0; j--) {
                    const p = parts[j];
                    if (p?.type === "text" && typeof p.text === "string") {
                        prompt = p.text;
                        break;
                    }
                }
            }
            if (!prompt)
                return;
            let depth = null;
            let reason = "";
            if (CRITICAL_KEYWORD_RE.test(prompt)) {
                depth = "Critical";
                reason = "auth/security/payment keyword detected";
            }
            else if (TRIVIAL_KEYWORD_RE.test(prompt)) {
                depth = "Trivial";
                reason = "rename/typo/docs keyword detected";
            }
            lastDepthHint = depth
                ? `[CIEL] Depth: ${depth} (${reason}). Route the pipeline accordingly.`
                : null;
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
                (0, fs_1.writeFileSync)(MEMORY_FILE, JSON.stringify(memory, null, 2), "utf-8");
            }
            catch {
                // silent
            }
            // Inject context for the LLM to update learnings, map, and parking
            output.context.push("CIEL PRE-COMPACT -- Persist if needed: (1) user corrections -> .ciel/learnings.md, " +
                "(2) project map updates -> .ciel/map.json, " +
                "(3) fortuitous discoveries -> .ciel/parking.md. " +
                "Memory already saved at .ciel/memory.json");
        },
        // ----- BEFORE HOOK -- FAIRE gates -----
        "tool.execute.before": async (input, output) => {
            if (!["write", "edit"].includes(input.tool))
                return;
            const filePath = output?.args?.filePath ?? "";
            if (!filePath || !CODE_EXT_RE.test(filePath))
                return;
            // Skip for the plugin itself and test files
            if (filePath.includes("ciel.ts") || isTestFile(filePath))
                return;
            // Gate 1: TEST-FIRST (RED) -- only block if NOT in SPIKE mode
            if (isSourceFile(filePath) && !sourceFileHasTest(filePath) && !isSpikeMode()) {
                const testCandidates = getTestPathForSource(filePath);
                faireBlocked = { filePath, gate: "test-first", candidates: testCandidates };
            }
            else {
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
            }
            else if (output) {
                output.output = faireReminder;
            }
        },
        // ----- AFTER HOOK -- file tracking + map update -----
        "tool.execute.after": async (input, output) => {
            const toolName = input?.tool ?? "";
            // Track ASK window usage for any question tool call
            if (toolName === "question") {
                askWindowUsed = true;
                return; // question tool has no file path, nothing else to do
            }
            // Only process write/edit tools for file tracking
            if (!["write", "edit"].includes(toolName))
                return;
            const filePath = output?.metadata?.filepath ??
                output?.metadata?.filediff?.file ??
                output?.args?.filePath ??
                "";
            if (!filePath || !CODE_EXT_RE.test(filePath))
                return;
            if (writtenFiles.size >= MAX_TRACKED_FILES) {
                const firstKey = writtenFiles.values().next().value;
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
            }
            else if (output) {
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
                    let map = { modules: [], lastUpdated: new Date().toISOString() };
                    if ((0, fs_1.existsSync)(MAP_FILE)) {
                        map = JSON.parse((0, fs_1.readFileSync)(MAP_FILE, "utf-8"));
                    }
                    // Simple heuristic: the directory 2 levels deep is a module
                    const parts = filePath.replace(/^\.\//, "").split("/");
                    if (parts.length >= 2) {
                        const moduleName = parts[parts.length - 2];
                        const existingModule = map.modules?.find((m) => m.name === moduleName);
                        if (!existingModule) {
                            map.modules = map.modules || [];
                            map.modules.push({
                                name: moduleName,
                                path: parts.slice(0, -1).join("/"),
                                key_files: [{ path: filePath, responsibility: "auto-detected" }],
                            });
                        }
                        else {
                            const existingFile = existingModule.key_files?.find((f) => f.path === filePath);
                            if (!existingFile) {
                                existingModule.key_files = existingModule.key_files || [];
                                existingModule.key_files.push({ path: filePath, responsibility: "auto-detected" });
                            }
                        }
                        map.lastUpdated = new Date().toISOString();
                        (0, fs_1.writeFileSync)(MAP_FILE, JSON.stringify(map, null, 2), "utf-8");
                    }
                }
                catch {
                    // silent
                }
            }
        },
    };
};
exports.default = ciel;
//# sourceMappingURL=index.js.map