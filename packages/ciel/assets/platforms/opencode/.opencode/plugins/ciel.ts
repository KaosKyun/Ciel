// Ciel — OpenCode plugin (v6.2.4)
// Ciel v5 plugin. Pure TS, no shell dependency.
//
// Phase detection (conception/implementation/debug/research) complements
// depth classification — determines skill LOADING ORDER (conception first).
//
// Injection model (verified against @opencode-ai/plugin/dist/index.d.ts):
//   - experimental.chat.system.transform → push CIEL WORKFLOW + depth+phase
//     hint + sticky RELIRE notice + META-CRITIQUER into the system-prompt
//   - experimental.chat.messages.transform → depth + phase classification
//   - tool.execute.after (write|edit)    → append a per-file FAIRE/RELIRE
//     reminder to the tool result string
//   - session.created (event)            → console banner only
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
const CONCEPTION_KEYWORD_RE = /\b(architecture|design pattern|conception|structur.e?|schema.?archi|trade.?off|decoupage|ddd|monolithe|microservice|flux.*donn.e?|diagram|c4.?model|vision.*technique|plan.*architecture|hld|lld|system.?design|choisir.*techno|compare.*stack|refonte.*archi|audit.*archi|concevoir|designer)\b/i;
const IMPL_KEYWORD_RE = /\b(implement|code|coder|ecrire|write|creer|creat|setup|configure|deploy|migrat|refactor|feature|function|method|class|api.*route|endpoint|service|worker|queue|db.*schema|table.*sql|ajout|add.*(route|service|feature))\b/i;
const DEBUG_KEYWORD_RE = /\b(fix|bug|error|crash|issue|problem|fail|break|corrig|debug|incident|regression|panic|excep|stack.*trace|MTTR|root.?cause|ne.*marche|pas.*fonctionn)\b/i;
const RESEARCH_KEYWORD_RE = /\b(what.?is|how.?does|explain|understand|compare.*vs|diff.re?rence|document|doc.*tool|learn|tutoriel|guide|best.?practice|c'est.?quoi|quest.ce.que)\b/i;

// Pipeline instruction injected into every system prompt
const CIEL_WORKFLOW_INSTRUCTION = `
Follow the matching pipeline for your depth classification.

CLASSIFY: Trivial / Standard / Critical / Spike

| Depth | Pipeline |
|-------|----------|
| Standard/Critical | DOCS -> QUOI -> ASK -> AVEC QUOI -> DIVERGE -> RECHERCHE -> SECURITE -> CODEBASE -> EVALUER -> ASK2 -> FAIRE -> ADR -> RELIRE -> PROUVER -> MEMOIRE -> META |
| Trivial | QUOI -> FAIRE -> META |
| Spike | QUOI -> ASK -> AVEC QUOI -> DIVERGE -> FAIRE (relaxed) -> META |

PHASE defines skill LOADING ORDER: conception first (system-design, architecture, ha, resilience), THEN implementation.
Detect before dispatching. NEVER skip conception for implementation.
`;

const FAIRE_BEFORE_REMINDER = `
[CIEL FAIRE GATES -- BEFORE WRITE/EDIT]
Before executing this write/edit, verify:
0. CONCEPTION PHASE: If phase=conception, have you loaded system-design, architecture, ha, resilience FIRST? If phase=implementation, was conception done before jumping to code?
1. TEST-FIRST (RED): Have you written tests FIRST?
2. ALTERNATIVES: Can you justify X over Y?
3. IDIOMATIC: Are you using framework idiomatic patterns?
4. QUALITY: complexity < 15, nesting < 4, functions < 50 lines
5. REMOVAL: If deleting code, who uses it? What replaces it?
6. BOY-SCOUT: Did you leave code better than you found it?
`;

const META_CRITIQUER = `
[CIEL META-CRITIQUER -- 30s POST-TASK REFLECTION]
After completing the task, reflect on:
(1) Depth match -- etait-ce Trivial/Standard/Critical/Spike correct ?
(2) Failure mode -- nouveau mode d'echec decouvert ?
(3) User correction -- l'utilisateur a-t-il corrige quelque chose ? -> persist
(4) Phase match -- conception faite avant implementation ? Si non, qu'est-ce qui a ete saute ?
(5) Uncovered issues -- problemes non resolus ?
(6) Context health -- suggerer /compact si > 50% ?
(7) Dead code -- code mort introduit ?
(8) Map update -- la carte du projet (.ciel/map.json) est-elle a jour ?
(9) Parking -- y a-t-il des decouvertes fortuites a noter dans .ciel/parking.md ?
(10) Boy-scout -- le code est-il meilleur qu'avant ?
`;

const ciel: Plugin = async ({ $ }) => {
  // Per-session state. Reset when the plugin module is re-instantiated
  // (once per OpenCode session).
  const writtenFiles = new Set<string>();
  const remindedFiles = new Set<string>();
  let relireSticky = false; // once true, every turn re-injects the RELIRE notice
  let lastDepthHint: string | null = null;
  let lastPhaseHint: string | null = null;

  // v3.3.0 — dispatch-gate counter removed. The per-call [CIEL COUNTER: N/15]
  // systemMessage was pure noise on every inline tool call. Depth routing
  // still happens via experimental.chat.system.transform + the sticky
  // RELIRE notice; users dispatch @ciel-* explicitly when they need one.

  return {
    event: async ({ event }) => {
      if (event.type === "session.created") {
        // Terminal-only banner. Model context is handled by the transform hook.
        console.log("[CIEL] Session started — depth + phase-aware reasoning active. Use /ciel, @ciel-researcher, @ciel-explorer, @ciel-critic.");
      }
    },

    // Per-turn system-prompt injection. This hook runs on every model turn
    // so we get a reliable "inject once per turn" surface without having to
    // manage cross-hook message state ourselves.
    "experimental.chat.system.transform": async (_input, output) => {
      if (!Array.isArray(output?.system)) return;
      output.system.push(CIEL_WORKFLOW_INSTRUCTION);
      if (lastDepthHint) {
        output.system.push(lastDepthHint);
      }
      if (relireSticky) {
        const changed = Array.from(writtenFiles);
        output.system.push(
          `[CIEL RELIRE REQUIRED] ${changed.length} code files changed this session (${changed.slice(0, 6).join(", ")}${changed.length > 6 ? ", ..." : ""}). Dispatch @ciel-critic MODE=RELIRE — 3 RISQUES + FIX/ACCEPT/DEFER. Do not declare done before verdict.`
        );
      }
      output.system.push(META_CRITIQUER);
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
      // Phase detection (complements depth — determines skill LOADING ORDER)
      let phase: string | null = null;
      if (CONCEPTION_KEYWORD_RE.test(prompt)) {
        phase = "conception";
      } else if (DEBUG_KEYWORD_RE.test(prompt)) {
        phase = "debug";
      } else if (IMPL_KEYWORD_RE.test(prompt)) {
        phase = "implementation";
      } else if (RESEARCH_KEYWORD_RE.test(prompt)) {
        phase = "research";
      }
      lastPhaseHint = phase;
      const hints: string[] = [];
      if (depth) hints.push(`Depth: ${depth} (${reason})`);
      if (phase) hints.push(`Phase: ${phase}`);
      lastDepthHint = hints.length > 0
        ? `[CIEL] ${hints.join(". ")}. Route pipeline accordingly.`
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
