// Check command — compare local version against NPM registry
// (NPM is the canonical distribution channel for Ciel v6+)

import { get as httpsGet } from "https";
import { ok, err, say } from "./utils";
import { getVersion } from "./version";

const NPM_REGISTRY = "https://registry.npmjs.org/@neikyun/ciel/latest";
const CIEL_VERSION = getVersion();

function fetchUrl(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    httpsGet(url, { headers: { Accept: "application/json" } }, (res) => {
      let data = "";
      res.on("data", (chunk: string) => (data += chunk));
      res.on("end", () => resolve(data));
    }).on("error", reject);
  });
}

/**
 * Compare two semver strings. Returns:
 *   1 if a > b
 *  -1 if a < b
 *   0 if equal
 */
function compareVersions(a: string, b: string): number {
  const pa = a.split(".").map(Number);
  const pb = b.split(".").map(Number);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const na = pa[i] || 0;
    const nb = pb[i] || 0;
    if (na > nb) return 1;
    if (na < nb) return -1;
  }
  return 0;
}

export async function runCheck(): Promise<void> {
  try {
    const raw = await fetchUrl(NPM_REGISTRY);
    const pkg = JSON.parse(raw);
    const remoteVersion: string = pkg.version;

    if (!remoteVersion) {
      err("Could not fetch latest version from NPM registry.");
      err("Check your internet connection.");
      process.exit(2);
    }

    const cmp = compareVersions(CIEL_VERSION, remoteVersion);

    if (cmp === 0) {
      ok(`Ciel v${CIEL_VERSION} is up to date.`);
      process.exit(0);
    }

    if (cmp < 0) {
      // Remote is newer
      console.log(`  Update available: v${CIEL_VERSION} → v${remoteVersion}`);
      console.log("");
      console.log("  If installed globally:");
      console.log("    npm update -g @neikyun/ciel");
      console.log("    ciel update");
      console.log("");
      console.log("  If installed in project:");
      console.log("    npm update @neikyun/ciel");
      process.exit(0);
    }

    // Local is newer (dev mode)
    say(`Ciel v${CIEL_VERSION} (ahead of npm v${remoteVersion} — dev mode)`);
    process.exit(0);
  } catch (error: any) {
    err(`Network error: ${error.message}`);
    process.exit(2);
  }
}
