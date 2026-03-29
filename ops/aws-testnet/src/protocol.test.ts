import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import os from "node:os";
import { parseDeployOutput } from "./manifest";
import {
  checkChainHealth,
  deployProtocol,
  exportSnapshot,
  restoreSnapshot,
  runPokerSmoke,
  seedApprovals
} from "./protocol";
import { processJob } from "./worker-jobs";
import type { AppConfig } from "./config";
import type { CommandOptions, CommandResult } from "./exec";
import type { DeploymentManifest, ProofJobRecord } from "./types";

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
    awsRegion: "us-east-2",
    awsStackName: "scuro-testnet",
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

function makeManifest(): DeploymentManifest {
  return {
    chain: {
      rpcUrl: "http://127.0.0.1:8545",
      chainId: 31337,
      deployedAt: "2024-01-01T00:00:00.000Z"
    },
    aws: {
      region: "us-east-2",
      operatorPort: 8787,
      queueMode: "file"
    },
    contracts: {
      ScuroToken: "0x1",
      GameDeploymentFactory: "0x16",
      ProtocolSettlement: "0x2",
      ScuroStakingToken: "0x3",
      NumberPickerAdapter: "0x4",
      NumberPickerEngine: "0x5",
      TournamentController: "0x6",
      TournamentPokerEngine: "0x7",
      TournamentPokerVerifierBundle: "0x8",
      BlackjackController: "0x9",
      SingleDeckBlackjackEngine: "0x10",
      BlackjackVerifierBundle: "0x11",
      DeveloperRewards: "0x12",
      GameCatalog: "0x13",
      SoloDeveloper: "0x14",
      PokerDeveloper: "0x15",
      NumberPickerExpressionTokenId: "1",
      PokerExpressionTokenId: "2",
      BlackjackExpressionTokenId: "3"
    },
    actors: {
      Admin: "0xabc"
    }
  };
}

