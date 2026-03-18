import type { AppConfig } from "./config";
import { loadManifest } from "./manifest";
import type { ProofProvider } from "./proof-provider";
import {
  runBlackjackSmoke,
  runNumberPickerSmoke,
  runPokerSmoke
} from "./protocol";
import { runCommand } from "./exec";
import type { ProofJobRecord } from "./types";

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
  job: ProofJobRecord
): Promise<Record<string, string>> {
  const manifest = await loadManifest(config.manifestPath);
  if (!manifest) {
    throw new Error("manifest not found");
  }

  const env = {
    PRIVATE_KEY: config.adminPrivateKey,
    PLAYER1_PRIVATE_KEY: config.player1PrivateKey,
    PLAYER2_PRIVATE_KEY: config.player2PrivateKey,
    TOURNAMENT_POKER_ENGINE: manifest.contracts.TournamentPokerEngine,
    BLACKJACK_ENGINE: manifest.contracts.SingleDeckBlackjackEngine,
    ...envForProofJob(config, job)
  };

  await runCommand(
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
  providers: Record<"fixture" | "live", ProofProvider>
): Promise<unknown> {
  if (job.jobType === "smoke-number-picker") {
    return runNumberPickerSmoke(config);
  }
  if (job.jobType === "smoke-poker") {
    return runPokerSmoke(config);
  }
  if (job.jobType === "smoke-blackjack") {
    return runBlackjackSmoke(config);
  }

  const provider = providers[job.mode];
  const resolved = await provider.execute(job);

  switch (job.jobType) {
    case "poker-initial-deal":
      return {
        resolved,
        ...(await runFixtureScript(
          config,
          "script/aws/SubmitPokerInitialDeal.s.sol:SubmitPokerInitialDeal",
          job
        ))
      };
    case "poker-draw":
      return {
        resolved,
        ...(await runFixtureScript(config, "script/aws/SubmitPokerDraw.s.sol:SubmitPokerDraw", job))
      };
    case "poker-showdown":
      return {
        resolved,
        ...(await runFixtureScript(
          config,
          "script/aws/SubmitPokerShowdown.s.sol:SubmitPokerShowdown",
          job
        ))
      };
    case "blackjack-initial-deal":
      return {
        resolved,
        ...(await runFixtureScript(
          config,
          "script/aws/SubmitBlackjackInitialDeal.s.sol:SubmitBlackjackInitialDeal",
          job
        ))
      };
    case "blackjack-action":
      return {
        resolved,
        ...(await runFixtureScript(
          config,
          "script/aws/SubmitBlackjackAction.s.sol:SubmitBlackjackAction",
          job
        ))
      };
    case "blackjack-showdown":
      return {
        resolved,
        ...(await runFixtureScript(
          config,
          "script/aws/SubmitBlackjackShowdown.s.sol:SubmitBlackjackShowdown",
          job
        ))
      };
    case "benchmark-live-proof":
      return resolved;
    default:
      throw new Error(`unsupported job type: ${job.jobType}`);
  }
}
