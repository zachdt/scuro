import { describe, expect, test } from "bun:test";
import type { AppConfig } from "./config";
import { createOperatorFetchHandler, type OperatorDeps } from "./operator";
import type { DeploymentManifest } from "./types";

const manifest: DeploymentManifest = {
  chain: { rpcUrl: "http://127.0.0.1:8545", chainId: 31337, deployedAt: "2026-04-23T00:00:00.000Z" },
  aws: { operatorPort: 8787 },
  contracts: {
    ScuroToken: "0x0000000000000000000000000000000000000001",
    NumberPickerAdapter: "0x0000000000000000000000000000000000000002",
    SlotMachineController: "0x0000000000000000000000000000000000000003"
  },
  actors: {
    Admin: "0x0000000000000000000000000000000000000004",
    Player1: "0x0000000000000000000000000000000000000005",
    Player2: "0x0000000000000000000000000000000000000006"
  }
};

const config = {
  manifestPath: "/tmp/scuro-test-manifest.json",
  operatorHost: "127.0.0.1",
  operatorPort: 8787
} as AppConfig;

function deps(): OperatorDeps {
  return {
    deploymentJobs: {
      async start(operation) {
        return {
          id: `job-${operation}`,
          operation,
          status: "queued",
          createdAt: "2026-04-23T00:00:00.000Z",
          updatedAt: "2026-04-23T00:00:00.000Z",
          statusUrl: `/deploy-jobs/job-${operation}`
        };
      },
      async get() {
        return null;
      },
      async recover() {}
    },
    async checkChainHealth() {
      return { chainId: "0x7a69" };
    },
    async loadManifest() {
      return manifest;
    },
    async seedApprovals() {},
    async exportSnapshot() {
      return { snapshotName: "snap", localPath: "/tmp/snap.json" };
    },
    async restoreSnapshot() {
      return { snapshotName: "snap", localPath: "/tmp/snap.json" };
    },
    async runNumberPickerSmoke() {
      return { script: "number-picker", status: "ok" };
    },
    async runSlotSmoke() {
      return { script: "slot", status: "ok" };
    }
  };
}

async function request(path: string, init?: RequestInit): Promise<Response> {
  return createOperatorFetchHandler(config, deps())(new Request(`http://operator.test${path}`, init));
}

describe("operator", () => {
  test("runs direct number-picker and slot smokes", async () => {
    const numberPicker = await request("/smoke/number-picker", { method: "POST" });
    expect(numberPicker.status).toBe(200);
    expect(await numberPicker.json()).toEqual({ script: "number-picker", status: "ok" });

    const slot = await request("/smoke/slot", { method: "POST" });
    expect(slot.status).toBe(200);
    expect(await slot.json()).toEqual({ script: "slot", status: "ok" });
  });

  test("rejects unknown routes", async () => {
    expect((await request("/smoke/unknown", { method: "POST" })).status).toBe(404);
  });

  test("starts deployment jobs and exposes actors", async () => {
    const deploy = await request("/deploy", { method: "POST" });
    expect(deploy.status).toBe(202);
    expect(await deploy.json()).toMatchObject({ jobId: "job-deploy", status: "queued" });

    const actors = await request("/actors");
    expect(actors.status).toBe(200);
    expect(await actors.json()).toMatchObject({ actors: manifest.actors });
  });
});
