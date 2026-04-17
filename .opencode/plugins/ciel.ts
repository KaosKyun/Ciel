// Ciel — OpenCode plugin (v2.7.2)
// Ported from hooks/*.sh (Claude Code). Pure TS, no shell dependency.
//
// Fixes in v2.7.2:
//   - Added session.idle handler for Stop hook parity (meta-critiquer)
//   - Fixed depth hint injection to be immediate on first turn
//   - Added user prompt detection with immediate system context injection
//
// Injection model (verified against @opencode-ai/plugin/dist/index.d.ts):
//   - experimental.chat.system.transform → push depth hint + sticky RELIRE
//     notice into the system-prompt array each turn. Both are visible to
//     the model on the following turn.
//   - tool.execute.after (write|edit)    → append a per-file FAIRE/RELIRE
//     reminder to the tool result string so the model reads it on its
//     next turn attached to that tool call.
//   - session.created (event)            → console banner + immediate hint
//   - session.idle (event)               → meta-critiquer (Stop hook parity)
//
// The experimental.* hooks may shift between OpenCode releases. Regenerate
// this file with `scripts/build-platforms.sh --target=opencode` after any
// upstream plugin API change.

import type { Plugin } from "@opencode-ai/plugin";

const CODE_EXT_RE = /\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$/i;
const CRITICAL_FILE_RE = /(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)/;
const CRITICAL_KEYWORD_RE = /\b(auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration.*schema|2fa|mfa|encryption|credential|cookie.*security)\b/i;
const TRIVIAL_KEYWORD_RE = /\b(rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling)\b/i;

const ciel: Plugin = async ({ $, directory, worktree }) => {
  // Per-session state. Reset when the plugin module is re-instantiated
  // (once per OpenCode session).
  const writtenFiles = new Set<string>();
  const remindedFiles = new Set<string>();
  let relireSticky = false;
  let lastDepthHint: string | null = null;
  let sessionStartTime = Date.now();
  let inlineCallCount = 0;

  // Dispatch-gate counter (v2.5.1) — Claude Code parity
  const dispatchCounter = new Map<string, number>();
  const INLINE_GATHER_TOOLS = new Set(["bash", "read", "grep", "glob"]);
  const getSessionKey = (input: any): string =>
    input?.sessionID ?? input?.session_id ?? input?.sessionId ?? "__default";

  // Depth classification helper
  const classifyDepth = (prompt: string): { depth: string | null; reason: string } => {
    if (CRITICAL_KEYWORD_RE.test(prompt)) {
      return { depth: "Critical", reason: "auth/security/payment keyword detected" };
    }
    if (TRIVIAL_KEYWORD_RE.test(prompt)) {
      return { depth: "Trivial", reason: "rename/typo/docs keyword detected" };
    }
    return { depth: null, reason: "" };
  };

  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        sessionStartTime = Date.now();
        console.log("[CIEL] Session active — /ciel for orchestrator");
      }

      // Session idle — compact meta-critiquer (single line to avoid overflow)
      if (event.type === "session.idle") {
        const changed = writtenFiles.size;
        const status = relireSticky ? "RELIRE✓" : "RELIRE✗";
        console.log(`[CIEL] META-CRITIQUER: ${changed} files, ${inlineCallCount} inline calls, ${status}`);
      }
    },

    // Per-turn system-prompt injection
    "experimental.chat.system.transform": async (_input, output) => {
      if (!Array.isArray(output?.system)) return;

      // FIX #2: Always inject depth hint if available (immediate on first turn)
      if (lastDepthHint) {
        output.system.push(lastDepthHint);
      }
      
      if (relireSticky) {
        output.system.push(
          `[CIEL] ${writtenFiles.size} files changed — dispatch @ciel-critic MODE=RELIRE`
        );
      }
    },

    // FIX #3: Better immediate depth detection with system injection attempt
    "experimental.chat.messages.transform": async (_input, output) => {
      const msgs = output?.messages;
      if (!Array.isArray(msgs) || msgs.length === 0) return;

      // Find the most recent user text part
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

      // Immediate depth classification
      const { depth, reason } = classifyDepth(prompt);
      
      if (depth) {
        lastDepthHint = `[CIEL] Depth: ${depth}`;
      } else {
        lastDepthHint = null;
      }
    },

    tool: {
      execute: {
        before: async (input, output) => {
          if (!INLINE_GATHER_TOOLS.has(input.tool)) return;
          
          inlineCallCount++; // Track for meta-critiquer
          
          const sid = getSessionKey(input);
          const count = dispatchCounter.get(sid) ?? 0;
          if (count < 5) return;

          const msg = `[CIEL] HARD-STOP: ${count} inline calls — dispatch @ciel-researcher/@ciel-explorer now`;
          console.error(msg);
          
          if (output && typeof output === "object") {
            (output as any).args = { __ciel_hardstop__: msg };
          }
          throw new Error(msg);
        },

        after: async (input, output) => {
          const sid = getSessionKey(input);
          
          if (input.tool === "task") {
            dispatchCounter.delete(sid);
            return;
          }
          
          if (INLINE_GATHER_TOOLS.has(input.tool)) {
            dispatchCounter.set(sid, (dispatchCounter.get(sid) ?? 0) + 1);
            return;
          }

          if (!["write", "edit"].includes(input.tool)) return;
          
          const args: any = (input as any).args ?? {};
          const filePath: string = args.file_path ?? args.path ?? "";
          if (!filePath || !CODE_EXT_RE.test(filePath)) return;

          writtenFiles.add(filePath);

          const isCritical = CRITICAL_FILE_RE.test(filePath);
          if (writtenFiles.size >= 3 || isCritical) {
            relireSticky = true;
          }

          if (remindedFiles.has(filePath)) return;
          remindedFiles.add(filePath);

          // Compact reminders (single line to avoid terminal overflow)
          const reminder = isCritical
            ? `\n\n[CIEL] ${filePath} — CRITICAL: FAIRE + STRIDE + RELIRE required`
            : `\n\n[CIEL] ${filePath} — FAIRE gates: check alternatives, idiomatic, tests`;

          if (typeof output?.output === "string") {
            output.output += reminder;
          } else if (output) {
            (output as any).output = reminder.trimStart();
          }
          
          // Trigger meta-critiquer after 3+ files changed (task boundary simulation)
          if (writtenFiles.size >= 3 && !relireSticky) {
            console.log(`[CIEL] META-CRITIQUER triggered: ${writtenFiles.size} files changed — dispatch @ciel-critic MODE=RELIRE`);
          }
        },
      },
    },
  };
};

export default ciel;
