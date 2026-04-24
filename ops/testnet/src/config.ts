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
  deployJobsDir: string;
  snapshotsDir: string;
  manifestPath: string;
  deployLogPath: string;
  operatorHost: string;
  operatorPort: number;
  rpcUrl: string;
  chainId: number;
  snapshotPrefix: string;
  hostingProvider: string;
  hetznerServerId?: string;
  hetznerServerName?: string;
  cloudflareRpcHostname?: string;
  publicRpcUrl?: string;
  adminPrivateKey: string;
  player1PrivateKey: string;
  player2PrivateKey: string;
}

export function loadConfig(): AppConfig {
  const repoRoot = process.env.SCURO_REPO_ROOT ?? inferRepoRoot();
  const serviceRoot = process.env.SCURO_SERVICE_ROOT ?? path.resolve(import.meta.dir, "..");
  const stateDir = process.env.SCURO_STATE_DIR ?? path.join(repoRoot, ".scuro-testnet");
  const operatorPort = parseNumber(process.env.SCURO_OPERATOR_PORT, 8787);

  return {
    repoRoot,
    serviceRoot,
    stateDir,
    deployJobsDir: path.join(stateDir, "deploy-jobs"),
    snapshotsDir: path.join(stateDir, "snapshots"),
    manifestPath: path.join(stateDir, "manifest.json"),
    deployLogPath: path.join(stateDir, "deploy.log"),
    operatorHost: process.env.SCURO_OPERATOR_HOST ?? "127.0.0.1",
    operatorPort,
    rpcUrl: process.env.SCURO_RPC_URL ?? "http://127.0.0.1:8545",
    chainId: parseNumber(process.env.SCURO_CHAIN_ID, 31337),
    snapshotPrefix: process.env.SCURO_SNAPSHOT_PREFIX ?? "snapshots",
    hostingProvider: process.env.SCURO_HOSTING_PROVIDER ?? "local",
    hetznerServerId: process.env.SCURO_HETZNER_SERVER_ID,
    hetznerServerName: process.env.SCURO_HETZNER_SERVER_NAME,
    cloudflareRpcHostname: process.env.SCURO_CLOUDFLARE_RPC_HOSTNAME,
    publicRpcUrl: process.env.SCURO_PUBLIC_RPC_URL,
    adminPrivateKey: process.env.PRIVATE_KEY ?? DEFAULT_ADMIN_KEY,
    player1PrivateKey: process.env.PLAYER1_PRIVATE_KEY ?? DEFAULT_PLAYER1_KEY,
    player2PrivateKey: process.env.PLAYER2_PRIVATE_KEY ?? DEFAULT_PLAYER2_KEY
  };
}
