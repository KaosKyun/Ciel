// Ciel — OpenCode Plugin
// Replicates the pre-write-gate and post-write-relire hooks from Claude Code.
// Installed automatically by the Ciel installer into .opencode/plugins/
//
// Hooks:
//   tool.execute.before (write/edit) — injects FLUX/SECURITE reminder on code files
//   tool.execute.after  (write/edit) — injects RELIRE obligation on code files

import type { Plugin } from "@opencode-ai/plugin";

interface WriteToolArgs {
  filePath?: string;
  file_path?: string;
  path?: string;
  content?: string;
}

interface ToolMetadata {
  [key: string]: string | number | boolean;
}

const CODE_EXTENSIONS =
  /\.(kt|java|ts|tsx|js|jsx|py|go|rs|rb|php|cs|cpp|c|swift|scala|vue|svelte)$/;

const CRITICAL_PATTERNS =
  /(?:auth|security|route|service|controller|repository|gateway|middleware|proxy|token|session|password|secret)/i;

function isCodeFile(filePath: string | undefined): boolean {
  return !!filePath && CODE_EXTENSIONS.test(filePath);
}

function isCriticalFile(filePath: string): boolean {
  return CRITICAL_PATTERNS.test(filePath);
}

function getFilePath(args: WriteToolArgs): string | undefined {
  return args?.filePath || args?.file_path || args?.path;
}

export const id = "ciel";

export const server: Plugin = async ({ client }) => {
  const log = (message: string) =>
    client.app.log({
      body: { service: "ciel", level: "info", message },
    });

  return {
    // ── Pre-write gate ──────────────────────────────────────────────
    // Before any write/edit tool, inject a FLUX/SECURITE reminder.
    // Never blocks — informational only.
    "tool.execute.before": async (
      input: { tool: string; sessionID: string; callID: string },
      output: { args: WriteToolArgs }
    ) => {
      if (input.tool !== "write" && input.tool !== "edit") return;

      const filePath = getFilePath(output.args);
      if (!isCodeFile(filePath)) return;

      if (isCriticalFile(filePath!)) {
        log(
          `[CRITIQUE] ${filePath} — Before writing: (1) SECURITE STRIDE done? (2) FLUX narrated? (3) Dispatch @ciel-critic after FAIRE mandatory.`
        );
      } else {
        log(
          `${filePath} — FLUX narrated for this change? If Standard/Critical: @ciel-researcher + @ciel-explorer dispatched?`
        );
      }
    },

    // ── Post-write relire ───────────────────────────────────────────
    // After any write/edit on a code file, inject a RELIRE obligation
    // into the tool output so the LLM sees it in context.
    "tool.execute.after": async (
      input: {
        tool: string;
        sessionID: string;
        callID: string;
        args: WriteToolArgs;
      },
      output: { title: string; output: string; metadata: ToolMetadata }
    ) => {
      if (input.tool !== "write" && input.tool !== "edit") return;

      const filePath = getFilePath(input.args);
      if (!isCodeFile(filePath)) return;

      output.output += `\n\n[CIEL RELIRE] ${filePath} was just written. Dispatch @ciel-critic now: MODE=RELIRE, CHANGED_FILES=[${filePath}], QUOI_GOAL=[objective], IMPLEMENTATION=[summary]. Do not continue before the verdict.`;
    },
  };
};
