import { describe, expect, test } from "bun:test";
import os from "node:os";
import path from "node:path";
import { createOperatorFetchHandler, normalizeJob, startOperatorServer, type OperatorDeps } from "./operator";
import type { AppConfig } from "./config";
import type { DeploymentManifest, ProofJobRecord, ProofJobRequest } from "./types";

function makeConfig(): AppConfig {
  const stateDir = path.join(os.tmpdir(), "scuro-operator-test");
  return {
    repoRoot: "/repo",
    serviceRoot: "/repo/ops/aws-testnet",
    stateDir,
    jobsDir: path.join(stateDir, "jobs"),
    queueDir: path.join(stateDir, "queue"),
    snapshotsDir: path.join(stateDir, "snapshots"),
    manifestPath: path.join(stateDir, "manifest.json"),
    deployLogPath: path.join(stateDir, "deploy.log"),
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

function makeManifest(): DeploymentManifest {
  return {
    chain: {
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      deployedAt: "2024-01-01T00:00:00.000Z"
    },
    aws: {
      operatorPort: 8787,
      queueMode: "file"
    },
    contracts: {
      ScuroToken: "0x1"
    },
    actors: {
      Admin: "0xabc"
    }
  };
}

function makeDeps(overrides: Partial<OperatorDeps> = {}): OperatorDeps {
  const jobsState = new Map<string, ProofJobRecord>();
  return {
    jobs: {
      async create(request: ProofJobRequest): Promise<ProofJobRecord> {
        const record: ProofJobRecord = {
          ...request,
          id: "job-1",
          status: "queued",
          createdAt: "now",
          updatedAt: "now"
        };
        jobsState.set(record.id, record);
        return record;
      },
      async get(id: string): Promise<ProofJobRecord | null> {
        return jobsState.get(id) ?? null;
      }
    },
    queue: {
      async enqueue() {
        return;
      },
      async receive() {
        return null;
      },
      async ack() {
        return;
      }
    },
    async checkChainHealth() {
      return { rpcUrl: "http://127.0.0.1:8545", chainId: "0x7a69" };
    },
    async loadManifest() {
      return makeManifest();
    },
    async deployProtocol() {
      return makeManifest();
    },
    async seedApprovals() {
      return;
    },
    async resetAndDeploy() {
      return makeManifest();
    },
    async exportSnapshot() {
      return { snapshotName: "snap-1", localPath: "/tmp/snap-1.json" };
    },
    async restoreSnapshot() {
      return { snapshotName: "snap-1", localPath: "/tmp/snap-1.json" };
    },
    async runNumberPickerSmoke() {
      return { script: "number-picker", status: "ok" };
    },
    async runPokerSmoke() {
      return { script: "poker", status: "ok" };
    },
    async runBlackjackSmoke() {
      return { script: "blackjack", status: "ok" };
    },
    ...overrides
  };
}

describe("normalizeJob", () => {
  test("rejects missing jobType", () => {
    expect(() => normalizeJob({ mode: "fixture" })).toThrow("jobType is required");
  });

  test("rejects invalid mode", () => {
    expect(() => normalizeJob({ jobType: "x", mode: "bad" })).toThrow("mode must be fixture or live");
  });
});

describe("operator handler", () => {
  test("returns health payload", async () => {
    const handler = createOperatorFetchHandler(makeConfig(), makeDeps());
    const response = await handler(new Request("http://local/health"));
    expect(response.status).toBe(200);
    const body = await response.json() as Record<string, unknown>;
    expect(body.ok).toBe(true);
    expect(body.service).toBe("operator-api");
    expect((body.chain as { ok: boolean }).ok).toBe(true);
  });

  test("returns degraded chain health without failing liveness", async () => {
    const handler = createOperatorFetchHandler(
      makeConfig(),
      makeDeps({
        async checkChainHealth() {
          throw new Error("rpc unavailable");
        }
      })
    );
    const response = await handler(new Request("http://local/health"));
    expect(response.status).toBe(200);
    const body = await response.json() as {
      ok: boolean;
      chain: { ok: boolean; error: string };
    };
    expect(body.ok).toBe(true);
    expect(body.chain.ok).toBe(false);
    expect(body.chain.error).toContain("rpc unavailable");
  });

  test("returns manifest not found as 404", async () => {
    const deps = makeDeps({
      async loadManifest() {
        return null;
      }
    });
    const handler = createOperatorFetchHandler(makeConfig(), deps);
    const response = await handler(new Request("http://local/manifest"));
    expect(response.status).toBe(404);
  });

  test("returns actors from manifest", async () => {
    const handler = createOperatorFetchHandler(makeConfig(), makeDeps());
    const response = await handler(new Request("http://local/actors"));
    expect(response.status).toBe(200);
    const body = await response.json() as { actors: Record<string, string> };
    expect(body.actors.Admin).toBe("0xabc");
  });

  test("enqueues smoke jobs", async () => {
    const enqueued: string[] = [];
    const deps = makeDeps({
      queue: {
        async enqueue(job) {
          enqueued.push(job.jobType);
        },
        async receive() {
          return null;
        },
        async ack() {
          return;
        }
      }
    });
    const handler = createOperatorFetchHandler(makeConfig(), deps);
    const response = await handler(new Request("http://local/smoke/poker", { method: "POST" }));
    expect(response.status).toBe(202);
    expect(enqueued).toEqual(["smoke-poker"]);
  });

  test("rejects invalid proof jobs with 400", async () => {
    const handler = createOperatorFetchHandler(makeConfig(), makeDeps());
    const response = await handler(new Request("http://local/proof-jobs", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ mode: "fixture" })
    }));
    expect(response.status).toBe(400);
  });

  test("returns missing job as 404", async () => {
    const handler = createOperatorFetchHandler(makeConfig(), makeDeps());
    const response = await handler(new Request("http://local/proof-jobs/unknown"));
    expect(response.status).toBe(404);
  });

  test("routes snapshot export", async () => {
    const handler = createOperatorFetchHandler(makeConfig(), makeDeps());
    const response = await handler(new Request("http://local/snapshots/export", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ name: "snap-1" })
    }));
    expect(response.status).toBe(201);
  });

  test("exposes local smoke endpoints without binding a port", async () => {
    const handler = createOperatorFetchHandler(makeConfig(), makeDeps());
    const response = await handler(new Request("http://local/_local/smoke/blackjack", { method: "POST" }));
    expect(response.status).toBe(200);
    const body = await response.json() as Record<string, string>;
    expect(body.script).toBe("blackjack");
  });
});

describe("startOperatorServer", () => {
  test("passes handler into injected serve function", async () => {
    const calls: Array<{ hostname: string; port: number }> = [];
    const config = makeConfig();
    const deps = makeDeps();
    const server = await startOperatorServer(
      config,
      deps,
      ({ hostname, port, fetch }) => {
        calls.push({ hostname, port });
        expect(typeof fetch).toBe("function");
        return {
          stop() {
            return;
          }
        };
      }
    );

    expect(calls).toEqual([{ hostname: "127.0.0.1", port: 8787 }]);
    expect(typeof server.stop).toBe("function");
  });
});
