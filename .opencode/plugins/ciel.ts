// Ciel — OpenCode plugin (v3.5.0)
// Mandatory workflow injection for ciel-plan and ciel-build agents
//
// Injection model:
//   - experimental.chat.system.transform → CIEL WORKFLOW (mandatory) + depth hint + RELIRE + overlay
//   - experimental.chat.messages.transform → depth classification
//   - session.* events → tracking, META-CRITIQUER
//   - tool.execute.after → FAIRE/RELIRE reminders + file tracking

import type { Plugin } from "@opencode-ai/plugin";
import { readFileSync, existsSync } from "fs";

const CODE_EXT_RE = /\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$/i;
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

const ciel: Plugin = async ({ $ }) => {
  const writtenFiles = new Set<string>();
  const remindedFiles = new Set<string>();
  const MAX_TRACKED_FILES = 100;
  let relireSticky = false;
  let lastDepthHint: string | null = null;
  let overlayContent: string | null = null;

  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        const sessionId = event.info?.id?.slice(0, 8) ?? "unknown";
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
        remindedFiles.clear();
        relireSticky = false;
        lastDepthHint = null;
      }

      if (event.type === "session.diff") {
        const diffs = (event as any).diff ?? [];
        for (const fileDiff of diffs) {
          const path = fileDiff?.path ?? "";
          if (CODE_EXT_RE.test(path)) {
            if (writtenFiles.size >= MAX_TRACKED_FILES) {
              const firstKey = writtenFiles.values().next().value!;
              writtenFiles.delete(firstKey);
              remindedFiles.delete(firstKey);
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
        for (let j = parts.length - 1; j >= 0; j--) {
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

    tool: {
      execute: {
        after: async (input, output) => {
          if (!["write", "edit"].includes(input.tool)) return;
          const filePath: string = input.args?.file_path ?? input.args?.path ?? "";
          if (!filePath || !CODE_EXT_RE.test(filePath)) return;

          if (writtenFiles.size >= MAX_TRACKED_FILES) {
            const firstKey = writtenFiles.values().next().value!;
            writtenFiles.delete(firstKey);
            remindedFiles.delete(firstKey);
          }
          writtenFiles.add(filePath);
          if (writtenFiles.size >= 5 || CRITICAL_FILE_RE.test(filePath)) {
            relireSticky = true;
          }

          remindedFiles.add(filePath);
          const isCritical = CRITICAL_FILE_RE.test(filePath);

          const reminder = isCritical
            ? `\n\n[CIEL CRITIQUE] ${filePath} — FAIRE gates + stride-analyzer + test-first (RED). Dispatch @ciel-critic MODE=RELIRE.`
            : `\n\n[CIEL] ${filePath} — FAIRE gates: alternatives, idiomatic, test-first.`;

          if (typeof output?.output === "string") {
            output.output += reminder;
          } else if (output) {
            (output as any).output = reminder.trimStart();
          }
        },
      },
    },
  };
};

export default ciel;
