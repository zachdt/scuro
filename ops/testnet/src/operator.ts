import type { AppConfig } from "./config";
import { loadConfig } from "./config";
import { createDeploymentJobManager } from "./deployment-jobs";
import { HttpError, notFound } from "./errors";
import { ensureStateDirs } from "./fs";
import { json, notFound as notFoundResponse, readJsonRequest } from "./http";
import { loadManifest } from "./manifest";
import {
  checkChainHealth,
  deployProtocol,
  exportSnapshot,
  resetAndDeploy,
  restoreSnapshot,
  runNumberPickerSmoke,
  runSlotSmoke,
  seedApprovals
} from "./protocol";
import type { DeploymentJobRecord } from "./types";

export interface DeploymentJobsLike {
  start(operation: "deploy" | "reset"): Promise<DeploymentJobRecord>;
  get(id: string): Promise<DeploymentJobRecord | null>;
  recover(): Promise<void>;
}

export interface OperatorDeps {
  deploymentJobs: DeploymentJobsLike;
  checkChainHealth: typeof checkChainHealth;
  loadManifest: typeof loadManifest;
  seedApprovals: typeof seedApprovals;
  exportSnapshot: typeof exportSnapshot;
  restoreSnapshot: typeof restoreSnapshot;
  runNumberPickerSmoke: typeof runNumberPickerSmoke;
  runSlotSmoke: typeof runSlotSmoke;
}

export interface ServerLike {
  stop(closeActiveConnections?: boolean): void;
}

export type ServeFunction = (options: {
  hostname: string;
  port: number;
  idleTimeout?: number;
  fetch: (request: Request) => Promise<Response> | Response;
}) => ServerLike;

export function createDefaultOperatorDeps(config: AppConfig): OperatorDeps {
  return {
    deploymentJobs: createDeploymentJobManager(config, {
      deployProtocol,
      resetAndDeploy,
      seedApprovals,
      loadManifest,
      logger: console
    }),
    checkChainHealth,
    loadManifest,
    seedApprovals,
    exportSnapshot,
    restoreSnapshot,
    runNumberPickerSmoke,
    runSlotSmoke
  };
}

function mapError(error: unknown): Response {
  if (error instanceof HttpError) {
    return json({ error: error.message }, { status: error.status });
  }
  if (error instanceof Error && /manifest not found/i.test(error.message)) {
    return json({ error: error.message }, { status: 404 });
  }
  if (error instanceof Error && /ENOENT|no such file/i.test(error.message)) {
    return json({ error: error.message }, { status: 404 });
  }
  return json({ error: error instanceof Error ? error.message : String(error) }, { status: 500 });
}

export function createOperatorFetchHandler(
  config: AppConfig,
  deps: OperatorDeps
): (request: Request) => Promise<Response> {
  return async function handleOperatorRequest(request: Request): Promise<Response> {
    try {
      const url = new URL(request.url);

      if (request.method === "GET" && url.pathname === "/health") {
        let chain: Record<string, unknown>;
        try {
          chain = { ok: true, ...(await deps.checkChainHealth(config)) };
        } catch (error) {
          chain = { ok: false, error: error instanceof Error ? error.message : String(error) };
        }
        return json({ ok: true, service: "operator-api", chain });
      }

      if (request.method === "GET" && url.pathname === "/manifest") {
        const manifest = await deps.loadManifest(config.manifestPath);
        return manifest ? json(manifest) : json({ error: "manifest not found" }, { status: 404 });
      }

      if (request.method === "GET" && url.pathname === "/actors") {
        const manifest = await deps.loadManifest(config.manifestPath);
        if (!manifest) {
          return json({ error: "manifest not found" }, { status: 404 });
        }
        return json({
          actors: manifest.actors,
          privateKeys: {
            Admin: "PRIVATE_KEY",
            Player1: "PLAYER1_PRIVATE_KEY",
            Player2: "PLAYER2_PRIVATE_KEY"
          }
        });
      }

      if (request.method === "POST" && url.pathname === "/deploy") {
        const record = await deps.deploymentJobs.start("deploy");
        return json({ jobId: record.id, status: record.status, statusUrl: record.statusUrl }, { status: 202 });
      }

      if (request.method === "POST" && url.pathname === "/reset") {
        const record = await deps.deploymentJobs.start("reset");
        return json({ jobId: record.id, status: record.status, statusUrl: record.statusUrl }, { status: 202 });
      }

      if (request.method === "POST" && url.pathname === "/seed") {
        await deps.seedApprovals(config);
        return json({ ok: true });
      }

      if (request.method === "POST" && url.pathname === "/smoke/number-picker") {
        return json(await deps.runNumberPickerSmoke(config));
      }

      if (request.method === "POST" && url.pathname === "/smoke/slot") {
        return json(await deps.runSlotSmoke(config));
      }

      if (request.method === "GET" && url.pathname.startsWith("/deploy-jobs/")) {
        const jobId = url.pathname.split("/").pop();
        if (!jobId) {
          throw notFound("deployment job not found");
        }
        const record = await deps.deploymentJobs.get(jobId);
        return record ? json(record) : json({ error: "deployment job not found" }, { status: 404 });
      }

      if (request.method === "POST" && url.pathname === "/snapshots/export") {
        const body = await readJsonRequest(request);
        const snapshot = await deps.exportSnapshot(config, typeof body.name === "string" ? body.name : undefined);
        return json(snapshot, { status: 201 });
      }

      if (request.method === "POST" && url.pathname === "/snapshots/restore") {
        const body = await readJsonRequest(request);
        const restored = await deps.restoreSnapshot(config, {
          name: typeof body.name === "string" ? body.name : undefined
        });
        return json(restored);
      }

      if (request.method === "POST" && url.pathname === "/_local/smoke/number-picker") {
        return json(await deps.runNumberPickerSmoke(config));
      }

      if (request.method === "POST" && url.pathname === "/_local/smoke/slot") {
        return json(await deps.runSlotSmoke(config));
      }

      return notFoundResponse();
    } catch (error) {
      return mapError(error);
    }
  };
}

export async function startOperatorServer(
  config: AppConfig = loadConfig(),
  deps: OperatorDeps = createDefaultOperatorDeps(config),
  serve: ServeFunction = Bun.serve
): Promise<ServerLike> {
  await ensureStateDirs([config.stateDir, config.deployJobsDir, config.snapshotsDir]);
  await deps.deploymentJobs.recover();

  const fetch = createOperatorFetchHandler(config, deps);
  const server = serve({
    hostname: config.operatorHost,
    port: config.operatorPort,
    idleTimeout: 30,
    fetch
  });

  console.log(`operator-api listening on http://${config.operatorHost}:${config.operatorPort}`);
  return server;
}

if (import.meta.main) {
  await startOperatorServer();
}
