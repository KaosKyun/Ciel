// Ciel — OpenCode plugin (v3.7.0)
// Mandatory workflow injection for ciel-plan and ciel-build agents
//
// Injection model:
//   - experimental.chat.system.transform → CIEL WORKFLOW (mandatory) + depth hint + RELIRE + overlay + faireBlocked
//   - experimental.chat.messages.transform → depth classification
//   - session.* events → tracking, META-CRITIQUER, RELIRE reminders
//   - tool.execute.before → FAIRE gates reminder (NON-BLOCKING: injects into tool output)
//   - tool.execute.after → file tracking + RELIRE trigger

import type { Plugin } from "@opencode-ai/plugin";
import { readFileSync, existsSync } from "fs";
import { basename, dirname, join } from "path";

const CODE_EXT_RE = /\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$/i;
const TEST_FILE_RE = /\.(test|spec|_test|_spec)\.(ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte)$/i;
const CRITICAL_FILE_RE = /(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)/;
const CRITICAL_KEYWORD_RE = /\b(auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration\.schema|2fa|mfa|encryption|credential|cookie.*security)\b/i;
const TRIVIAL_KEYWORD_RE = /\b(rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling)\b/i;

// MANDATORY WORKFLOW INJECTION — Added to EVERY system prompt
const CIEL_WORKFLOW_INSTRUCTION = `
[CIEL MANDATORY WORKFLOW — ALWAYS ACTIVE]

You are using Ciel deep-reasoning workflow. For EVERY user message:

1. **ALWAYS classify depth first** (Trivial/Standard/Critical)
2. **ALWAYS follow the pipeline**:
   - Trivial: Direct response
   - Standard: QUOI → AVEC QUOI → RECHERCHE → CODEBASE → PLAN → FAIRE → RELIRE → PROUVER
   - Critical: Same + STRIDE analysis + security-regression-check

3. **ALWAYS dispatch subagents** when required:
   - @ciel-researcher: External libs, APIs, unknown patterns
   - @ciel-explorer: Codebase analysis (3+ files)
   - @ciel-critic: 5+ files changed OR critical files (auth/, security/, *Service.*)

4. **NEVER skip gates**: test-first, alternatives, idiomatic, quality, removal

This is NOT optional. Every conversation must follow this workflow.
`;

// FAIRE gate reminder injected BEFORE every write/edit via tool.execute.before
const FAIRE_BEFORE_REMINDER = `
[CIEL FAIRE GATES — BEFORE WRITE/EDIT]
Before executing this write/edit, verify:
1. TEST-FIRST (RED): Have you written tests FIRST? If this is source code, a corresponding test file must exist or be created first.
2. ALTERNATIVES: Can you justify X over Y in a comment or commit message?
3. IDIOMATIC: Are you using the framework's idiomatic pattern? If bypassing, justify why.
4. QUALITY: complexity < 15, nesting < 4, functions < 50 lines.
5. REMOVAL: If deleting code — who uses it? What replaces it? What degrades?
`;

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

