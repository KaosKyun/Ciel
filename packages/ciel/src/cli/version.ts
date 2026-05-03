// Shared version utility — reads from package.json at runtime
// Single source of truth for all version display

import { readFileSync, existsSync } from "fs";
import { join } from "path";

// In-memory cache (avoids reading file on every call)
let _cachedVersion: string | null = null;

export function getVersion(): string {
  if (_cachedVersion) return _cachedVersion;

  // Try package.json (npm package: node_modules/@neikyun/ciel/package.json)
  try {
    // __dirname is dist/cli/ or src/cli/ depending on environment
    const pkgPath = join(__dirname, "..", "..", "package.json");
    if (existsSync(pkgPath)) {
      const pkg = JSON.parse(readFileSync(pkgPath, "utf-8"));
      _cachedVersion = pkg.version || "0.0.0";
      return _cachedVersion;
    }
  } catch {
    // silent
  }

  // Fallback: VERSION file at project root (dev mode)
  try {
    const versionPath = join(process.cwd(), "VERSION");
    if (existsSync(versionPath)) {
      _cachedVersion = readFileSync(versionPath, "utf-8").trim();
      return _cachedVersion;
    }
  } catch {
    // silent
  }

  return "0.0.0";
}
