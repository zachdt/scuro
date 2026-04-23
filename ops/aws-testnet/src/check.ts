import { loadConfig } from "./config";
import { ensureStateDirs } from "./fs";

const config = loadConfig();
await ensureStateDirs([
  config.stateDir,
  config.deployJobsDir,
  config.snapshotsDir
]);

console.log(JSON.stringify({
  ok: true,
  repoRoot: config.repoRoot,
  stateDir: config.stateDir
}, null, 2));
