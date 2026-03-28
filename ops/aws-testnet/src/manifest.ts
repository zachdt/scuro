import type { AppConfig } from "./config";
import { readJsonFile, writeJsonFile } from "./fs";
import type { DeploymentManifest } from "./types";

const LABELS = [
  "ScuroToken",
  "ScuroStakingToken",
  "TimelockController",
  "ScuroGovernor",
  "GameCatalog",
  "GameDeploymentFactory",
  "DeveloperExpressionRegistry",
  "DeveloperRewards",
  "ProtocolSettlement",
  "TournamentController",
  "TournamentPokerEngine",
  "TournamentPokerVerifierBundle",
  "PvPController",
  "PvPPokerEngine",
  "PvPPokerVerifierBundle",
  "VRFCoordinatorMock",
  "NumberPickerEngine",
  "NumberPickerAdapter",
  "BlackjackVerifierBundle",
  "SingleDeckBlackjackEngine",
  "BlackjackController",
  "NumberPickerModuleId",
  "TournamentPokerModuleId",
  "PvPPokerModuleId",
  "BlackjackModuleId",
  "Admin",
  "Player1",
  "Player2",
  "SoloDeveloper",
  "PokerDeveloper",
  "NumberPickerExpressionTokenId",
  "PokerExpressionTokenId",
  "BlackjackExpressionTokenId"
];

const ACTOR_LABELS = [
  "Admin",
  "Player1",
  "Player2",
  "SoloDeveloper",
  "PokerDeveloper"
];

export function parseDeployOutput(output: string): Record<string, string> {
  const wanted = new Set(LABELS);
  const parsed: Record<string, string> = {};

  for (const line of output.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed) {
      continue;
    }
    const [label, value] = trimmed.split(/\s+/, 2);
    if (wanted.has(label) && value) {
      parsed[label] = value;
    }
  }

  return parsed;
}

export function buildManifest(
  contracts: Record<string, string>,
  config: AppConfig,
  deployment?:
    | {
        status: "completed" | "failed";
        stages: Array<{ name: string; status: "completed" | "failed" }>;
        failedStage?: string;
        error?: string;
      }
    | undefined
): DeploymentManifest {
  const actors: Record<string, string> = {};
  for (const label of ACTOR_LABELS) {
    if (contracts[label]) {
      actors[label] = contracts[label];
    }
  }

  return {
    chain: {
      rpcUrl: config.rpcUrl,
      chainId: config.chainId,
      deployedAt: new Date().toISOString()
    },
    aws: {
      region: config.awsRegion,
      stackName: config.awsStackName,
      ssmTargetInstanceId: config.ssmTargetInstanceId,
      operatorPort: config.operatorPort,
      queueMode: config.queueMode,
      queueUrl: config.sqsQueueUrl,
      proofQueueName: config.proofQueueName,
      snapshotBucket: config.snapshotBucket,
      snapshotPrefix: config.snapshotPrefix
    },
    contracts,
    actors,
    ...(deployment
      ? {
          deploymentStatus: deployment.status,
          deploymentStages: deployment.stages,
          ...(deployment.failedStage ? { failedStage: deployment.failedStage } : {}),
          ...(deployment.error ? { deploymentError: deployment.error } : {})
        }
      : {})
  };
}

export async function writeManifest(manifestPath: string, manifest: DeploymentManifest): Promise<void> {
  await writeJsonFile(manifestPath, manifest);
}

export async function loadManifest(manifestPath: string): Promise<DeploymentManifest | null> {
  return readJsonFile<DeploymentManifest>(manifestPath);
}
