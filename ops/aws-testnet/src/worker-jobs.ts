import type { AppConfig } from "./config";
import { loadManifest } from "./manifest";
import type { ProofProvider } from "./proof-provider";
import {
  runBlackjackSmoke,
  runNumberPickerSmoke,
  runPokerSmoke
} from "./protocol";
import type { CommandRunner } from "./exec";
import { runCommand } from "./exec";
import type { ProofJobRecord } from "./types";

export interface WorkerJobDeps {
  commandRunner: CommandRunner;
  loadManifest: typeof loadManifest;
  runNumberPickerSmoke: typeof runNumberPickerSmoke;
  runPokerSmoke: typeof runPokerSmoke;
  runBlackjackSmoke: typeof runBlackjackSmoke;
}

function withWorkerJobDeps(overrides: Partial<WorkerJobDeps> = {}): WorkerJobDeps {
  return {
    commandRunner: runCommand,
    loadManifest,
    runNumberPickerSmoke,
    runPokerSmoke,
    runBlackjackSmoke,
    ...overrides
  };
}

function envForProofJob(config: AppConfig, job: ProofJobRecord): Record<string, string> {
  const payload = job.payload ?? {};
  const get = (key: string): string => {
    const value = payload[key];
    if (typeof value !== "string" && typeof value !== "number") {
      throw new Error(`payload.${key} is required`);
    }
    return String(value);
  };

  const base: Record<string, string> = {
    PRIVATE_KEY: config.adminPrivateKey,
    PLAYER1_PRIVATE_KEY: config.player1PrivateKey,
    PLAYER2_PRIVATE_KEY: config.player2PrivateKey
  };

  switch (job.jobType) {
    case "poker-initial-deal":
      return { ...base, GAME_ID: get("gameId") };
    case "poker-draw":
      return {
        ...base,
        GAME_ID: get("gameId"),
        PLAYER_ADDRESS: get("playerAddress"),
        DRAW_FIXTURE_NAME: job.fixtureName ?? get("fixtureName")
      };
    case "poker-showdown":
      return { ...base, GAME_ID: get("gameId"), WINNER_ADDRESS: get("winnerAddress") };
    case "blackjack-initial-deal":
    case "blackjack-action":
    case "blackjack-showdown":
      return { ...base, SESSION_ID: get("sessionId") };
    default:
      return base;
  }
}

async function runFixtureScript(
  config: AppConfig,
  target: string,
  job: ProofJobRecord,
  deps: WorkerJobDeps,
  extraEnv: Record<string, string> = {}
): Promise<Record<string, string>> {
  const manifest = await deps.loadManifest(config.manifestPath);
  if (!manifest) {
    throw new Error("manifest not found");
  }

  const env = {
    PRIVATE_KEY: config.adminPrivateKey,
    PLAYER1_PRIVATE_KEY: config.player1PrivateKey,
    PLAYER2_PRIVATE_KEY: config.player2PrivateKey,
    TOURNAMENT_POKER_ENGINE: manifest.contracts.TournamentPokerEngine,
    BLACKJACK_ENGINE: manifest.contracts.SingleDeckBlackjackEngine,
    ...envForProofJob(config, job),
    ...extraEnv
  };

  await deps.commandRunner(
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
      env
    }
  );

  return { script: target, status: "ok" };
}

export async function processJob(
  config: AppConfig,
  job: ProofJobRecord,
  providers: Record<"fixture" | "live", ProofProvider>,
  depsOverrides: Partial<WorkerJobDeps> = {}
): Promise<unknown> {
  const deps = withWorkerJobDeps(depsOverrides);
  if (job.jobType === "smoke-number-picker") {
    return deps.runNumberPickerSmoke(config);
  }
  if (job.jobType === "smoke-poker") {
    return deps.runPokerSmoke(config);
  }
  if (job.jobType === "smoke-blackjack") {
    return deps.runBlackjackSmoke(config);
  }

  const provider = providers[job.mode];
  const resolved = await provider.execute(job);
  const proofPayloadEnv = extractProofPayloadEnv(resolved);

  switch (job.jobType) {
    case "poker-initial-deal":
      return {
        resolved,
        ...(await runFixtureScript(
          config,
          "script/aws/SubmitPokerInitialDeal.s.sol:SubmitPokerInitialDeal",
          job,
          deps
        ))
      };
    case "poker-draw":
      return {
        resolved,
        ...(await runFixtureScript(config, "script/aws/SubmitPokerDraw.s.sol:SubmitPokerDraw", job, deps))
      };
    case "poker-showdown":
      return {
        resolved,
        ...(await runFixtureScript(
          config,
          "script/aws/SubmitPokerShowdown.s.sol:SubmitPokerShowdown",
          job,
          deps
        ))
      };
    case "blackjack-initial-deal":
      return {
        resolved,
        ...(await runFixtureScript(
          config,
          "script/aws/SubmitBlackjackInitialDeal.s.sol:SubmitBlackjackInitialDeal",
          job,
          deps,
          proofPayloadEnv
        ))
      };
    case "blackjack-action":
      return {
        resolved,
        ...(await runFixtureScript(
          config,
          "script/aws/SubmitBlackjackAction.s.sol:SubmitBlackjackAction",
          job,
          deps,
          proofPayloadEnv
        ))
      };
    case "blackjack-showdown":
      return {
        resolved,
        ...(await runFixtureScript(
          config,
          "script/aws/SubmitBlackjackShowdown.s.sol:SubmitBlackjackShowdown",
          job,
          deps,
          proofPayloadEnv
        ))
      };
    case "benchmark-live-proof":
      return resolved;
    default:
      throw new Error(`unsupported job type: ${job.jobType}`);
  }
}

function extractProofPayloadEnv(resolved: unknown): Record<string, string> {
  if (
    typeof resolved === "object" &&
    resolved !== null &&
    "payloadPath" in resolved &&
    typeof (resolved as { payloadPath?: unknown }).payloadPath === "string"
  ) {
    return {
      PROOF_PAYLOAD_PATH: (resolved as { payloadPath: string }).payloadPath
    };
  }

  return {};
}
