import { appendFile, rm } from "node:fs/promises";
import path from "node:path";
import type { AppConfig } from "./config";
import type { CommandRunner } from "./exec";
import { runCommand } from "./exec";
import { notFound } from "./errors";
import { buildManifest, loadManifest, parseDeployOutput, writeManifest } from "./manifest";
import type { DeploymentManifest } from "./types";

const MAX_UINT256 =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";
const PREALLOCATED_NATIVE_BALANCE = `0x${(10_000n * 10n ** 18n).toString(16)}`;

interface DeployStage {
  name: string;
  target: string;
}

const DEPLOY_STAGES: DeployStage[] = [
  { name: "core", target: "script/aws/DeployCore.s.sol:DeployCore" },
  { name: "number-picker", target: "script/aws/DeployNumberPickerModule.s.sol:DeployNumberPickerModule" },
  { name: "slot", target: "script/aws/DeploySlotModule.s.sol:DeploySlotModule" },
  { name: "finalize", target: "script/aws/DeployFinalize.s.sol:DeployFinalize" }
];

function deployEnv(config: AppConfig): Record<string, string> {
  return {
    PRIVATE_KEY: config.adminPrivateKey,
    PLAYER1_PRIVATE_KEY: config.player1PrivateKey,
    PLAYER2_PRIVATE_KEY: config.player2PrivateKey
  };
}

function mergeContracts(
  current: Record<string, string>,
  next: Record<string, string>
): Record<string, string> {
  return { ...current, ...next };
}

function deployStageEnv(
  config: AppConfig,
  contracts: Record<string, string>
): Record<string, string> {
  return {
    ...deployEnv(config),
    ...contracts
  };
}

function combineStageOutput(stageOutput: string, bufferedOutput: string): string {
  const normalizedStageOutput = stageOutput.trimEnd();
  const normalizedBufferedOutput = bufferedOutput.trimEnd();

  if (!normalizedStageOutput) {
    return normalizedBufferedOutput;
  }
  if (!normalizedBufferedOutput) {
    return normalizedStageOutput;
  }
  if (normalizedStageOutput.includes(normalizedBufferedOutput)) {
    return normalizedStageOutput;
  }
  if (normalizedBufferedOutput.includes(normalizedStageOutput)) {
    return normalizedBufferedOutput;
  }
  return `${normalizedStageOutput}\n${normalizedBufferedOutput}`;
}

async function privateKeyToAddress(
  privateKey: string,
  deps: ProtocolDeps
): Promise<string> {
  const result = await deps.commandRunner("cast", ["wallet", "address", "--private-key", privateKey]);
  return result.stdout.trim();
}

async function fundAddress(
  address: string,
  config: AppConfig,
  deps: ProtocolDeps
): Promise<void> {
  await deps.commandRunner("cast", [
    "rpc",
    "--rpc-url",
    config.rpcUrl,
    "anvil_setBalance",
    `["${address}","${PREALLOCATED_NATIVE_BALANCE}"]`,
    "--raw"
  ]);
}

async function ensureFundedAccounts(
  config: AppConfig,
  deps: ProtocolDeps
): Promise<void> {
  const privateKeys = [...new Set([
    config.adminPrivateKey,
    config.player1PrivateKey,
    config.player2PrivateKey
  ])];

  for (const privateKey of privateKeys) {
    const address = await privateKeyToAddress(privateKey, deps);
    await fundAddress(address, config, deps);
  }
}

function normalizeSnapshotState(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) {
    throw new Error("snapshot state is empty");
  }

  let normalized = trimmed;
  if (normalized.startsWith("\"") && normalized.endsWith("\"")) {
    try {
      const parsed = JSON.parse(normalized);
      if (typeof parsed === "string" && parsed.trim()) {
        normalized = parsed.trim();
      }
    } catch {
      // Keep the raw value if it was not valid JSON.
    }
  }

  if (!normalized.startsWith("0x")) {
    normalized = `0x${normalized}`;
  }

  return normalized;
}

function smokeEnv(config: AppConfig, manifest: DeploymentManifest): Record<string, string> {
  return {
    PRIVATE_KEY: config.adminPrivateKey,
    PLAYER1_PRIVATE_KEY: config.player1PrivateKey,
    PLAYER2_PRIVATE_KEY: config.player2PrivateKey,
    SCURO_TOKEN: manifest.contracts.ScuroToken,
    SCURO_STAKING_TOKEN: manifest.contracts.ScuroStakingToken,
    PROTOCOL_SETTLEMENT: manifest.contracts.ProtocolSettlement,
    GAME_CATALOG: manifest.contracts.GameCatalog,
    DEVELOPER_REWARDS: manifest.contracts.DeveloperRewards,
    NUMBER_PICKER_ADAPTER: manifest.contracts.NumberPickerAdapter,
    NUMBER_PICKER_ENGINE: manifest.contracts.NumberPickerEngine,
    SLOT_MACHINE_CONTROLLER: manifest.contracts.SlotMachineController,
    SLOT_MACHINE_ENGINE: manifest.contracts.SlotMachineEngine,
    SOLO_DEVELOPER: manifest.contracts.SoloDeveloper,
    NUMBER_PICKER_EXPRESSION_TOKEN_ID: manifest.contracts.NumberPickerExpressionTokenId,
    SLOT_MACHINE_EXPRESSION_TOKEN_ID: manifest.contracts.SlotMachineExpressionTokenId,
    SLOT_BASE_PRESET_ID: manifest.contracts.SlotBasePresetId
  };
}

