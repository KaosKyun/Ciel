// Ciel — OpenCode plugin (v3.2.0)
// Ported from hooks/*.sh (Claude Code). Pure TS, no shell dependency.
//
// Injection model (verified against @opencode-ai/plugin/dist/index.d.ts):
//   - experimental.chat.system.transform → push depth hint + sticky RELIRE
//     notice into the system-prompt array each turn. Both are visible to
//     the model on the following turn.
//   - tool.execute.after (write|edit)    → append a per-file FAIRE/RELIRE
//     reminder to the tool result string so the model reads it on its
//     next turn attached to that tool call.
//   - session.created (event)            → console banner only (no
//     model-visible injection needed at session start).
//
// Why not tool.execute.before? Its output shape is { args } only — no way
// to inject context, and console.log goes to terminal/plugin log, not the
// model.
//
// Why not chat.params? Its output has no `system` field; pushing to it
// is a silent no-op. Depth hints belong in experimental.chat.system.transform.
//
// The experimental.* hooks may shift between OpenCode releases. Regenerate
// this file with `scripts/build-platforms.sh --target=opencode` after any
// upstream plugin API change.

import type { Plugin } from "@opencode-ai/plugin";

const CODE_EXT_RE = /\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte|sql)$/i;
const CRITICAL_FILE_RE = /(auth|Auth|security|Security|Route|Service|Controller|Repository|Gateway|Middleware|Proxy|Token|Session|Password|Secret)/;
const CRITICAL_KEYWORD_RE = /\b(auth|authenti|author|jwt|oauth|password|secret|token|session|payment|credit.card|migration.*schema|2fa|mfa|encryption|credential|cookie.*security)\b/i;
const TRIVIAL_KEYWORD_RE = /\b(rename|typo|copyright|comment|readme|1-line|one.line|fix.typo|spelling)\b/i;

