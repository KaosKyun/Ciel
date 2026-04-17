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
  const writtenFiles = new Set<string>();

  return {
    event: async ({ event }) => {
      // Hook: session start — banner log (idempotent, no side effects)
      if (event.type === "session.created") {
        console.log("[CIEL] Session started — depth-aware reasoning active. Use /ciel, @ciel-researcher, @ciel-explorer, @ciel-critic.");
      }
    },

    chat: {
      // chat.params fires before the model processes a user prompt.
      // Inject depth classification hint as a system message.
      params: async (input, output) => {
        const last = input.message?.parts?.findLast?.((p: any) => p.type === "text");
        const prompt: string = last?.text ?? "";
        if (!prompt) return;

        let depth = "Standard";
        let reason = "default";
        if (CRITICAL_KEYWORD_RE.test(prompt)) {
          depth = "Critical";
          reason = "auth/security/payment keyword detected";
        } else if (TRIVIAL_KEYWORD_RE.test(prompt)) {
          depth = "Trivial";
          reason = "rename/typo/docs keyword detected";
        }

        const hint = `[CIEL] Depth hint: ${depth} (${reason}). Invoke depth-classifier reasoning if ambiguous before routing the pipeline.`;
        if (output?.system && Array.isArray(output.system)) {
          output.system.push(hint);
        }
      },
    },

    tool: {
      execute: {
        before: async (input, output) => {
          if (!["write", "edit"].includes(input.tool)) return;
          const filePath: string = output?.args?.file_path ?? output?.args?.path ?? "";
          if (!filePath || !CODE_EXT_RE.test(filePath)) return;

          const isCritical = CRITICAL_FILE_RE.test(filePath);
          const msg = isCritical
            ? `[CIEL CRITIQUE] ${filePath} — Before writing: (1) faire-gatekeeper gates checked (2) stride-analyzer run (3) flux-narrator completed (4) test written FIRST (RED). Dispatch @ciel-critic MODE=RELIRE after writing is mandatory.`
            : `[CIEL] ${filePath} — Invoke faire-gatekeeper gates (alternatives, idiomatic, quality, removal, test-first). If Standard/Critical: ensure @ciel-researcher + @ciel-explorer were dispatched before this write.`;

          console.log(msg);
          writtenFiles.add(filePath);
        },

        after: async (input, output) => {
          if (!["write", "edit"].includes(input.tool)) return;
          const filePath: string = output?.args?.file_path ?? output?.args?.path ?? "";
          if (!filePath || !CODE_EXT_RE.test(filePath)) return;

          writtenFiles.add(filePath);
          const changed = Array.from(writtenFiles);
          const relireRequired = changed.length >= 3 || CRITICAL_FILE_RE.test(filePath);

          const msg = relireRequired
            ? `[CIEL RELIRE REQUIRED] ${filePath} just written. Dispatch @ciel-critic: MODE=RELIRE, CHANGED_FILES=[${changed.join(", ")}]. Required: 3 RISQUES (functional + imports + data) + FIX/ACCEPT/DEFER. Do not continue before verdict.`
            : `[CIEL RELIRE] ${filePath} written. Run relire-critic inline (3 RISQUES + FIX/ACCEPT/DEFER) before next write.`;

          console.log(msg);
        },
      },
    },
  };
};

export default ciel;
