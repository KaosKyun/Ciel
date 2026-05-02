// Ciel Plugin — local bridge for self-hosting
//
// During development, re-exports from the packages/ workspace.
// The npm package @ciel/plugin is the source of truth.
//
// When using the npm version, reference in opencode.json as:
//   "plugin": ["@ciel/plugin"]

import cielPlugin from "../../packages/ciel/src/plugin/index";
export default cielPlugin;
