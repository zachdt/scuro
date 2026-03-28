import { describe, expect, test } from "bun:test";
import os from "node:os";
import path from "node:path";
import { mkdtempSync, rmSync } from "node:fs";
import { ensureStateDirs, writeJsonFile } from "./fs";
import { createDeploymentJobManager } from "./deployment-jobs";
import type { AppConfig } from "./config";
import type { DeploymentManifest } from "./types";

function makeConfig(stateDir: string): AppConfig {
  return {
    repoRoot: "/repo",
    serviceRoot: "/repo/ops/aws-testnet",
    stateDir,
    jobsDir: path.join(stateDir, "jobs"),
    deployJobsDir: path.join(stateDir, "deploy-jobs"),
    queueDir: path.join(stateDir, "queue"),
    snapshotsDir: path.join(stateDir, "snapshots"),
    manifestPath: path.join(stateDir, "manifest.json"),
    deployLogPath: path.join(stateDir, "deploy.log"),
    operatorHost: "127.0.0.1",
    operatorPort: 8787,
    rpcUrl: "http://127.0.0.1:8545",
    chainId: 31337,
    awsRegion: "us-east-1",
    awsStackName: "scuro-testnet-beta",
    ssmTargetInstanceId: "i-123",
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

function makeManifest(
  overrides: Partial<DeploymentManifest> = {}
): DeploymentManifest {
  return {
    chain: {
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      deployedAt: "2024-01-01T00:00:00.000Z"
    },
    aws: {
      region: "us-east-1",
      stackName: "scuro-testnet-beta",
      operatorPort: 8787,
      queueMode: "file"
    },
    contracts: {
      ScuroToken: "0x1",
      GameDeploymentFactory: "0x2"
    },
    actors: {
      Admin: "0xabc"
    },
    ...overrides
  };
}

async function waitForJob(
  getJob: () => Promise<{ status: string; error?: string } | null>
): Promise<{ status: string; error?: string }> {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const job = await getJob();
    if (job && (job.status === "completed" || job.status === "failed")) {
      return job;
    }
    await Bun.sleep(10);
  }
  throw new Error("deployment job did not reach a terminal state");
}

describe("deployment job manager", () => {
  test("persists completed deploy jobs with manifest metadata", async () => {
    const stateDir = mkdtempSync(path.join(os.tmpdir(), "scuro-deploy-job-success-"));
    const config = makeConfig(stateDir);
    await ensureStateDirs([config.stateDir, config.deployJobsDir]);

    let seedManifest: DeploymentManifest | null = null;
    const manager = createDeploymentJobManager(config, {
      async deployProtocol() {
        const manifest = makeManifest({
          deploymentStatus: "completed",
          deploymentStages: [
            { name: "core", status: "completed" },
            { name: "finalize", status: "completed" }
          ]
        });
        await writeJsonFile(config.manifestPath, manifest);
        return manifest;
      },
      async resetAndDeploy() {
        throw new Error("should not reset");
      },
      async seedApprovals(_config, manifest) {
        seedManifest = manifest;
      },
      async loadManifest() {
        return makeManifest();
      },
      logger: console
    });

    const queued = await manager.start("deploy");
    expect(queued.status).toBe("queued");

    const job = await waitForJob(async () => manager.get(queued.id));
    expect(job.status).toBe("completed");
    expect(seedManifest?.contracts.GameDeploymentFactory).toBe("0x2");

    const persisted = await manager.get(queued.id);
    expect(persisted?.manifestPath).toBe(config.manifestPath);
    expect(persisted?.deploymentStatus).toBe("completed");
    expect(persisted?.deploymentStages?.map((stage) => stage.name)).toEqual(["core", "finalize"]);

    rmSync(stateDir, { recursive: true, force: true });
  });

  test("persists failed deploy jobs with partial manifest metadata", async () => {
    const stateDir = mkdtempSync(path.join(os.tmpdir(), "scuro-deploy-job-failure-"));
    const config = makeConfig(stateDir);
    await ensureStateDirs([config.stateDir, config.deployJobsDir]);

    const partialManifest = makeManifest({
      deploymentStatus: "failed",
      deploymentStages: [
        { name: "core", status: "completed" },
        { name: "number-picker", status: "failed" }
      ],
      failedStage: "number-picker",
      deploymentError: "forge script exceeded gas budget"
    });

    const errors: string[] = [];
    const manager = createDeploymentJobManager(config, {
      async deployProtocol() {
        await writeJsonFile(config.manifestPath, partialManifest);
        throw new Error("transport failed");
      },
      async resetAndDeploy() {
        throw new Error("should not reset");
      },
      async seedApprovals() {
        throw new Error("should not seed");
      },
      async loadManifest() {
        return partialManifest;
      },
      logger: {
        error(message) {
          errors.push(String(message));
        }
      }
    });

    const queued = await manager.start("deploy");
    const job = await waitForJob(async () => manager.get(queued.id));

    expect(job.status).toBe("failed");
    expect(job.error).toBe("forge script exceeded gas budget");

    const persisted = await manager.get(queued.id);
    expect(persisted?.manifestPath).toBe(config.manifestPath);
    expect(persisted?.deploymentStatus).toBe("failed");
    expect(persisted?.failedStage).toBe("number-picker");
    expect(persisted?.deploymentStages?.map((stage) => stage.status)).toEqual(["completed", "failed"]);
    expect(errors).toHaveLength(1);

    rmSync(stateDir, { recursive: true, force: true });
  });
});