export interface ProtocolDeps {
  commandRunner: CommandRunner;
  rpcRequest: (config: AppConfig, method: string, params: unknown[]) => Promise<unknown>;
  loadManifest: typeof loadManifest;
  writeManifest: typeof writeManifest;
}

async function defaultRpcRequest(
  config: AppConfig,
  method: string,
  params: unknown[]
): Promise<unknown> {
  const response = await fetch(config.rpcUrl, {
    method: "POST",
    headers: {
      "content-type": "application/json"
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method,
      params,
      id: 1
    })
  });

  const payload = await response.json() as { result?: unknown; error?: unknown };
  if (!response.ok) {
    throw new Error(`rpc request failed: ${method} (${response.status})`);
  }
  if ("error" in payload && payload.error !== undefined) {
    throw new Error(`rpc request failed: ${method}\n${JSON.stringify(payload.error)}`);
  }
  return payload.result;
}

function withProtocolDeps(overrides: Partial<ProtocolDeps> = {}): ProtocolDeps {
  return {
    commandRunner: runCommand,
    rpcRequest: defaultRpcRequest,
    loadManifest,
    writeManifest,
    ...overrides
  };
}

async function rpc(
  method: string,
  params: unknown[],
  config: AppConfig,
  deps: ProtocolDeps
): Promise<unknown> {
  const result = await deps.commandRunner("cast", [
    "rpc",
    "--rpc-url",
    config.rpcUrl,
    method,
    JSON.stringify(params)
  ]);
  return result.stdout.trim();
}

