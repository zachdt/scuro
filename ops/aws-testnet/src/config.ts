import path from "node:path";

const DEFAULT_ADMIN_KEY =
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const DEFAULT_PLAYER1_KEY =
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
const DEFAULT_PLAYER2_KEY =
  "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";

function parseNumber(value: string | undefined, fallback: number): number {
  if (!value) {
    return fallback;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function inferRepoRoot(): string {
  return path.resolve(import.meta.dir, "../../..");
}

export interface AppConfig {
  repoRoot: string;
  serviceRoot: string;
  stateDir: string;
  jobsDir: string;
  queueDir: string;
  snapshotsDir: string;
  manifestPath: string;
  deployLogPath: string;
  operatorHost: string;
  operatorPort: number;
  rpcUrl: string;
  chainId: number;
  awsRegion?: string;
  awsStackName?: string;
  ssmTargetInstanceId?: string;
  snapshotBucket?: string;
  snapshotPrefix: string;
  sqsQueueUrl?: string;
  proofQueueName?: string;
  queueMode: "file" | "sqs";
  adminPrivateKey: string;
  player1PrivateKey: string;
  player2PrivateKey: string;
}

export function loadConfig(): AppConfig {
  const repoRoot = process.env.SCURO_REPO_ROOT ?? inferRepoRoot();
  const serviceRoot = process.env.SCURO_SERVICE_ROOT ?? path.resolve(import.meta.dir, "..");
  const stateDir = process.env.SCURO_STATE_DIR ?? path.join(repoRoot, ".scuro-testnet");
  const operatorPort = parseNumber(process.env.SCURO_OPERATOR_PORT, 8787);
  const sqsQueueUrl = process.env.SCURO_SQS_QUEUE_URL;

  return {
    repoRoot,
    serviceRoot,
    stateDir,
    jobsDir: path.join(stateDir, "jobs"),
    queueDir: path.join(stateDir, "queue"),
    snapshotsDir: path.join(stateDir, "snapshots"),
    manifestPath: path.join(stateDir, "manifest.json"),
    deployLogPath: path.join(stateDir, "deploy.log"),
    operatorHost: process.env.SCURO_OPERATOR_HOST ?? "127.0.0.1",
    operatorPort,
    rpcUrl: process.env.SCURO_RPC_URL ?? "http://127.0.0.1:8545",
    chainId: parseNumber(process.env.SCURO_CHAIN_ID, 31337),
    awsRegion: process.env.AWS_REGION ?? process.env.AWS_DEFAULT_REGION,
    awsStackName: process.env.SCURO_AWS_STACK_NAME,
    ssmTargetInstanceId: process.env.SCURO_SSM_TARGET_INSTANCE_ID,
    snapshotBucket: process.env.SCURO_SNAPSHOT_BUCKET,
    snapshotPrefix: process.env.SCURO_SNAPSHOT_PREFIX ?? "snapshots",
    sqsQueueUrl,
    proofQueueName: process.env.SCURO_PROOF_QUEUE_NAME,
    queueMode: sqsQueueUrl ? "sqs" : "file",
    adminPrivateKey: process.env.PRIVATE_KEY ?? DEFAULT_ADMIN_KEY,
    player1PrivateKey: process.env.PLAYER1_PRIVATE_KEY ?? DEFAULT_PLAYER1_KEY,
    player2PrivateKey: process.env.PLAYER2_PRIVATE_KEY ?? DEFAULT_PLAYER2_KEY
  };
}
