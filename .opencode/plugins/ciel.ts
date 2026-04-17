// Ciel — OpenCode plugin (v2.7.3)
// Ultra-minimal: no console output, only system/tool injections

import type { Plugin } from "@opencode-ai/plugin";

const CODE_EXT_RE = /\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$/i;
const CRITICAL_FILE_RE = /(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)/;
const CRITICAL_KEYWORD_RE = /\b(auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration.*schema|2fa|mfa|encryption|credential|cookie.*security)\b/i;
const TRIVIAL_KEYWORD_RE = /\b(rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling)\b/i;

const ciel: Plugin = async () => {
  const writtenFiles = new Set<string>();
  const remindedFiles = new Set<string>();
  let relireSticky = false;
  let lastDepthHint: string | null = null;

  const dispatchCounter = new Map<string, number>();
  const INLINE_GATHER_TOOLS = new Set(["bash", "read", "grep", "glob"]);
  const getSessionKey = (input: any): string =>
    input?.sessionID ?? input?.session_id ?? input?.sessionId ?? "__default";

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
    // Silencieux — aucun event handler

    "experimental.chat.system.transform": async (_input, output) => {
      if (!Array.isArray(output?.system)) return;

      if (lastDepthHint) {
        output.system.push(lastDepthHint);
      }
      
      if (relireSticky) {
        output.system.push(`[C] ${writtenFiles.size}f R`);
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

      const { depth } = classifyDepth(prompt);
      lastDepthHint = depth ? `[C] ${depth[0]}` : null;
    },

    tool: {
      execute: {
        before: async (input) => {
          if (!INLINE_GATHER_TOOLS.has(input.tool)) return;
          
          const sid = getSessionKey(input);
          const count = dispatchCounter.get(sid) ?? 0;
          if (count < 5) {
            dispatchCounter.set(sid, count + 1);
            return;
          }

          throw new Error(`[C] STOP:${count}`);
        },

        after: async (input, output) => {
          const sid = getSessionKey(input);
          
          if (input.tool === "task") {
            dispatchCounter.delete(sid);
            return;
          }
          
          if (INLINE_GATHER_TOOLS.has(input.tool)) return;
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

          const reminder = isCritical
            ? `\n[C] ${filePath} !`
            : `\n[C] ${filePath}`;

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
