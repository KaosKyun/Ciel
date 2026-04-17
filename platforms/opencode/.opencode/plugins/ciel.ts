// Ciel — OpenCode plugin
// Ported from hooks/*.sh (Claude Code). Pure TS, no shell dependency.
//
// Events handled:
//   - tool.execute.before  (matcher: write|edit) → FAIRE gates reminder
//   - tool.execute.after   (matcher: write|edit) → RELIRE dispatch reminder
//   - chat.params                                → depth pre-classification hint
//
// Never blocks. Only injects reminders via output.metadata / context.

import type { Plugin } from "@opencode-ai/plugin";

const CODE_EXT_RE = /\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$/i;
const CRITICAL_FILE_RE = /(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)/;
const CRITICAL_KEYWORD_RE = /\b(auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration.*schema|2fa|mfa|encryption|credential|cookie.*security)\b/i;
const TRIVIAL_KEYWORD_RE = /\b(rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling)\b/i;

const ciel: Plugin = async ({ $ }) => {
  // Track which files were already reminded this session to avoid duplicate
  // reminders on repeated edits (each reminder = ~50 tokens in context).
  const writtenFiles = new Set<string>();
  const remindedFiles = new Set<string>();
  let relireBlockDispatched = false;

  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        console.log("[CIEL] Session started — depth-aware reasoning active. Use /ciel, @ciel-researcher, @ciel-explorer, @ciel-critic.");
      }
    },

    chat: {
      // Only inject a depth hint when the classifier finds a signal (Critical or
      // Trivial keyword). Skip the "Standard default" case — a neutral hint adds
      // tokens without guiding the model.
      params: async (input, output) => {
        const last = input.message?.parts?.findLast?.((p: any) => p.type === "text");
        const prompt: string = last?.text ?? "";
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
        if (!depth) return;

        const hint = `[CIEL] Depth: ${depth} (${reason}). Route the pipeline accordingly.`;
        if (output?.system && Array.isArray(output.system)) {
          output.system.push(hint);
        }
      },
    },

    tool: {
      execute: {
        // Pre-write reminder fires once per file. On non-critical files, a tight
        // single-line hint; on critical files, the full STRIDE/FAIRE reminder.
        before: async (input, output) => {
          if (!["write", "edit"].includes(input.tool)) return;
          const filePath: string = output?.args?.file_path ?? output?.args?.path ?? "";
          if (!filePath || !CODE_EXT_RE.test(filePath)) return;
          if (remindedFiles.has(filePath)) return;
          remindedFiles.add(filePath);

          const isCritical = CRITICAL_FILE_RE.test(filePath);
          const msg = isCritical
            ? `[CIEL CRITIQUE] ${filePath} — FAIRE gates + stride-analyzer + flux-narrator + test-first (RED). Dispatch @ciel-critic MODE=RELIRE after this write.`
            : `[CIEL] ${filePath} — FAIRE gates: alternatives, idiomatic, test-first. Ensure @ciel-researcher + @ciel-explorer ran.`;
          console.log(msg);
        },

        // Post-write RELIRE reminder: emit AT MOST ONCE per session once the
        // threshold is reached (3+ files or a critical file touched). Suppresses
        // the per-file repeat noise that otherwise burns ~50 tokens × N writes.
        after: async (input, output) => {
          if (!["write", "edit"].includes(input.tool)) return;
          const filePath: string = output?.args?.file_path ?? output?.args?.path ?? "";
          if (!filePath || !CODE_EXT_RE.test(filePath)) return;

          writtenFiles.add(filePath);
          if (relireBlockDispatched) return;

          const changed = Array.from(writtenFiles);
          const relireRequired = changed.length >= 3 || CRITICAL_FILE_RE.test(filePath);
          if (!relireRequired) return;

          relireBlockDispatched = true;
          console.log(`[CIEL RELIRE REQUIRED] ${changed.length} files changed (${changed.join(", ")}). Dispatch @ciel-critic MODE=RELIRE now — 3 RISQUES + FIX/ACCEPT/DEFER. Do not continue before verdict.`);
        },
      },
    },
  };
};

export default ciel;
