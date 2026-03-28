import { describe, expect, test } from "bun:test";
import { processOneJob, runWorkerLoop, type WorkerDeps } from "./worker";
import type { AppConfig } from "./config";
import type { ProofJobRecord } from "./types";

function makeConfig(): AppConfig {
  return {
    repoRoot: "/repo",
    serviceRoot: "/repo/ops/aws-testnet",
    stateDir: "/state",
    jobsDir: "/state/jobs",
    deployJobsDir: "/state/deploy-jobs",
    queueDir: "/state/queue",
    snapshotsDir: "/state/snapshots",
    manifestPath: "/state/manifest.json",
    deployLogPath: "/state/deploy.log",
    operatorHost: "127.0.0.1",
    operatorPort: 8787,
    rpcUrl: "http://127.0.0.1:8545",
    chainId: 31337,
    awsRegion: undefined,
    awsStackName: undefined,
    ssmTargetInstanceId: undefined,
    snapshotBucket: undefined,
    snapshotPrefix: "snapshots",
    sqsQueueUrl: undefined,
    proofQueueName: undefined,
    queueMode: "file",
    adminPrivateKey: "admin",
    player1PrivateKey: "player1",
    player2PrivateKey: "player2"
  };
}

function makeJob(): ProofJobRecord {
  return {
    id: "job-1",
    jobType: "smoke-poker",
    mode: "fixture",
    status: "queued",
    createdAt: "now",
    updatedAt: "now"
  };
}

function makeDeps(overrides: Partial<WorkerDeps> = {}): WorkerDeps {
  const job = makeJob();
  const acked: string[] = [];
  return {
    config: makeConfig(),
    queue: {
      async enqueue() {
        return;
      },
      async receive() {
        return { jobId: job.id };
      },
      async ack(message) {
        acked.push(message.jobId);
      }
    },
    jobs: {
      async get(id) {
        return id === job.id ? job : null;
      },
      async update(_id, patch) {
        Object.assign(job, patch, { updatedAt: "later" });
        return job;
      }
    },
    providers: {
      fixture: { mode: "fixture", async execute() { return {}; } },
      live: { mode: "live", async execute() { return {}; } }
    },
    async processJob() {
      return { ok: true };
    },
    async sleep() {
      return;
    },
    logger: {
      log() {
        return;
      },
      error() {
        return;
      }
    },
    ...overrides
  };
}

describe("worker", () => {
  test("marks successful jobs completed", async () => {
    const deps = makeDeps();
    const status = await processOneJob(deps, { jobId: "job-1" });
    expect(status).toBe("completed");
    const job = await deps.jobs.get("job-1");
    expect(job?.status).toBe("completed");
  });

  test("marks failing jobs failed and acks them", async () => {
    const deps = makeDeps({
      async processJob() {
        throw new Error("boom");
      }
    });
    const status = await processOneJob(deps, { jobId: "job-1" });
    expect(status).toBe("failed");
    const job = await deps.jobs.get("job-1");
    expect(job?.status).toBe("failed");
    expect(job?.error).toContain("boom");
  });

  test("acks missing jobs without failing", async () => {
    const deps = makeDeps({
      jobs: {
        async get() {
          return null;
        },
        async update() {
          throw new Error("should not update");
        }
      }
    });
    const status = await processOneJob(deps, { jobId: "missing" });
    expect(status).toBe("missing");
  });

  test("runWorkerLoop can execute exactly one iteration", async () => {
    const deps = makeDeps();
    await runWorkerLoop(deps, { once: true });
    const job = await deps.jobs.get("job-1");
    expect(job?.status).toBe("completed");
  });
});
