import type { AppConfig } from "./config";
import { loadConfig } from "./config";
import { HttpError, badRequest, notFound } from "./errors";
import { ensureStateDirs } from "./fs";
import { json, notFound as notFoundResponse, readJsonRequest } from "./http";
import { JobStore } from "./jobs";
import { loadManifest } from "./manifest";
import {
  checkChainHealth,
  deployProtocol,
  exportSnapshot,
  resetAndDeploy,
  restoreSnapshot,
  runBlackjackSmoke,
  runNumberPickerSmoke,
  runPokerSmoke,
  seedApprovals
} from "./protocol";
import { createQueueClient, type QueueClient } from "./queue";
import type { ProofJobRecord, ProofJobRequest } from "./types";

export interface JobStoreLike {
  create(request: ProofJobRequest): Promise<ProofJobRecord>;
  get(id: string): Promise<ProofJobRecord | null>;
}

export interface OperatorDeps {
  jobs: JobStoreLike;
  queue: QueueClient;
  checkChainHealth: typeof checkChainHealth;
  loadManifest: typeof loadManifest;
  deployProtocol: typeof deployProtocol;
  seedApprovals: typeof seedApprovals;
  resetAndDeploy: typeof resetAndDeploy;
  exportSnapshot: typeof exportSnapshot;
  restoreSnapshot: typeof restoreSnapshot;
  runNumberPickerSmoke: typeof runNumberPickerSmoke;
  runPokerSmoke: typeof runPokerSmoke;
  runBlackjackSmoke: typeof runBlackjackSmoke;
}

export interface ServerLike {
  stop(closeActiveConnections?: boolean): void;
}

export type ServeFunction = (options: {
  hostname: string;
  port: number;
  fetch: (request: Request) => Promise<Response> | Response;
}) => ServerLike;

export function normalizeJob(body: Record<string, unknown>): ProofJobRequest {
  if (typeof body.jobType !== "string") {
    throw badRequest("jobType is required");
  }
  if (body.mode !== "fixture" && body.mode !== "live") {
    throw badRequest("mode must be fixture or live");
  }
  return {
    jobType: body.jobType,
    mode: body.mode,
    chainRef: typeof body.chainRef === "string" ? body.chainRef : undefined,
    gameRef: typeof body.gameRef === "string" ? body.gameRef : undefined,
    fixtureName: typeof body.fixtureName === "string" ? body.fixtureName : undefined,
    payload: typeof body.payload === "object" && body.payload ? body.payload as Record<string, unknown> : undefined,
    requestedBy: typeof body.requestedBy === "string" ? body.requestedBy : undefined
  };
}

function jobResponsePath(jobId: string): string {
  return `/proof-jobs/${jobId}`;
}

export function createDefaultOperatorDeps(config: AppConfig): OperatorDeps {
  return {
    jobs: new JobStore(config.jobsDir),
    queue: createQueueClient(config),
    checkChainHealth,
    loadManifest,
    deployProtocol,
    seedApprovals,
    resetAndDeploy,
    exportSnapshot,
    restoreSnapshot,
    runNumberPickerSmoke,
    runPokerSmoke,
    runBlackjackSmoke
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
  return json(
    {
      error: error instanceof Error ? error.message : String(error)
    },
    { status: 500 }
  );
}

export function createOperatorFetchHandler(
  config: AppConfig,
  deps: OperatorDeps
): (request: Request) => Promise<Response> {
  return async function handleOperatorRequest(request: Request): Promise<Response> {
    try {
      const url = new URL(request.url);

      if (request.method === "GET" && url.pathname === "/health") {
        return json({
          ok: true,
          service: "operator-api",
          queueMode: config.queueMode,
          chain: await deps.checkChainHealth(config)
        });
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
        const manifest = await deps.deployProtocol(config);
        await deps.seedApprovals(config, manifest);
        return json(manifest, { status: 201 });
      }

      if (request.method === "POST" && url.pathname === "/reset") {
        const manifest = await deps.resetAndDeploy(config);
        return json(manifest, { status: 201 });
      }

      if (request.method === "POST" && url.pathname === "/seed") {
        await deps.seedApprovals(config);
        return json({ ok: true });
      }

      if (request.method === "POST" && url.pathname === "/smoke/number-picker") {
        const record = await deps.jobs.create({ jobType: "smoke-number-picker", mode: "fixture" });
        await deps.queue.enqueue(record);
        return json({ jobId: record.id, statusUrl: jobResponsePath(record.id) }, { status: 202 });
      }

      if (request.method === "POST" && url.pathname === "/smoke/poker") {
        const record = await deps.jobs.create({ jobType: "smoke-poker", mode: "fixture" });
        await deps.queue.enqueue(record);
        return json({ jobId: record.id, statusUrl: jobResponsePath(record.id) }, { status: 202 });
      }

      if (request.method === "POST" && url.pathname === "/smoke/blackjack") {
        const record = await deps.jobs.create({ jobType: "smoke-blackjack", mode: "fixture" });
        await deps.queue.enqueue(record);
        return json({ jobId: record.id, statusUrl: jobResponsePath(record.id) }, { status: 202 });
      }

      if (request.method === "POST" && url.pathname === "/proof-jobs") {
        const body = await readJsonRequest(request);
        const record = await deps.jobs.create(normalizeJob(body));
        await deps.queue.enqueue(record);
        return json({ jobId: record.id, statusUrl: jobResponsePath(record.id) }, { status: 202 });
      }

      if (request.method === "GET" && url.pathname.startsWith("/proof-jobs/")) {
        const jobId = url.pathname.split("/").pop();
        if (!jobId) {
          throw notFound("job not found");
        }
        const record = await deps.jobs.get(jobId);
        return record ? json(record) : json({ error: "job not found" }, { status: 404 });
      }

      if (request.method === "POST" && url.pathname === "/snapshots/export") {
        const body = await readJsonRequest(request);
        const snapshot = await deps.exportSnapshot(
          config,
          typeof body.name === "string" ? body.name : undefined
        );
        return json(snapshot, { status: 201 });
      }

      if (request.method === "POST" && url.pathname === "/snapshots/restore") {
        const body = await readJsonRequest(request);
        const restored = await deps.restoreSnapshot(config, {
          name: typeof body.name === "string" ? body.name : undefined,
          s3Key: typeof body.s3Key === "string" ? body.s3Key : undefined
        });
        return json(restored);
      }

      if (request.method === "POST" && url.pathname === "/_local/smoke/number-picker") {
        return json(await deps.runNumberPickerSmoke(config));
      }

      if (request.method === "POST" && url.pathname === "/_local/smoke/poker") {
        return json(await deps.runPokerSmoke(config));
      }

      if (request.method === "POST" && url.pathname === "/_local/smoke/blackjack") {
        return json(await deps.runBlackjackSmoke(config));
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
  await ensureStateDirs([
    config.stateDir,
    config.jobsDir,
    config.queueDir,
    config.snapshotsDir
  ]);

  const fetch = createOperatorFetchHandler(config, deps);
  const server = serve({
    hostname: config.operatorHost,
    port: config.operatorPort,
    fetch
  });

  console.log(`operator-api listening on http://${config.operatorHost}:${config.operatorPort}`);
  return server;
}

if (import.meta.main) {
  await startOperatorServer();
}