const ciel: Plugin = async ({ $ }) => {
  const writtenFiles = new Set<string>();
  const MAX_TRACKED_FILES = 100;
  let relireSticky = false;
  let lastDepthHint: string | null = null;
  let overlayContent: string | null = null;
  let faireBlocked: { filePath: string; gate: string; candidates: string[] } | null = null;

  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        const rawId = (event as any).info?.id ?? (event as any).sessionID ?? "unknown";
        const sessionId = typeof rawId === "string" ? rawId.slice(0, 8) : "unknown";
        console.log(`[CIEL] Session ${sessionId} started`);

        if (existsSync("./ciel-overlay.md")) {
          try {
            const rawOverlay = readFileSync("./ciel-overlay.md", "utf-8");
            overlayContent = rawOverlay.replace(
              /##\s*\S*sensitive[:\s]*true\S*\s*\n([\s\S]*?)(?=\n##\s|\n*$)/gi,
              "## [REDACTED — sensitive section]\n"
            );
          } catch {
            // Silent fail
          }
        }

        writtenFiles.clear();
        relireSticky = false;
        lastDepthHint = null;
        faireBlocked = null;
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
        lastDepthHint = "CIEL STOP — 30s META-CRITIQUER: (1) depth match? (2) failure mode? (3) user correction → overlay? (4) stale branches?";
        relireSticky = true;
        faireBlocked = null;
      }

      if (event.type === "session.error") {
        const errorName = (event as any).error?.name ?? "UnknownError";
        const errorMessage = (event as any).error?.message ?? "";
        if (errorName === "ProviderAuthError" || errorName === "MessageAbortedError") {
          console.log(`[CIEL ERROR] ${errorName}: ${errorMessage}`);
        }
      }
    },

    "experimental.chat.system.transform": async (_input, output) => {
      if (!Array.isArray(output?.system)) return;

      // ⚠️ MANDATORY WORKFLOW INJECTION (FIRST — highest priority)
      output.system.push(CIEL_WORKFLOW_INSTRUCTION);

      // Overlay injection
      if (overlayContent) {
        output.system.push(`Project Overlay:\n${overlayContent}`);
      }

      // Depth hint
      if (lastDepthHint) {
        output.system.push(lastDepthHint);
      }

      // FAIRE gate blocked — inject full Ciel workflow trigger
      if (faireBlocked) {
        output.system.push(
          `[CIEL FAIRE GATE TRIGGERED] You just wrote ${faireBlocked.filePath} without a corresponding test file.\n\n` +
          `This means you skipped the Ciel workflow. You MUST now:\n` +
          `1. Classify depth (Trivial/Standard/Critical)\n` +
          `2. Follow the pipeline: QUOI → AVEC QUOI → RECHERCHE → CODEBASE → PLAN → FAIRE → RELIRE → PROUVER\n` +
          `3. Dispatch subagents if required (@ciel-researcher for external libs, @ciel-explorer for 3+ files)\n` +
          `4. Write the test file FIRST, then implement\n\n` +
          `Candidates checked: ${faireBlocked.candidates.slice(0, 3).join(", ")}\n\n` +
          `Do NOT continue writing source code until tests exist. Follow the full Ciel pipeline.`
        );
      }

      // RELIRE sticky notice
      if (relireSticky) {
        const changed = Array.from(writtenFiles);
        output.system.push(
          `[CIEL RELIRE REQUIRED] ${changed.length} files changed. Dispatch @ciel-critic MODE=RELIRE — 3 RISQUES + FIX/ACCEPT/DEFER.`
        );
      }
    },

    "experimental.chat.messages.transform": async (_input, output) => {
      const msgs = output?.messages;
      if (!Array.isArray(msgs) || msgs.length === 0) return;

      let prompt = "";
      for (let i = msgs.length - 1; i >= 0 && !prompt; i--) {
        const m = msgs[i];
        if (m?.info?.role !== "user") continue;
        const parts = m?.parts;
        if (!Array.isArray(parts)) continue;
        for (let j = parts.length - 1; j >= 0; j++) {
          const p = parts[j];
          if (p?.type === "text" && typeof p.text === "string") {
            prompt = p.text;
            break;
          }
        }
      }
      if (!prompt) return;

      let depth: string | null = null;
      let reason = "";
      if (CRITICAL_KEYWORD_RE.test(prompt)) {
        depth = "Critical";
        reason = "auth/security/payment keyword detected";
      } else if (TRIVIAL_KEYWORD_RE.test(prompt)) {
        depth = "Trivial";
        reason = "rename/typo/docs keyword detected";
      }

      lastDepthHint = depth
        ? `[CIEL] Depth: ${depth} (${reason}). Route accordingly.`
        : null;
    },

    "experimental.session.compacting": async (_input, output) => {
      output.context.push(
        "CIEL PRE-COMPACT — Invoke learnings-capture skill NOW. Persist: (1) user corrections, (2) failure modes, (3) failed approaches + why they failed."
      );
    },

    // ─── BEFORE HOOK — FAIRE gates reminder (NON-BLOCKING) ───
    // Injects FAIRE checklist into tool output so the model sees it before writing.
    // Also sets faireBlocked flag if test-first gate fails (picked up by system.transform).
    "tool.execute.before": async (input: any, output: any) => {
      if (!["write", "edit"].includes(input.tool)) return;
      const filePath: string = output?.args?.filePath ?? "";
      if (!filePath || !CODE_EXT_RE.test(filePath)) return;

      // Skip for the plugin itself and test files
      if (filePath.includes("ciel.ts") || isTestFile(filePath)) return;

      // Gate 1: TEST-FIRST (RED) — set flag if writing source without test
      if (isSourceFile(filePath) && !sourceFileHasTest(filePath)) {
        const testCandidates = getTestPathForSource(filePath);
        faireBlocked = { filePath, gate: "test-first", candidates: testCandidates };
      } else {
        faireBlocked = null;
      }

      // Gate 2: CRITICAL FILE WARNING
      if (CRITICAL_FILE_RE.test(filePath)) {
        console.log(
          `[CIEL CRITICAL FILE] ${filePath} — stride-analyzer + security-regression-check required.`
        );
      }

      // Inject FAIRE reminder into the tool output
      const faireReminder = FAIRE_BEFORE_REMINDER.trim();
      if (typeof output?.output === "string") {
        output.output = faireReminder + "\n" + output.output;
      } else if (output) {
        output.output = faireReminder;
      }
    },

    // ─── AFTER HOOK — file tracking + RELIRE trigger ───
    "tool.execute.after": async (input: any, output: any) => {
      if (!["write", "edit"].includes(input.tool)) return;
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

      const reminder = isCritical
        ? `\n\n[CIEL CRITIQUE] ${filePath} — FAIRE gates + stride-analyzer + test-first (RED). Dispatch @ciel-critic MODE=RELIRE.`
        : `\n\n[CIEL] ${filePath} — FAIRE gates: alternatives, idiomatic, test-first.`;

      if (typeof output?.output === "string") {
        output.output += reminder;
      } else if (output) {
        output.output = reminder.trimStart();
      }
    },
  };
};

export default ciel;
