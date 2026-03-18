import type { AppConfig } from "./config";
import { loadConfig } from "./config";
import { ensureStateDirs } from "./fs";
import { JobStore } from "./jobs";
import { FixtureProofProvider, LiveProofProvider, type ProofProvider } from "./proof-provider";
import { createQueueClient, type QueueClient, type QueueMessage } from "./queue";
import { processJob } from "./worker-jobs";
import type { ProofJobRecord } from "./types";

export interface WorkerJobStore {
  get(id: string): Promise<ProofJobRecord | null>;
  update(id: string, patch: Partial<ProofJobRecord>): Promise<ProofJobRecord>;
}

export interface WorkerDeps {
  config: AppConfig;
  queue: QueueClient;
  jobs: WorkerJobStore;
  providers: Record<"fixture" | "live", ProofProvider>;
  processJob: typeof processJob;
  sleep: (ms: number) => Promise<void>;
  logger: Pick<Console, "log" | "error">;
}

export function createDefaultWorkerDeps(config: AppConfig): WorkerDeps {
  return {
    config,
    queue: createQueueClient(config),
    jobs: new JobStore(config.jobsDir),
    providers: {
      fixture: new FixtureProofProvider(config),
      live: new LiveProofProvider(config)
    },
    processJob,
    sleep: Bun.sleep,
    logger: console
  };
}

export async function processOneJob(
  deps: WorkerDeps,
  message: QueueMessage
): Promise<"missing" | "completed" | "failed"> {
  const job = await deps.jobs.get(message.jobId);
  if (!job) {
    await deps.queue.ack(message);
    return "missing";
  }

  try {
    await deps.jobs.update(job.id, { status: "running", error: undefined });
    const result = await deps.processJob(deps.config, job, deps.providers);
    await deps.jobs.update(job.id, { status: "completed", result });
    await deps.queue.ack(message);
    return "completed";
  } catch (error) {
    await deps.jobs.update(job.id, {
      status: "failed",
      error: error instanceof Error ? error.message : String(error)
    });
    await deps.queue.ack(message);
    return "failed";
  }
}

export async function runWorkerLoop(
  deps: WorkerDeps,
  options: { once?: boolean } = {}
): Promise<void> {
  deps.logger.log(`prover-worker started in ${deps.config.queueMode} mode`);

  while (true) {
    const message = await deps.queue.receive();
    if (!message) {
      if (options.once) {
        return;
      }
      await deps.sleep(1000);
      continue;
    }

    await processOneJob(deps, message);
    if (options.once) {
      return;
    }
  }
}

export async function startWorker(
  config: AppConfig = loadConfig(),
  deps: WorkerDeps = createDefaultWorkerDeps(config)
): Promise<void> {
  await ensureStateDirs([
    config.stateDir,
    config.jobsDir,
    config.queueDir,
    config.snapshotsDir
  ]);
  await runWorkerLoop(deps);
}

if (import.meta.main) {
  await startWorker();
}
