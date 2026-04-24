export type JobStatus = "queued" | "running" | "completed" | "failed";

export type DeploymentOperation = "deploy" | "reset";

export type DeploymentState = "completed" | "failed";

export interface DeploymentStageRecord {
  name: string;
  status: "completed" | "failed";
}

export interface DeploymentJobRecord {
  id: string;
  operation: DeploymentOperation;
  status: JobStatus;
  createdAt: string;
  updatedAt: string;
  startedAt?: string;
  completedAt?: string;
  statusUrl: string;
  manifestPath?: string;
  deploymentStatus?: DeploymentState;
  deploymentStages?: DeploymentStageRecord[];
  failedStage?: string;
  error?: string;
}

export interface DeploymentManifest {
  chain: {
    rpcUrl: string;
    chainId: number;
    deployedAt: string;
  };
  hosting: {
    provider: string;
    hetznerServerId?: string;
    hetznerServerName?: string;
    cloudflareRpcHostname?: string;
    publicRpcUrl?: string;
    operatorPort: number;
    snapshotPrefix?: string;
  };
  contracts: Record<string, string>;
  actors: Record<string, string>;
  deploymentStatus?: DeploymentState;
  deploymentStages?: DeploymentStageRecord[];
  failedStage?: string;
  deploymentError?: string;
}
