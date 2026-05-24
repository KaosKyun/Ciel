// Memory command — query and manage Ciel cued-recall memory
// Wraps memory-engine.py for query/capture/rebuild; implements list/stats/show
// in TypeScript by reading index.json directly.
//
// Used by both humans and Ciel itself:
//   ciel memory query "topic"           Search memories
//   ciel memory list                    List all (ID + title)
//   ciel memory show <id>               Full memory content
//   ciel memory stats                   Health: count, stale, orphans
//   ciel memory save --title "..."      Save memory (content on stdin)
//   ciel memory rebuild                 Rebuild index from episode files

import { existsSync, readFileSync, readdirSync } from "fs";
import { join, basename } from "path";
import { execFileSync } from "child_process";
import { say, ok, warn, header } from "./utils";
import { getVersion } from "./version";

interface MemoryRecord {
  id: string;
  title?: string;
  symbols?: string[];
  intents?: string[];
  path_patterns?: string[];
  languages?: string[];
  trigger_count?: number;
  last_triggered?: string | null;
  captured_at?: string;
  captured_from?: string;
  source?: string;
  stale?: boolean;
}

interface MemoryIndex {
  version?: number;
  memories: Record<string, MemoryRecord>;
  by_symbol?: Record<string, string[]>;
  by_path?: Record<string, string[]>;
  by_intent?: Record<string, string[]>;
  by_language?: Record<string, string[]>;
}

// ── Python bridge ──────────────────────────────────────────────────────────

function findEngine(cwd: string): string {
  const candidates = [
    join(cwd, ".claude", "hooks", "memory-engine.py"),
    join(cwd, "hooks", "memory-engine.py"),
  ];
  for (const c of candidates) {
    if (existsSync(c)) return c;
  }
  throw new Error("memory-engine.py not found. Run 'ciel init' first.");
}

function py(args: string[], cwd: string): string {
  const engine = findEngine(cwd);
  return execFileSync("python3", [engine, ...args], {
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
    cwd,
  });
}

// ── Index reading ──────────────────────────────────────────────────────────

function readIndex(cwd: string): MemoryIndex | null {
  const idxPath = join(cwd, ".ciel", "memory", "index.json");
  if (!existsSync(idxPath)) return null;
  try {
    return JSON.parse(readFileSync(idxPath, "utf8"));
  } catch {
    return null;
  }
}

function findEpisodeFile(cwd: string, id: string): string | null {
  const dirs = ["episodes", "concepts", "guards"];
  for (const d of dirs) {
    const dirPath = join(cwd, ".ciel", "memory", d);
    if (!existsSync(dirPath)) continue;
    for (const f of readdirSync(dirPath)) {
      if (!f.endsWith(".md")) continue;
      try {
        const content = readFileSync(join(dirPath, f), "utf8");
        if (content.includes(id)) return join(dirPath, f);
      } catch { /* skip */ }
    }
  }
  return null;
}

// ── Core functions ─────────────────────────────────────────────────────────

export function memoryQuery(cwd: string, prompt: string): string {
  return py(["query", "--prompt", prompt, "--cwd", cwd, "--depth", "standard"], cwd);
}

export function memoryList(cwd: string): string {
  const idx = readIndex(cwd);
  if (!idx || !Object.keys(idx.memories).length) return "No memories.";

  const lines: string[] = [];
  for (const [mid, m] of Object.entries(idx.memories).sort(([, a], [, b]) =>
    (a.title || "").localeCompare(b.title || "")
  )) {
    const title = (m.title || "untitled").substring(0, 70);
    const triggers = `fired=${m.trigger_count || 0}x`;
    const last = m.last_triggered || "never";
    lines.push(`${mid}  ${title}  ${triggers}  last=${last}`);
  }
  return lines.join("\n");
}

