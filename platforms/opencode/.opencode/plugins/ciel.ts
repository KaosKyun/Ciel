// Ciel — OpenCode plugin (v6.16.3)
// Ciel v5 plugin. Pure TS, no shell dependency.
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

  // v3.3.0 — dispatch-gate counter removed. The per-call [CIEL COUNTER: N/15]
  // systemMessage was pure noise on every inline tool call. Depth routing
  // still happens via experimental.chat.system.transform + the sticky
  // RELIRE notice; users dispatch @ciel-* explicitly when they need one.

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
      if (!Array.isArray(output?.system)) return;
      // SKILLS (mandatory — every turn). Must precede depth/RELIRE so it's read first.
      output.system.push(
        "[CIEL SKILL DISPATCH] Before responding to ANY task, scan the list of available skills. You MUST call Skill() for EVERY domain skill relevant to this task — analysis, planning, debugging, or coding. Skip = pipeline violation. If no skill matches, state it and continue."
      );
      if (lastDepthHint) {
        output.system.push(lastDepthHint);
      }
      if (relireSticky) {
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
        // Append FAIRE/RELIRE reminder to the tool result text. OpenCode's
        // tool.execute.after output is { title, output, metadata } — the
        // `output` field is the tool result string surfaced to the model.
        // Mutation here is the ONLY way to inject per-tool context.
        after: async (input, output) => {
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
            ? `\n\n[CIEL CRITIQUE] ${filePath} — SKILLS loaded? FAIRE gates + stride-analyzer + test-first (RED). Dispatch @ciel-critic MODE=RELIRE before declaring done.`
            : `\n\n[CIEL] ${filePath} — SKILLS loaded? FAIRE gates: alternatives, idiomatic, test-first. Ensure @ciel-researcher + @ciel-explorer ran.`;

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
