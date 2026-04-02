import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import os from "node:os";
import { FixtureProofProvider, LiveProofProvider } from "./proof-provider";
import type { AppConfig } from "./config";
import type { CommandResult } from "./exec";
import type { ProofJobRecord } from "./types";

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

describe("proof providers", () => {
  test("live provider shells to blackjack CLI and writes payload file", async () => {
    const tempDir = mkdtempSync(path.join(os.tmpdir(), "scuro-live-proof-"));
    const config = makeConfig(tempDir);
    const calls: Array<{ cmd: string; args: string[] }> = [];
    const provider = new LiveProofProvider(config, async (cmd, args): Promise<CommandResult> => {
      calls.push({ cmd, args });
      return {
        stdout: JSON.stringify({
          kind: "showdown",
          args: {
            playerStateCommitment: "0x" + "11".repeat(32),
            dealerStateCommitment: "0x" + "22".repeat(32),
            payout: "200",
            dealerFinalValue: "18",
            playerCards: ["7", "16", "32", "52", "52", "52", "52", "52"],
            dealerCards: ["9", "3", "16", "52"],
            handCount: "1",
            activeHandIndex: "0",
            handStatuses: ["4", "0", "0", "0"],
            handValues: ["19", "0", "0", "0"],
            handCardCounts: ["3", "0", "0", "0"],
            handPayoutKinds: ["3", "0", "0", "0"],
            dealerRevealMask: "7",
            proof: "0x1234"
          }
        }),
        stderr: "",
        exitCode: 0
      };
    });

    const job: ProofJobRecord = {
      id: "job-1",
      jobType: "blackjack-showdown",
      mode: "live",
      status: "queued",
      createdAt: "now",
      updatedAt: "now",
      payload: {
        witness: {
          sessionId: "1",
          proofSequence: "2",
          playerCards: ["7", "16", "32", "52", "52", "52", "52", "52"],
          handCardCounts: ["3", "0", "0", "0"],
          dealerPrivateCards: ["9", "3", "16", "52"],
          playerSalt: "1004",
          dealerSalt: "1005",
          handWagers: ["100", "0", "0", "0"],
          handCount: "1",
          activeHandIndex: "0"
        }
      }
    };

    const resolved = await provider.execute(job);
    expect(calls[0]).toEqual({
      cmd: "bun",
      args: ["run", "--cwd", "zk", "prove:blackjack", "--phase", "showdown", "--witness", path.join(config.jobsDir, "job-1-showdown-witness.json")]
    });
    expect((resolved as { payloadPath: string }).payloadPath).toBe(path.join(config.jobsDir, "job-1-showdown-payload.json"));
    expect(await Bun.file((resolved as { payloadPath: string }).payloadPath).json()).toMatchObject({
      kind: "showdown"
    });

    rmSync(tempDir, { recursive: true, force: true });
  });

  test("fixture provider keeps using generated fixture payloads", async () => {
    const tempDir = mkdtempSync(path.join(os.tmpdir(), "scuro-fixture-proof-"));
    const config = makeConfig(tempDir);
    mkdirSync(path.join(tempDir, "zk", "fixtures", "generated"), { recursive: true });
    writeFileSync(path.join(tempDir, "zk", "fixtures", "generated", "blackjack_initial_deal.json"), "{}");
    const provider = new FixtureProofProvider({ ...config, repoRoot: tempDir });
    const resolved = await provider.execute({
      id: "job-2",
      jobType: "blackjack-initial-deal",
      mode: "fixture",
      status: "queued",
      createdAt: "now",
      updatedAt: "now"
    });

    expect((resolved as { fixtureName: string }).fixtureName).toBe("blackjack_initial_deal");
    rmSync(tempDir, { recursive: true, force: true });
  });
});