export function memoryShow(cwd: string, id: string): string {
  const idx = readIndex(cwd);
  if (!idx || !idx.memories[id]) return `Memory '${id}' not found.`;

  const mem = idx.memories[id];
  const episodePath = findEpisodeFile(cwd, id);
  let content = "";
  if (episodePath) {
    try {
      content = readFileSync(episodePath, "utf8");
    } catch { content = "(unreadable)"; }
  } else {
    content = "(episode file not found)";
  }

  return [
    `## ${id}: ${mem.title || "untitled"}`,
    `Captured: ${mem.captured_at || "?"}  Source: ${mem.source || "?"}  From: ${mem.captured_from || "?"}`,
    `Symbols: ${(mem.symbols || []).join(", ") || "-"}`,
    `Intents: ${(mem.intents || []).join(", ") || "-"}`,
    `Path patterns: ${(mem.path_patterns || []).join(", ") || "-"}`,
    `Languages: ${(mem.languages || []).join(", ") || "-"}`,
    `Trigger count: ${mem.trigger_count || 0}  Last triggered: ${mem.last_triggered || "never"}`,
    `Stale: ${mem.stale ? "yes" : "no"}`,
    "",
    content,
  ].join("\n");
}

export function memoryStats(cwd: string): string {
  const idx = readIndex(cwd);
  if (!idx) return "No index found. Run 'ciel memory init' first.";

  const mems = Object.entries(idx.memories);
  const total = mems.length;
  const stale = mems.filter(([, m]) => m.stale).length;
  const neverTriggered = mems.filter(([, m]) => !(m.trigger_count || 0)).length;
  const midSet = new Set(mems.map(([id]) => id));

  let orphans = 0;
  let emptyKeys = 0;
  for (const idxName of ["by_path", "by_symbol", "by_intent", "by_language"] as const) {
    const idxMap = (idx as any)[idxName] || {};
    for (const [, mids] of Object.entries(idxMap) as [string, string[]][]) {
      if (!mids || !mids.length) { emptyKeys++; continue; }
      orphans += mids.filter((mid) => !midSet.has(mid)).length;
    }
  }

  const top = mems
    .sort(([, a], [, b]) => (b.trigger_count || 0) - (a.trigger_count || 0))
    .slice(0, 5)
    .map(([id, m]) => `  ${id} — ${(m.title || "").substring(0, 60)} (${m.trigger_count || 0}x)`);

  return [
    `Total: ${total}  Stale: ${stale}  Never triggered: ${neverTriggered}`,
    `Orphan refs: ${orphans}  Empty keys: ${emptyKeys}`,
    "",
    "Top 5 most triggered:",
    ...top,
  ].join("\n");
}

export function memoryRebuild(cwd: string): string {
  return py(["rebuild-index", "--cwd", cwd], cwd);
}

export function memorySave(
  cwd: string,
  opts: {
    title: string;
    content: string;
    symbols?: string[];
    intents?: string[];
    paths?: string[];
    languages?: string[];
    capturedFrom?: string;
    source?: string;
    type?: string;
  }
): string {
  const args = [
    "capture",
    "--cwd", cwd,
    "--title", opts.title,
    "--content", opts.content,
  ];
  if (opts.symbols?.length) args.push("--symbols", opts.symbols.join(","));
  if (opts.intents?.length) args.push("--intents", opts.intents.join(","));
  if (opts.paths?.length) args.push("--path_patterns", opts.paths.join(","));
  if (opts.languages?.length) args.push("--languages", opts.languages.join(","));
  if (opts.capturedFrom) args.push("--captured_from", opts.capturedFrom);
  if (opts.source) args.push("--source", opts.source);
  if (opts.type) args.push("--type", opts.type);
  return py(args, cwd);
}

// ── CLI entry point ────────────────────────────────────────────────────────

