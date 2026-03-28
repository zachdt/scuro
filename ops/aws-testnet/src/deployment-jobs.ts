import path from "node:path";
import { randomUUID } from "node:crypto";
import { readdir } from "node:fs/promises";
import type { AppConfig } from "./config";
import { conflict } from "./errors";
import { readJsonFile, writeJsonFile } from "./fs";
import { loadManifest } from "./manifest";
import type {
  DeploymentJobRecord,
  DeploymentManifest,
  DeploymentOperation,
  JobStatus
} from "./types";
import type { deployProtocol, resetAndDeploy, seedApprovals } from "./protocol";

const ACTIVE_STATUSES: JobStatus[] = ["queued", "running"];

export interface DeploymentJobStoreLike {
  create(operation: DeploymentOperation): Promise<DeploymentJobRecord>;
  get(id: string): Promise<DeploymentJobRecord | null>;
  update(id: string, patch: Partial<DeploymentJobRecord>): Promise<DeploymentJobRecord>;
  list(): Promise<DeploymentJobRecord[]>;
  findActive(): Promise<DeploymentJobRecord | null>;
}

export interface DeploymentJobManager {
  start(operation: DeploymentOperation): Promise<DeploymentJobRecord>;
  get(id: string): Promise<DeploymentJobRecord | null>;
  recover(): Promise<void>;
}

export interface DeploymentJobDeps {
  deployProtocol: typeof deployProtocol;
  resetAndDeploy: typeof resetAndDeploy;
  seedApprovals: typeof seedApprovals;
  loadManifest: typeof loadManifest;
  logger: Pick<Console, "error">;
}

export class DeploymentJobStore implements DeploymentJobStoreLike {
  constructor(private readonly deployJobsDir: string) {}

  private filePath(id: string): string {
    return path.join(this.deployJobsDir, `${id}.json`);
  }

  async create(operation: DeploymentOperation): Promise<DeploymentJobRecord> {
    const now = new Date().toISOString();
    const id = randomUUID();
    const record: DeploymentJobRecord = {
      id,
      operation,
      status: "queued",
      createdAt: now,
      updatedAt: now,
      statusUrl: `/deploy-jobs/${id}`
    };
    await writeJsonFile(this.filePath(id), record);
    return record;
  }

  async get(id: string): Promise<DeploymentJobRecord | null> {
    return readJsonFile<DeploymentJobRecord>(this.filePath(id));
  }

  async update(
    id: string,
    patch: Partial<DeploymentJobRecord>
  ): Promise<DeploymentJobRecord> {
    const current = await this.get(id);
    if (!current) {
      throw new Error(`deployment job not found: ${id}`);
    }
    const next: DeploymentJobRecord = {
      ...current,
      ...patch,
      updatedAt: new Date().toISOString()
    };
    await writeJsonFile(this.filePath(id), next);
    return next;
  }

  async list(): Promise<DeploymentJobRecord[]> {
    const entries = await readdir(this.deployJobsDir, { withFileTypes: true });
    const jobs = await Promise.all(entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".json"))
      .map(async (entry) => readJsonFile<DeploymentJobRecord>(path.join(this.deployJobsDir, entry.name))));
    return jobs
      .filter((job): job is DeploymentJobRecord => job !== null)
      .sort((left, right) => left.createdAt.localeCompare(right.createdAt));
  }

  async findActive(): Promise<DeploymentJobRecord | null> {
    const jobs = await this.list();
    return jobs.find((job) => ACTIVE_STATUSES.includes(job.status)) ?? null;
  }
}

function deploymentFailureMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function manifestPatch(
  manifest: DeploymentManifest | null,
  config: AppConfig
): Partial<DeploymentJobRecord> {
  if (!manifest) {
    return {};
  }
  return {
    manifestPath: config.manifestPath,
    deploymentStatus: manifest.deploymentStatus,
    deploymentStages: manifest.deploymentStages,
    failedStage: manifest.failedStage,
    error: manifest.deploymentError
  };
}

class AsyncDeploymentJobManager implements DeploymentJobManager {
  constructor(
    private readonly config: AppConfig,
    private readonly store: DeploymentJobStoreLike,
    private readonly deps: DeploymentJobDeps
  ) {}

  async start(operation: DeploymentOperation): Promise<DeploymentJobRecord> {
    const active = await this.store.findActive();
    if (active) {
      throw conflict(`deployment job already ${active.status}: ${active.id}`);
    }

    const job = await this.store.create(operation);
    queueMicrotask(() => {
      void this.run(job.id, operation);
    });
    return job;
  }

  async get(id: string): Promise<DeploymentJobRecord | null> {
    return this.store.get(id);
  }

  async recover(): Promise<void> {
    const jobs = await this.store.list();
    const staleJobs = jobs.filter((job) => ACTIVE_STATUSES.includes(job.status));
    await Promise.all(staleJobs.map(async (job) => {
      await this.store.update(job.id, {
        status: "failed",
        completedAt: new Date().toISOString(),
        error: "operator restarted before deployment job completed"
      });
    }));
  }

  private async run(id: string, operation: DeploymentOperation): Promise<void> {
    await this.store.update(id, {
      status: "running",
      startedAt: new Date().toISOString(),
      error: undefined
    });

    try {
      const manifest = operation === "deploy"
        ? await this.runDeploy()
        : await this.deps.resetAndDeploy(this.config);
      await this.store.update(id, {
        status: "completed",
        completedAt: new Date().toISOString(),
        manifestPath: this.config.manifestPath,
        deploymentStatus: manifest.deploymentStatus ?? "completed",
        deploymentStages: manifest.deploymentStages,
        failedStage: manifest.failedStage
      });
    } catch (error) {
      const manifest = await this.deps.loadManifest(this.config.manifestPath);
      await this.store.update(id, {
        status: "failed",
        completedAt: new Date().toISOString(),
        error: manifest?.deploymentError ?? deploymentFailureMessage(error),
        ...manifestPatch(manifest, this.config)
      });
      this.deps.logger.error(error instanceof Error ? error : String(error));
    }
  }

  private async runDeploy(): Promise<DeploymentManifest> {
    const manifest = await this.deps.deployProtocol(this.config);
    await this.deps.seedApprovals(this.config, manifest);
    return manifest;
  }
}

export function createDeploymentJobManager(
  config: AppConfig,
  deps: DeploymentJobDeps
): DeploymentJobManager {
  return new AsyncDeploymentJobManager(
    config,
    new DeploymentJobStore(config.deployJobsDir),
    deps
  );
}
