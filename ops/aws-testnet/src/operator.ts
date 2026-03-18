import { loadConfig } from "./config";
import { ensureStateDirs } from "./fs";
import { json, notFound, readJsonRequest } from "./http";
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
import { createQueueClient } from "./queue";
import type { ProofJobRequest } from "./types";

const config = loadConfig();
await ensureStateDirs([
  config.stateDir,
  config.jobsDir,
  config.queueDir,
  config.snapshotsDir
]);

const jobs = new JobStore(config.jobsDir);
const queue = createQueueClient(config);

function normalizeJob(body: Record<string, unknown>): ProofJobRequest {
  if (typeof body.jobType !== "string") {
    throw new Error("jobType is required");
  }
  if (body.mode !== "fixture" && body.mode !== "live") {
    throw new Error("mode must be fixture or live");
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

const server = Bun.serve({
  hostname: config.operatorHost,
  port: config.operatorPort,
  async fetch(request) {
    try {
      const url = new URL(request.url);

      if (request.method === "GET" && url.pathname === "/health") {
        return json({
          ok: true,
          service: "operator-api",
          queueMode: config.queueMode,
          chain: await checkChainHealth(config)
        });
      }

      if (request.method === "GET" && url.pathname === "/manifest") {
        const manifest = await loadManifest(config.manifestPath);
        return manifest ? json(manifest) : json({ error: "manifest_not_found" }, { status: 404 });
      }

      if (request.method === "GET" && url.pathname === "/actors") {
        const manifest = await loadManifest(config.manifestPath);
        if (!manifest) {
          return json({ error: "manifest_not_found" }, { status: 404 });
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
        const manifest = await deployProtocol(config);
        await seedApprovals(config, manifest);
        return json(manifest, { status: 201 });
      }

      if (request.method === "POST" && url.pathname === "/reset") {
        const manifest = await resetAndDeploy(config);
        return json(manifest, { status: 201 });
      }

      if (request.method === "POST" && url.pathname === "/seed") {
        await seedApprovals(config);
        return json({ ok: true });
      }

      if (request.method === "POST" && url.pathname === "/smoke/number-picker") {
        const record = await jobs.create({ jobType: "smoke-number-picker", mode: "fixture" });
        await queue.enqueue(record);
        return json({ jobId: record.id, statusUrl: jobResponsePath(record.id) }, { status: 202 });
      }

      if (request.method === "POST" && url.pathname === "/smoke/poker") {
        const record = await jobs.create({ jobType: "smoke-poker", mode: "fixture" });
        await queue.enqueue(record);
        return json({ jobId: record.id, statusUrl: jobResponsePath(record.id) }, { status: 202 });
      }

      if (request.method === "POST" && url.pathname === "/smoke/blackjack") {
        const record = await jobs.create({ jobType: "smoke-blackjack", mode: "fixture" });
        await queue.enqueue(record);
        return json({ jobId: record.id, statusUrl: jobResponsePath(record.id) }, { status: 202 });
      }

      if (request.method === "POST" && url.pathname === "/proof-jobs") {
        const body = await readJsonRequest(request);
        const record = await jobs.create(normalizeJob(body));
        await queue.enqueue(record);
        return json({ jobId: record.id, statusUrl: jobResponsePath(record.id) }, { status: 202 });
      }

      if (request.method === "GET" && url.pathname.startsWith("/proof-jobs/")) {
        const jobId = url.pathname.split("/").pop();
        if (!jobId) {
          return notFound();
        }
        const record = await jobs.get(jobId);
        return record ? json(record) : json({ error: "job_not_found" }, { status: 404 });
      }

      if (request.method === "POST" && url.pathname === "/snapshots/export") {
        const body = await readJsonRequest(request);
        const snapshot = await exportSnapshot(
          config,
          typeof body.name === "string" ? body.name : undefined
        );
        return json(snapshot, { status: 201 });
      }

      if (request.method === "POST" && url.pathname === "/snapshots/restore") {
        const body = await readJsonRequest(request);
        const restored = await restoreSnapshot(config, {
          name: typeof body.name === "string" ? body.name : undefined,
          s3Key: typeof body.s3Key === "string" ? body.s3Key : undefined
        });
        return json(restored);
      }

      if (request.method === "POST" && url.pathname === "/_local/smoke/number-picker") {
        return json(await runNumberPickerSmoke(config));
      }
      if (request.method === "POST" && url.pathname === "/_local/smoke/poker") {
        return json(await runPokerSmoke(config));
      }
      if (request.method === "POST" && url.pathname === "/_local/smoke/blackjack") {
        return json(await runBlackjackSmoke(config));
      }

      return notFound();
    } catch (error) {
      return json(
        {
          error: error instanceof Error ? error.message : String(error)
        },
        { status: 500 }
      );
    }
  }
});

console.log(`operator-api listening on http://${config.operatorHost}:${config.operatorPort}`);
