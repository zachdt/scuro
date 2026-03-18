import { loadConfig } from "./config";
import { ensureStateDirs } from "./fs";

const config = loadConfig();
await ensureStateDirs([
  config.stateDir,
  config.jobsDir,
  config.queueDir,
  config.snapshotsDir
]);

console.log(JSON.stringify({
  ok: true,
  queueMode: config.queueMode,
  repoRoot: config.repoRoot,
  stateDir: config.stateDir
}, null, 2));
