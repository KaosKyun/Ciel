// Shared utilities for Ciel CLI

const isQuiet = (): boolean => process.argv.includes("--quiet") || process.argv.includes("-q");

const ANSI_CYAN = "\u001b[0;36m";
const ANSI_GREEN = "\u001b[0;32m";
const ANSI_YELLOW = "\u001b[0;33m";
const ANSI_RED = "\u001b[0;31m";
const ANSI_BOLD = "\u001b[1m";
const ANSI_RESET = "\u001b[0m";

function hasAnsi(): boolean {
  return process.stdout.isTTY;
}

export function say(msg: string): void {
  if (!isQuiet()) {
    console.log(`  ${hasAnsi() ? ANSI_CYAN + "→" + ANSI_RESET : "→"} ${msg}`);
  }
}

export function ok(msg: string): void {
  if (!isQuiet()) {
    console.log(`  ${hasAnsi() ? ANSI_GREEN + "✓" + ANSI_RESET : "✓"} ${msg}`);
  }
}

export function warn(msg: string): void {
  console.error(`  ${hasAnsi() ? ANSI_YELLOW + "~" + ANSI_RESET : "~"} ${msg}`);
}

export function err(msg: string): void {
  console.error(`  ${hasAnsi() ? ANSI_RED + "✗" + ANSI_RESET : "✗"} ${msg}`);
}

export function header(msg: string): void {
  console.log(`\n  ${hasAnsi() ? ANSI_BOLD : ""}${msg}${hasAnsi() ? ANSI_RESET : ""}`);
}

export function promptConfirm(msg: string, defaultYes: boolean = true): Promise<boolean> {
  return new Promise((resolve) => {
    const prompt = defaultYes ? "Y/n" : "y/N";
    process.stdout.write(`  ? ${msg} [${prompt}]: `);

    const stdin = process.stdin;
    stdin.resume();
    stdin.once("data", (data: Buffer) => {
      stdin.pause();
      const answer = data.toString().trim().toLowerCase();
      if (answer === "") resolve(defaultYes);
      else if (answer === "y" || answer === "yes") resolve(true);
      else resolve(false);
    });
  });
}

// Platform detection moved to opencode.ts and claude.ts (detectOpenCode, detectClaude)

/**
 * Build the argument vector for re-executing the freshly-updated `ciel`
 * binary as a clean `update`. Takes the raw process.argv.
 *
 * Contract: the re-exec must ALWAYS run `update` and nothing else. The
 * downstream CLI resolves its command as the first non-flag token
 * (args.find(a => !a.startsWith("-"))), so ANY surviving positional poisons
 * resolution — the leaked absolute script path (slice(1) kept argv[1], e.g.
 * /opt/homebrew/bin/ciel → "Unknown command: /opt/homebrew/bin/ciel") was one
 * instance; a stray `ciel repair foo` would be another.
 *
 * So: drop every positional (node binary, script path, the update/repair
 * token, and any extra positional), keep only the user's flags, then append a
 * canonical `update`. `--skip-npm-update --yes` force a non-interactive run
 * that does not re-trigger the npm-update re-exec loop.
 */
export function buildReexecArgs(argv: string[]): string[] {
  const flags = argv.slice(2).filter((a) => a.startsWith("-"));
  return [...flags, "update", "--skip-npm-update", "--yes"];
}