export async function memoryMain(args: string[]): Promise<void> {
  const version = getVersion();
  // args[0] is "memory", the first subcommand is at index 1 or later
  const nonFlags = args.filter((a) => !a.startsWith("-"));
  // args[0] is "memory", the actual subcommand is the next non-flag argument
  const subcommand = nonFlags.length > 1 ? nonFlags[1] : "query";
  const cwdArg = args.find((a) => a.startsWith("--cwd="));
  const cwd = cwdArg ? cwdArg.slice(6) : process.cwd();
  const json = args.includes("--json");
  const quiet = args.includes("--quiet");

  try {
    switch (subcommand) {
      case "query": {
        const prompt = args.filter((a) => !a.startsWith("-") && a !== "query").join(" ") || "";
        if (!prompt) {
          warn("Usage: ciel memory query <prompt>");
          process.exit(1);
        }
        const output = memoryQuery(cwd, prompt);
        console.log(output || "No memories matched.");
        break;
      }
      case "list": {
        if (json) {
          const idx = readIndex(cwd);
          console.log(JSON.stringify(idx?.memories || {}));
          return;
        }
        if (!quiet) header(`Ciel v${version} — Memory List`);
        console.log(memoryList(cwd));
        break;
      }
      case "show": {
        const params = args.filter((a) => !a.startsWith("-"));
        const id = params[params.indexOf("show") + 1];
        if (!id) {
          warn("Usage: ciel memory show <id>");
          process.exit(1);
        }
        console.log(memoryShow(cwd, id));
        break;
      }
      case "stats": {
        if (json) {
          const idx = readIndex(cwd);
          console.log(JSON.stringify({ total: Object.keys(idx?.memories || {}).length }));
          return;
        }
        if (!quiet) header(`Ciel v${version} — Memory Stats`);
        console.log(memoryStats(cwd));
        break;
      }
      case "save": {
        const titleIdx = args.indexOf("--title");
        const title = titleIdx >= 0 ? args[titleIdx + 1] : "";
        if (!title) {
          warn("Usage: ciel memory save --title <title> [--symbols a,b] [--intents a,b] [--paths a,b] [--languages a,b] [--from X] [--source X] < content.md");
          process.exit(1);
        }
        // Read content from stdin
        let content = "";
        if (!process.stdin.isTTY) {
          const chunks: Buffer[] = [];
          process.stdin.resume();
          for (;;) {
            const chunk = process.stdin.read() as Buffer | null;
            if (!chunk) break;
            chunks.push(chunk);
          }
          content = Buffer.concat(chunks).toString("utf8").trim();
        }
        if (!content) {
          warn("No content provided on stdin. Pipe memory body into 'ciel memory save'.");
          process.exit(1);
        }

        const symIdx = args.indexOf("--symbols");
        const intIdx = args.indexOf("--intents");
        const pathIdx = args.indexOf("--paths");
        const langIdx = args.indexOf("--languages");
        const fromIdx = args.indexOf("--from");
        const srcIdx = args.indexOf("--source");

        const mid = memorySave(cwd, {
          title,
          content,
          symbols: symIdx >= 0 ? args[symIdx + 1].split(",").map((s: string) => s.trim()) : undefined,
          intents: intIdx >= 0 ? args[intIdx + 1].split(",").map((s: string) => s.trim()) : undefined,
          paths: pathIdx >= 0 ? args[pathIdx + 1].split(",").map((s: string) => s.trim()) : undefined,
          languages: langIdx >= 0 ? args[langIdx + 1].split(",").map((s: string) => s.trim()) : undefined,
          capturedFrom: fromIdx >= 0 ? args[fromIdx + 1] : undefined,
          source: srcIdx >= 0 ? args[srcIdx + 1] : undefined,
        });
        if (!quiet) ok(`Memory saved: ${mid.trim()}`);
        break;
      }
      case "rebuild": {
        if (!quiet) header(`Ciel v${version} — Rebuild Index`);
        const output = memoryRebuild(cwd);
        if (!quiet) ok(output.trim() || "Index rebuilt.");
        break;
      }
      default:
        warn(`Unknown memory command: ${subcommand}`);
        warn("Usage: ciel memory <query|list|show|stats|save|rebuild> [options]");
        process.exit(1);
    }
  } catch (e: any) {
    warn(`Memory command failed: ${e.message}`);
    if (e.stderr) warn(e.stderr.toString().slice(0, 300));
    process.exit(1);
  }
}