export async function checkChainHealth(
  config: AppConfig,
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<Record<string, unknown>> {
  const deps = withProtocolDeps(depsOverrides);
  const chainId = await deps.commandRunner("cast", ["rpc", "--rpc-url", config.rpcUrl, "eth_chainId"]);
  return {
    rpcUrl: config.rpcUrl,
    chainId: chainId.stdout.trim()
  };
}

export async function deployProtocol(
  config: AppConfig,
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<DeploymentManifest> {
  const deps = withProtocolDeps(depsOverrides);
  await Bun.write(config.deployLogPath, "");
  await ensureFundedAccounts(config, deps);
  let contracts: Record<string, string> = {};
  const deploymentStages: Array<{ name: string; status: "completed" | "failed" }> = [];

  for (const stage of DEPLOY_STAGES) {
    const stageLogPath = path.join(config.stateDir, `deploy-${stage.name}.log`);
    await appendFile(config.deployLogPath, `\n==== deploy stage: ${stage.name} ====\n`);
    const result = await deps.commandRunner(
      "forge",
      [
        "script",
        stage.target,
        "--rpc-url",
        config.rpcUrl,
        "--broadcast",
        "--offline",
        "--skip-simulation",
        "--non-interactive",
        "--disable-code-size-limit"
      ],
      {
        cwd: config.repoRoot,
        env: deployStageEnv(config, contracts),
        allowFailure: true,
        streamOutputToPath: stageLogPath
      }
    );

    const bufferedOutput = [result.stdout, result.stderr].filter(Boolean).join("\n");
    const stageLog = Bun.file(stageLogPath);
    const stageOutput = (await stageLog.exists()) ? await stageLog.text() : "";
    const combinedStageOutput = combineStageOutput(stageOutput, bufferedOutput);
    if (combinedStageOutput) {
      await appendFile(
        config.deployLogPath,
        combinedStageOutput.endsWith("\n") ? combinedStageOutput : `${combinedStageOutput}\n`
      );
    }
    contracts = mergeContracts(contracts, parseDeployOutput(combinedStageOutput));
    await rm(stageLogPath, { force: true });

    if (result.exitCode !== 0) {
      deploymentStages.push({ name: stage.name, status: "failed" });
      const deploymentError = `deploy stage failed: ${stage.name}\n${combinedStageOutput}`;
      const partialManifest = buildManifest(contracts, config, {
        status: "failed",
        stages: deploymentStages,
        failedStage: stage.name,
        error: deploymentError
      });
      await deps.writeManifest(config.manifestPath, partialManifest);
      throw new Error(deploymentError);
    }

    deploymentStages.push({ name: stage.name, status: "completed" });
  }

  if (!contracts.ScuroToken || !contracts.NumberPickerAdapter || !contracts.SlotMachineController) {
    throw new Error("failed to assemble staged deployment output");
  }

  const manifest = buildManifest(contracts, config, {
    status: "completed",
    stages: deploymentStages
  });
  await deps.writeManifest(config.manifestPath, manifest);
  return manifest;
}

export async function seedApprovals(
  config: AppConfig,
  manifest?: DeploymentManifest,
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<void> {
  const deps = withProtocolDeps(depsOverrides);
  await ensureFundedAccounts(config, deps);
  const activeManifest = manifest ?? (await deps.loadManifest(config.manifestPath));
  if (!activeManifest) {
    throw notFound("manifest not found");
  }

  const token = activeManifest.contracts.ScuroToken;
  const settlement = activeManifest.contracts.ProtocolSettlement;
  const staking = activeManifest.contracts.ScuroStakingToken;

  const approvals = [
    [config.adminPrivateKey, settlement],
    [config.player1PrivateKey, settlement],
    [config.player2PrivateKey, settlement],
    [config.adminPrivateKey, staking]
  ] as const;

  for (const [privateKey, spender] of approvals) {
    await deps.commandRunner("cast", [
      "send",
      token,
      "approve(address,uint256)",
      spender,
      MAX_UINT256,
      "--private-key",
      privateKey,
      "--rpc-url",
      config.rpcUrl
    ]);
  }
}

export async function resetAndDeploy(
  config: AppConfig,
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<DeploymentManifest> {
  const deps = withProtocolDeps(depsOverrides);
  await rpc("anvil_reset", [], config, deps);
  const manifest = await deployProtocol(config, deps);
  await seedApprovals(config, manifest, deps);
  return manifest;
}

export async function exportSnapshot(
  config: AppConfig,
  name?: string,
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<Record<string, string>> {
  const deps = withProtocolDeps(depsOverrides);
  const snapshotName = name ?? new Date().toISOString().replace(/[:.]/g, "-");
  const localPath = path.join(config.snapshotsDir, `${snapshotName}.json`);
  const state = normalizeSnapshotState(String(await deps.rpcRequest(config, "anvil_dumpState", [])));

  await Bun.write(localPath, state + "\n");

  let s3Path: string | undefined;
  if (config.snapshotBucket) {
    s3Path = `s3://${config.snapshotBucket}/${config.snapshotPrefix}/${snapshotName}.json`;
    await deps.commandRunner("aws", [
      "s3",
      "cp",
      localPath,
      s3Path,
      ...(config.awsRegion ? ["--region", config.awsRegion] : [])
    ]);
  }

  return { snapshotName, localPath, ...(s3Path ? { s3Path } : {}) };
}

export async function restoreSnapshot(
  config: AppConfig,
  options: { name?: string; s3Key?: string },
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<Record<string, string>> {
  const deps = withProtocolDeps(depsOverrides);
  const snapshotName = options.name ?? "latest";
  const localPath = path.join(config.snapshotsDir, `${snapshotName}.json`);

  if (options.s3Key) {
    await deps.commandRunner("aws", [
      "s3",
      "cp",
      `s3://${config.snapshotBucket}/${options.s3Key}`,
      localPath,
      ...(config.awsRegion ? ["--region", config.awsRegion] : [])
    ]);
  }

  const state = normalizeSnapshotState(await Bun.file(localPath).text());
  await deps.rpcRequest(config, "anvil_reset", []);
  await deps.rpcRequest(config, "anvil_loadState", [state]);

  return { snapshotName, localPath };
}

async function runSmokeScript(
  target: string,
  config: AppConfig,
  manifest: DeploymentManifest,
  deps: ProtocolDeps
): Promise<Record<string, string>> {
  await ensureFundedAccounts(config, deps);
  await deps.commandRunner(
    "forge",
    [
      "script",
      target,
      "--rpc-url",
      config.rpcUrl,
      "--broadcast",
      "--offline",
      "--skip-simulation",
      "--non-interactive",
      "--disable-code-size-limit"
    ],
    {
      cwd: config.repoRoot,
      env: smokeEnv(config, manifest)
    }
  );
  return { script: target, status: "ok" };
}

export async function runNumberPickerSmoke(
  config: AppConfig,
  manifest?: DeploymentManifest,
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<Record<string, string>> {
  const deps = withProtocolDeps(depsOverrides);
  const activeManifest = manifest ?? (await deps.loadManifest(config.manifestPath));
  if (!activeManifest) {
    throw notFound("manifest not found");
  }
  return runSmokeScript("script/aws/SmokeNumberPicker.s.sol:SmokeNumberPicker", config, activeManifest, deps);
}

export async function runSlotSmoke(
  config: AppConfig,
  manifest?: DeploymentManifest,
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<Record<string, string>> {
  const deps = withProtocolDeps(depsOverrides);
  const activeManifest = manifest ?? (await deps.loadManifest(config.manifestPath));
  if (!activeManifest) {
    throw notFound("manifest not found");
  }
  return runSmokeScript("script/aws/SmokeSlot.s.sol:SmokeSlot", config, activeManifest, deps);
}
