// Check command — compare local version against GitHub

import { get as httpsGet } from "https";
import { ok, err, say } from "./utils";
import { getVersion } from "./version";

const GITHUB_RAW = "https://raw.githubusercontent.com/KaosKyun/Ciel/main";
const CIEL_VERSION = getVersion();

function fetchUrl(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    httpsGet(url, (res) => {
      let data = "";
      res.on("data", (chunk: string) => (data += chunk));
      res.on("end", () => resolve(data.trim()));
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
    const remoteVersion = await fetchUrl(`${GITHUB_RAW}/VERSION`);
    if (!remoteVersion) {
      err("Could not fetch remote version from GitHub.");
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
      console.log(`  Update available: v${CIEL_VERSION} → ${remoteVersion}`);
      console.log("  Run 'npx ciel update' to upgrade.");
      process.exit(0);
    }

    // Local is newer (dev mode)
    say(`Ciel v${CIEL_VERSION} (ahead of remote v${remoteVersion} — dev mode)`);
    process.exit(0);
  } catch (error: any) {
    err(`Network error: ${error.message}`);
    process.exit(2);
  }
}