const ciel: Plugin = async ({ $ }) => {
  // Per-session state. Reset when the plugin module is re-instantiated
  // (once per OpenCode session).
  const writtenFiles = new Set<string>();
  const remindedFiles = new Set<string>();
  let relireSticky = false; // once true, every turn re-injects the RELIRE notice
  let lastDepthHint: string | null = null;

  // Dispatch-gate counter (v2.5.1) — Claude Code parity. Per-session count
  // of inline bash|read|grep|glob calls; reset on task dispatch. At 5+ the
  // tool.execute.before hook throws to reject the next tool call AND
  // mutates output.args into an invalid form so the tool fails loud even
  // if throw-to-reject is swallowed by the runtime (defense in depth).
  //
  // Session key: best-effort from any input field that looks like a
  // session id; falls back to a single "__default" bucket if absent.
  // (input shape for tool.execute.* hooks is not fully documented; one
  // bucket means the counter is effectively global when no sessionID is
  // exposed — acceptable because OpenCode runs one session per plugin
  // module instance in practice.)
  const dispatchCounter = new Map<string, number>();
  const INLINE_GATHER_TOOLS = new Set(["bash", "read", "grep", "glob"]);
  const getSessionKey = (input: any): string =>
    input?.sessionID ?? input?.session_id ?? input?.sessionId ?? "__default";

  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        // Terminal-only banner. Model context is handled by the transform hook.
        console.log("[CIEL] Session started — depth-aware reasoning active. Use /ciel, @ciel-researcher, @ciel-explorer, @ciel-critic.");
      }
    },

    // Per-turn system-prompt injection. This hook runs on every model turn
    // so we get a reliable "inject once per turn" surface without having to
    // manage cross-hook message state ourselves.
    "experimental.chat.system.transform": async (_input, output) => {
      if (lastDepthHint && Array.isArray(output?.system)) {
        output.system.push(lastDepthHint);
      }
      if (relireSticky && Array.isArray(output?.system)) {
        const changed = Array.from(writtenFiles);
        output.system.push(
          `[CIEL RELIRE REQUIRED] ${changed.length} code files changed this session (${changed.slice(0, 6).join(", ")}${changed.length > 6 ? ", ..." : ""}). Dispatch @ciel-critic MODE=RELIRE — 3 RISQUES + FIX/ACCEPT/DEFER. Do not declare done before verdict.`
        );
      }
    },

    // Full message-list transform — read the most recent user text and
    // reclassify depth every turn. Keeps lastDepthHint fresh; the actual
    // injection happens in the system.transform hook above.
    "experimental.chat.messages.transform": async (_input, output) => {
      const msgs = output?.messages;
      if (!Array.isArray(msgs) || msgs.length === 0) return;
      // Find the most recent user text part.
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
        ? `[CIEL] Depth: ${depth} (${reason}). Route the pipeline accordingly.`
        : null;
    },

    tool: {
      execute: {
        // Dispatch-gate counter (v2.5.1) — Claude Code parity. Throws at
        // N>=5 to reject the 6th+ inline bash|read|grep|glob call AND
        // mutates args to a clearly-invalid form so the tool fails loud
        // if the runtime swallows the throw. WARNING: OpenCode's
        // throw-from-before semantic is not formally documented — the
        // args mutation is the belt-and-suspenders fallback.
        before: async (input, output) => {
          if (!INLINE_GATHER_TOOLS.has(input.tool)) return;
          const sid = getSessionKey(input);
          const count = dispatchCounter.get(sid) ?? 0;
          if (count < 5) return;

          const msg = `[CIEL HARD-STOP] Dispatch gate exceeded (${count} inline calls without a Task() on a Standard+ task). Dispatch @ciel-researcher / @ciel-explorer / @ciel-critic now with [ASSUMED] markers for unresolved inputs. Further investigation belongs INSIDE the fork, not in the main session.`;
          console.error(msg);
          // Belt: nullify the tool args so the tool call errors out if
          // throw is swallowed. OpenCode tool.execute.before output is
          // { args } — mutating it flows to the tool invocation.
          if (output && typeof output === "object") {
            (output as any).args = { __ciel_hardstop__: msg };
          }
          // Suspenders: throw to reject (assumed semantic).
          throw new Error(msg);
        },

        // Append FAIRE/RELIRE reminder to the tool result text. OpenCode's
        // tool.execute.after output is { title, output, metadata } — the
        // `output` field is the tool result string surfaced to the model.
        // Mutation here is the ONLY way to inject per-tool context.
        //
        // Also maintains the v2.5.1 dispatch-gate counter: increment on
        // bash|read|grep|glob, reset on task. Runs BEFORE the existing
        // write|edit branch; both paths are independent (same handler,
        // different early-return gates).
        after: async (input, output) => {
          // Counter maintenance — incremented on tool SUCCESS (post-hoc),
          // read by tool.execute.before next time around.
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
          if (writtenFiles.size >= 5 || isCritical) {
            relireSticky = true;
          }

          // Per-file FAIRE reminder fires once per path to avoid burning
          // ~50 tokens × N edits on the same file.
          if (remindedFiles.has(filePath)) return;
          remindedFiles.add(filePath);

          const reminder = isCritical
            ? `\n\n[CIEL CRITIQUE] ${filePath} — FAIRE gates + stride-analyzer + flux-narrator + test-first (RED). Dispatch @ciel-critic MODE=RELIRE before declaring done.`
            : `\n\n[CIEL] ${filePath} — FAIRE gates: alternatives, idiomatic, test-first. Ensure @ciel-researcher + @ciel-explorer ran.`;

          if (typeof output?.output === "string") {
            output.output += reminder;
          } else if (output) {
            // Defensive: if output.output is missing/nullish, create it so
            // the reminder still lands on the model.
            (output as any).output = reminder.trimStart();
          }
        },
      },
    },
  };
};

export default ciel;
