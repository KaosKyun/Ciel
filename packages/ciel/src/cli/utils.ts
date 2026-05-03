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