describe("protocol and worker-job verification", () => {
  test("parses deployment output", () => {
    const parsed = parseDeployOutput("ScuroToken 0x1\nPlayer1 0x2\nIgnored value");
    expect(parsed.ScuroToken).toBe("0x1");
    expect(parsed.Player1).toBe("0x2");
  });

  test("assembles chain health command", async () => {
    const calls: Array<{ cmd: string; args: string[] }> = [];
    const health = await checkChainHealth(makeConfig("/tmp/state"), {
      async commandRunner(cmd: string, args: string[]): Promise<CommandResult> {
        calls.push({ cmd, args });
        return { stdout: "0x7a69\n", stderr: "", exitCode: 0 };
      }
    });
    expect(health.chainId).toBe("0x7a69");
    expect(calls[0]).toEqual({
      cmd: "cast",
      args: ["rpc", "--rpc-url", "http://127.0.0.1:8545", "eth_chainId"]
    });
  });

  test("assembles deploy and smoke commands", async () => {
    const calls: Array<{ cmd: string; args: string[]; options?: CommandOptions }> = [];
    const tempDir = mkdtempSync(path.join(os.tmpdir(), "scuro-protocol-"));
    const config = makeConfig(tempDir);
    const manifest = await deployProtocol(config, {
      async commandRunner(cmd, args, options) {
        calls.push({ cmd, args, options });
        if (cmd === "cast" && args[0] === "wallet" && args[1] === "address") {
          const privateKey = args[3];
          return {
            stdout: `${privateKey}-address\n`,
            stderr: "",
            exitCode: 0
          };
        }
        if (cmd === "cast" && args[0] === "rpc" && args[3] === "anvil_setBalance") {
          return {
            stdout: "true\n",
            stderr: "",
            exitCode: 0
          };
        }
        const target = args[1];
        const stageOutputForTarget = (() => {
          if (target === "script/aws/DeployCore.s.sol:DeployCore") {
            return [
              "ScuroToken 0x1",
              "ScuroStakingToken 0x2",
              "TimelockController 0x3",
              "ScuroGovernor 0x4",
              "GameCatalog 0x5",
              "GameDeploymentFactory 0x16",
              "DeveloperExpressionRegistry 0x6",
              "DeveloperRewards 0x7",
              "ProtocolSettlement 0x8",
              "VRFCoordinatorMock 0x9"
            ].join("\n");
          }
          if (target === "script/aws/DeployNumberPickerModule.s.sol:DeployNumberPickerModule") {
            return "NumberPickerEngine 0x10\nNumberPickerAdapter 0x11\nNumberPickerModuleId 1\n";
          }
          if (target === "script/aws/DeployPokerTournamentModule.s.sol:DeployPokerTournamentModule") {
            return "TournamentController 0x12\nTournamentPokerEngine 0x13\nTournamentPokerVerifierBundle 0x14\nTournamentPokerModuleId 2\n";
          }
          if (target === "script/aws/DeployPokerPvPModule.s.sol:DeployPokerPvPModule") {
            return "PvPController 0x15\nPvPPokerEngine 0x16\nPvPPokerVerifierBundle 0x17\nPvPPokerModuleId 3\n";
          }
          if (target === "script/aws/DeployBlackjackModule.s.sol:DeployBlackjackModule") {
            return "BlackjackVerifierBundle 0x18\nSingleDeckBlackjackEngine 0x19\nBlackjackController 0x20\nBlackjackModuleId 4\n";
          }
          if (target === "script/aws/DeployFinalize.s.sol:DeployFinalize") {
            return [
              "GameDeploymentFactory 0x16",
              "Admin 0xabc",
              "Player1 0xdef",
              "Player2 0xghi",
              "SoloDeveloper 0xjkl",
              "PokerDeveloper 0xmno",
              "NumberPickerExpressionTokenId 11",
              "PokerExpressionTokenId 12",
              "BlackjackExpressionTokenId 13"
            ].join("\n");
          }
          return "";
        })();
        if (options?.streamOutputToPath && stageOutputForTarget) {
          writeFileSync(options.streamOutputToPath, stageOutputForTarget);
        }
        if (target === "script/aws/DeployCore.s.sol:DeployCore") {
          return {
            stdout: "verbose tail without labels",
            stderr: "",
            exitCode: 0
          };
        }
        if (target === "script/aws/DeployNumberPickerModule.s.sol:DeployNumberPickerModule") {
          return {
            stdout: "verbose tail without labels",
            stderr: "",
            exitCode: 0
          };
        }
        if (target === "script/aws/DeployPokerTournamentModule.s.sol:DeployPokerTournamentModule") {
          return {
            stdout: "verbose tail without labels",
            stderr: "",
            exitCode: 0
          };
        }
        if (target === "script/aws/DeployPokerPvPModule.s.sol:DeployPokerPvPModule") {
          return {
            stdout: "verbose tail without labels",
            stderr: "",
            exitCode: 0
          };
        }
        if (target === "script/aws/DeployBlackjackModule.s.sol:DeployBlackjackModule") {
          return {
            stdout: "verbose tail without labels",
            stderr: "",
            exitCode: 0
          };
        }
        if (target === "script/aws/DeployFinalize.s.sol:DeployFinalize") {
          return {
            stdout: "verbose tail without labels",
            stderr: "",
            exitCode: 0
          };
        }
        return {
          stdout: "",
          stderr: "",
          exitCode: 0
        };
      }
    });

    expect(manifest.contracts.ScuroToken).toBe("0x1");
    expect(manifest.contracts.GameDeploymentFactory).toBe("0x16");
    expect(calls.filter((call) => call.cmd === "forge")).toHaveLength(6);
    const forgeCalls = calls.filter((call) => call.cmd === "forge");
    expect(forgeCalls[0]?.args[1]).toBe("script/aws/DeployCore.s.sol:DeployCore");
    expect(forgeCalls[5]?.args[1]).toBe("script/aws/DeployFinalize.s.sol:DeployFinalize");
    expect(forgeCalls[0]?.options?.streamOutputToPath).toBe(path.join(config.stateDir, "deploy-core.log"));
    expect(forgeCalls[0]?.args.includes("-vvvv")).toBe(false);
    expect(calls.filter((call) => call.cmd === "cast" && call.args[1] === "address")).toHaveLength(3);
    expect(calls.filter((call) => call.cmd === "cast" && call.args[3] === "anvil_setBalance")).toHaveLength(3);
    expect(manifest.deploymentStatus).toBe("completed");
    expect(manifest.deploymentStages?.every((stage) => stage.status === "completed")).toBe(true);

    await runPokerSmoke(config, makeManifest(), {
      async commandRunner(cmd, args, options) {
        calls.push({ cmd, args, options });
        if (cmd === "cast" && args[0] === "wallet" && args[1] === "address") {
          const privateKey = args[3];
          return {
            stdout: `${privateKey}-address\n`,
            stderr: "",
            exitCode: 0
          };
        }
        if (cmd === "cast" && args[0] === "rpc" && args[3] === "anvil_setBalance") {
          return { stdout: "true\n", stderr: "", exitCode: 0 };
        }
        return { stdout: "", stderr: "", exitCode: 0 };
      }
    });

    expect(calls.some((call) => call.args.includes("script/aws/SmokePokerFixture.s.sol:SmokePokerFixture"))).toBe(true);
    rmSync(tempDir, { recursive: true, force: true });
  });

  test("persists partial manifest when a deploy stage fails", async () => {
    const tempDir = mkdtempSync(path.join(os.tmpdir(), "scuro-protocol-fail-"));
    const config = makeConfig(tempDir);
    const writes: DeploymentManifest[] = [];

    await expect(
      deployProtocol(config, {
        async commandRunner(_cmd, args, options) {
          if (_cmd === "cast" && args[0] === "wallet" && args[1] === "address") {
            return {
              stdout: `${args[3]}-address\n`,
              stderr: "",
              exitCode: 0
            };
          }
          if (_cmd === "cast" && args[0] === "rpc" && args[3] === "anvil_setBalance") {
            return { stdout: "true\n", stderr: "", exitCode: 0 };
          }
          const target = args[1];
          if (target === "script/aws/DeployCore.s.sol:DeployCore") {
            if (options?.streamOutputToPath) {
              writeFileSync(options.streamOutputToPath, [
                "ScuroToken 0x1",
                "ScuroStakingToken 0x2",
                "TimelockController 0x3",
                "ScuroGovernor 0x4",
                "GameCatalog 0x5",
                "GameDeploymentFactory 0x16",
                "DeveloperExpressionRegistry 0x6",
                "DeveloperRewards 0x7",
                "ProtocolSettlement 0x8",
                "VRFCoordinatorMock 0x9"
              ].join("\n"));
            }
            return {
              stdout: "truncated verbose tail",
              stderr: "",
              exitCode: 0
            };
          }
          if (options?.streamOutputToPath) {
            writeFileSync(options.streamOutputToPath, "NumberPickerEngine 0x10\nNumberPickerAdapter 0x11\n");
          }
          return {
            stdout: "truncated verbose tail",
            stderr: "execution reverted: gas limit exceeded",
            exitCode: 1
          };
        },
        async writeManifest(_manifestPath, manifest) {
          writes.push(manifest);
        }
      })
    ).rejects.toThrow("deploy stage failed: number-picker");

    expect(writes).toHaveLength(1);
    expect(writes[0]?.deploymentStatus).toBe("failed");
    expect(writes[0]?.failedStage).toBe("number-picker");
    expect(writes[0]?.deploymentStages).toEqual([
      { name: "core", status: "completed" },
      { name: "number-picker", status: "failed" }
    ]);
    expect(writes[0]?.contracts.GameDeploymentFactory).toBe("0x16");
    expect(writes[0]?.contracts.NumberPickerEngine).toBe("0x10");
    expect(writes[0]?.deploymentError).toContain("gas limit exceeded");
    rmSync(tempDir, { recursive: true, force: true });
  });

  test("assembles approval and snapshot commands", async () => {
    const calls: Array<{ cmd: string; args: string[] }> = [];
    const tempDir = mkdtempSync(path.join(os.tmpdir(), "scuro-protocol-"));
    const config = makeConfig(tempDir);
    await Bun.$`mkdir -p ${config.snapshotsDir}`.quiet();
    await seedApprovals(config, makeManifest(), {
      async commandRunner(cmd, args) {
        calls.push({ cmd, args });
        return { stdout: "", stderr: "", exitCode: 0 };
      }
    });

    expect(calls.filter((call) => call.cmd === "cast" && call.args[1] === "address").length).toBe(3);
    expect(calls.filter((call) => call.cmd === "cast" && call.args[3] === "anvil_setBalance").length).toBe(3);
    expect(calls.filter((call) => call.cmd === "cast" && call.args.includes("approve(address,uint256)")).length).toBe(4);

    await exportSnapshot(config, "snap-1", {
      async commandRunner(cmd, args) {
        calls.push({ cmd, args });
        return { stdout: "0xdeadbeef", stderr: "", exitCode: 0 };
      }
    });
    writeFileSync(path.join(config.snapshotsDir, "snap-1.json"), "0xdeadbeef\n");
    await restoreSnapshot(config, { name: "snap-1" }, {
      async commandRunner(cmd, args) {
        calls.push({ cmd, args });
        return { stdout: "", stderr: "", exitCode: 0 };
      }
    });

    expect(calls.some((call) => call.args.includes("anvil_dumpState"))).toBe(true);
    expect(calls.some((call) => call.args.includes("anvil_loadState"))).toBe(true);
    rmSync(tempDir, { recursive: true, force: true });
  });

  test("assembles fixture submission jobs and rejects live gameplay", async () => {
    const calls: Array<{ cmd: string; args: string[] }> = [];
    const tempDir = mkdtempSync(path.join(os.tmpdir(), "scuro-jobs-"));
    const config = makeConfig(tempDir);
    const job: ProofJobRecord = {
      id: "job-1",
      jobType: "poker-showdown",
      mode: "fixture",
      status: "queued",
      createdAt: "now",
      updatedAt: "now",
      payload: {
        gameId: 12,
        winnerAddress: "0x0000000000000000000000000000000000000001"
      }
    };

    await processJob(config, job, {
      fixture: {
        mode: "fixture",
        async execute() {
          return { fixtureName: "poker_showdown", payload: {} };
        }
      },
      live: {
        mode: "live",
        async execute() {
          return {};
        }
      }
    }, {
      async loadManifest() {
        return makeManifest();
      },
      async commandRunner(cmd, args) {
        calls.push({ cmd, args });
        return { stdout: "", stderr: "", exitCode: 0 };
      },
      async runNumberPickerSmoke() {
        return { status: "ok" };
      },
      async runPokerSmoke() {
        return { status: "ok" };
      },
      async runBlackjackSmoke() {
        return { status: "ok" };
      }
    });

    expect(calls.some((call) => call.args.includes("script/aws/SubmitPokerShowdown.s.sol:SubmitPokerShowdown"))).toBe(true);

    await expect(processJob(config, {
      ...job,
      id: "job-2",
      mode: "live",
      jobType: "blackjack-showdown"
    }, {
      fixture: {
        mode: "fixture",
        async execute() {
          return {};
        }
      },
      live: {
        mode: "live",
        async execute() {
          throw new Error("live mode is not enabled for gameplay jobs in v1: blackjack-showdown");
        }
      }
    })).rejects.toThrow("live mode is not enabled for gameplay jobs in v1");

    rmSync(tempDir, { recursive: true, force: true });
  });
});
