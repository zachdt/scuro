import { loadConfig } from "./config";
import { ensureStateDirs } from "./fs";
import { JobStore } from "./jobs";
import { FixtureProofProvider, LiveProofProvider } from "./proof-provider";
import { createQueueClient } from "./queue";
import { processJob } from "./worker-jobs";

const config = loadConfig();
await ensureStateDirs([
  config.stateDir,
  config.jobsDir,
  config.queueDir,
  config.snapshotsDir
]);

const jobs = new JobStore(config.jobsDir);
const queue = createQueueClient(config);
const providers = {
  fixture: new FixtureProofProvider(config),
  live: new LiveProofProvider(config)
} as const;

console.log(`prover-worker started in ${config.queueMode} mode`);

while (true) {
  const message = await queue.receive();
  if (!message) {
    await Bun.sleep(1000);
    continue;
  }

  const job = await jobs.get(message.jobId);
  if (!job) {
    await queue.ack(message);
    continue;
  }

  try {
    await jobs.update(job.id, { status: "running", error: undefined });
    const result = await processJob(config, job, providers);
    await jobs.update(job.id, { status: "completed", result });
    await queue.ack(message);
  } catch (error) {
    await jobs.update(job.id, {
      status: "failed",
      error: error instanceof Error ? error.message : String(error)
    });
    await queue.ack(message);
  }
}
