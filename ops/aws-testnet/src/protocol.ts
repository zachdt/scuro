import path from "node:path";
import type { AppConfig } from "./config";
import type { CommandRunner } from "./exec";
import { runCommand } from "./exec";
import { notFound } from "./errors";
import { buildManifest, loadManifest, parseDeployOutput, writeManifest } from "./manifest";
import type { DeploymentManifest } from "./types";

const MAX_UINT256 =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

function deployEnv(config: AppConfig): Record<string, string> {
  return {
    PRIVATE_KEY: config.adminPrivateKey
  };
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
    TOURNAMENT_CONTROLLER: manifest.contracts.TournamentController,
    TOURNAMENT_POKER_ENGINE: manifest.contracts.TournamentPokerEngine,
    TOURNAMENT_POKER_VERIFIER_BUNDLE: manifest.contracts.TournamentPokerVerifierBundle,
    BLACKJACK_CONTROLLER: manifest.contracts.BlackjackController,
    BLACKJACK_ENGINE: manifest.contracts.SingleDeckBlackjackEngine,
    BLACKJACK_VERIFIER_BUNDLE: manifest.contracts.BlackjackVerifierBundle,
    SOLO_DEVELOPER: manifest.contracts.SoloDeveloper,
    POKER_DEVELOPER: manifest.contracts.PokerDeveloper,
    NUMBER_PICKER_EXPRESSION_TOKEN_ID: manifest.contracts.NumberPickerExpressionTokenId,
    POKER_EXPRESSION_TOKEN_ID: manifest.contracts.PokerExpressionTokenId,
    BLACKJACK_EXPRESSION_TOKEN_ID: manifest.contracts.BlackjackExpressionTokenId
  };
}

export interface ProtocolDeps {
  commandRunner: CommandRunner;
  loadManifest: typeof loadManifest;
  writeManifest: typeof writeManifest;
}

function withProtocolDeps(overrides: Partial<ProtocolDeps> = {}): ProtocolDeps {
  return {
    commandRunner: runCommand,
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
  const result = await deps.commandRunner(
    "forge",
    [
      "script",
      "script/DeployLocal.s.sol:DeployLocal",
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
      env: deployEnv(config),
      allowFailure: true,
      streamOutputToPath: config.deployLogPath
    }
  );

  const output = [result.stdout, result.stderr].filter(Boolean).join("\n");

  if (result.exitCode !== 0) {
    throw new Error(`deploy failed\n${output}`);
  }

  const contracts = parseDeployOutput(output);
  if (!contracts.ScuroToken) {
    throw new Error("failed to parse deployment output");
  }

  const manifest = buildManifest(contracts, config);
  await deps.writeManifest(config.manifestPath, manifest);
  return manifest;
}

export async function seedApprovals(
  config: AppConfig,
  manifest?: DeploymentManifest,
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<void> {
  const deps = withProtocolDeps(depsOverrides);
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
  const state = (await deps.commandRunner("cast", [
    "rpc",
    "--rpc-url",
    config.rpcUrl,
    "anvil_dumpState"
  ])).stdout.trim();

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

  const state = await Bun.file(localPath).text();
  await deps.commandRunner("cast", [
    "rpc",
    "--rpc-url",
    config.rpcUrl,
    "anvil_loadState",
    state.trim()
  ]);

  return { snapshotName, localPath };
}

async function runSmokeScript(
  target: string,
  config: AppConfig,
  manifest: DeploymentManifest,
  deps: ProtocolDeps
): Promise<Record<string, string>> {
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

export async function runPokerSmoke(
  config: AppConfig,
  manifest?: DeploymentManifest,
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<Record<string, string>> {
  const deps = withProtocolDeps(depsOverrides);
  const activeManifest = manifest ?? (await deps.loadManifest(config.manifestPath));
  if (!activeManifest) {
    throw notFound("manifest not found");
  }
  return runSmokeScript("script/aws/SmokePokerFixture.s.sol:SmokePokerFixture", config, activeManifest, deps);
}

export async function runBlackjackSmoke(
  config: AppConfig,
  manifest?: DeploymentManifest,
  depsOverrides: Partial<ProtocolDeps> = {}
): Promise<Record<string, string>> {
  const deps = withProtocolDeps(depsOverrides);
  const activeManifest = manifest ?? (await deps.loadManifest(config.manifestPath));
  if (!activeManifest) {
    throw notFound("manifest not found");
  }
  return runSmokeScript("script/aws/SmokeBlackjackFixture.s.sol:SmokeBlackjackFixture", config, activeManifest, deps);
}
