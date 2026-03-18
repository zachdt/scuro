import path from "node:path";
import type { AppConfig } from "./config";
import { runCommand } from "./exec";
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

async function rpc(method: string, params: unknown[], config: AppConfig): Promise<unknown> {
  const result = await runCommand("cast", [
    "rpc",
    "--rpc-url",
    config.rpcUrl,
    method,
    JSON.stringify(params)
  ]);
  return result.stdout.trim();
}

export async function checkChainHealth(config: AppConfig): Promise<Record<string, unknown>> {
  const chainId = await runCommand("cast", ["rpc", "--rpc-url", config.rpcUrl, "eth_chainId"]);
  return {
    rpcUrl: config.rpcUrl,
    chainId: chainId.stdout.trim()
  };
}

export async function deployProtocol(config: AppConfig): Promise<DeploymentManifest> {
  const result = await runCommand(
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
      env: deployEnv(config)
    }
  );

  const output = [result.stdout, result.stderr].filter(Boolean).join("\n");
  await Bun.write(config.deployLogPath, output);

  const contracts = parseDeployOutput(output);
  if (!contracts.ScuroToken) {
    throw new Error("failed to parse deployment output");
  }

  const manifest = buildManifest(contracts, config);
  await writeManifest(config.manifestPath, manifest);
  return manifest;
}

export async function seedApprovals(config: AppConfig, manifest?: DeploymentManifest): Promise<void> {
  const activeManifest = manifest ?? (await loadManifest(config.manifestPath));
  if (!activeManifest) {
    throw new Error("manifest not found");
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
    await runCommand("cast", [
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

export async function resetAndDeploy(config: AppConfig): Promise<DeploymentManifest> {
  await rpc("anvil_reset", [], config);
  const manifest = await deployProtocol(config);
  await seedApprovals(config, manifest);
  return manifest;
}

export async function exportSnapshot(config: AppConfig, name?: string): Promise<Record<string, string>> {
  const snapshotName = name ?? new Date().toISOString().replace(/[:.]/g, "-");
  const localPath = path.join(config.snapshotsDir, `${snapshotName}.json`);
  const state = (await runCommand("cast", [
    "rpc",
    "--rpc-url",
    config.rpcUrl,
    "anvil_dumpState"
  ])).stdout.trim();

  await Bun.write(localPath, state + "\n");

  let s3Path: string | undefined;
  if (config.snapshotBucket) {
    s3Path = `s3://${config.snapshotBucket}/${config.snapshotPrefix}/${snapshotName}.json`;
    await runCommand("aws", [
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
  options: { name?: string; s3Key?: string }
): Promise<Record<string, string>> {
  const snapshotName = options.name ?? "latest";
  const localPath = path.join(config.snapshotsDir, `${snapshotName}.json`);

  if (options.s3Key) {
    await runCommand("aws", [
      "s3",
      "cp",
      `s3://${config.snapshotBucket}/${options.s3Key}`,
      localPath,
      ...(config.awsRegion ? ["--region", config.awsRegion] : [])
    ]);
  }

  const state = await Bun.file(localPath).text();
  await runCommand("cast", [
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
  manifest: DeploymentManifest
): Promise<Record<string, string>> {
  await runCommand(
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
  manifest?: DeploymentManifest
): Promise<Record<string, string>> {
  const activeManifest = manifest ?? (await loadManifest(config.manifestPath));
  if (!activeManifest) {
    throw new Error("manifest not found");
  }
  return runSmokeScript("script/aws/SmokeNumberPicker.s.sol:SmokeNumberPicker", config, activeManifest);
}

export async function runPokerSmoke(
  config: AppConfig,
  manifest?: DeploymentManifest
): Promise<Record<string, string>> {
  const activeManifest = manifest ?? (await loadManifest(config.manifestPath));
  if (!activeManifest) {
    throw new Error("manifest not found");
  }
  return runSmokeScript("script/aws/SmokePokerFixture.s.sol:SmokePokerFixture", config, activeManifest);
}

export async function runBlackjackSmoke(
  config: AppConfig,
  manifest?: DeploymentManifest
): Promise<Record<string, string>> {
  const activeManifest = manifest ?? (await loadManifest(config.manifestPath));
  if (!activeManifest) {
    throw new Error("manifest not found");
  }
  return runSmokeScript("script/aws/SmokeBlackjackFixture.s.sol:SmokeBlackjackFixture", config, activeManifest);
}
