export type JobMode = "fixture" | "live";

export type JobStatus = "queued" | "running" | "completed" | "failed";

export type DeploymentOperation = "deploy" | "reset";

export type DeploymentState = "completed" | "failed";

export interface DeploymentStageRecord {
  name: string;
  status: "completed" | "failed";
}

export interface ProofJobRequest {
  jobType: string;
  mode: JobMode;
  chainRef?: string;
  gameRef?: string;
  fixtureName?: string;
  payload?: Record<string, unknown>;
  requestedBy?: string;
}

export interface ProofJobRecord extends ProofJobRequest {
  id: string;
  status: JobStatus;
  createdAt: string;
  updatedAt: string;
  result?: unknown;
  error?: string;
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
  aws: {
    region?: string;
    stackName?: string;
    ssmTargetInstanceId?: string;
    operatorPort: number;
    queueMode: "file" | "sqs";
    queueUrl?: string;
    proofQueueName?: string;
    snapshotBucket?: string;
    snapshotPrefix?: string;
  };
  contracts: Record<string, string>;
  actors: Record<string, string>;
  deploymentStatus?: DeploymentState;
  deploymentStages?: DeploymentStageRecord[];
  failedStage?: string;
  deploymentError?: string;
}
