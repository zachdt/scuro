import path from "node:path";
import type { AppConfig } from "./config";
import { runCommand } from "./exec";
import type { ProofJobRecord } from "./types";

export interface ResolvedFixture {
  fixtureName: string;
  payload: Record<string, unknown>;
}

export interface ProofProvider {
  readonly mode: "fixture" | "live";
  execute(job: ProofJobRecord): Promise<unknown>;
}

export class FixtureProofProvider implements ProofProvider {
  readonly mode = "fixture" as const;

  constructor(private readonly config: AppConfig) {}

  async execute(job: ProofJobRecord): Promise<ResolvedFixture> {
    const fixtureName = job.fixtureName ?? defaultFixtureName(job.jobType);
    if (!fixtureName) {
      throw new Error(`fixture name required for job type ${job.jobType}`);
    }
    const filePath = path.join(this.config.repoRoot, "zk", "fixtures", "generated", `${fixtureName}.json`);
    const payload = await Bun.file(filePath).json();
    return {
      fixtureName,
      payload: payload as Record<string, unknown>
    };
  }
}

export class LiveProofProvider implements ProofProvider {
  readonly mode = "live" as const;

  constructor(private readonly config: AppConfig) {}

  async execute(job: ProofJobRecord): Promise<unknown> {
    if (job.jobType !== "benchmark-live-proof") {
      throw new Error(`live mode is not enabled for gameplay jobs in v1: ${job.jobType}`);
    }

    const startedAt = Date.now();
    await runCommand("bun", ["run", "--cwd", "zk", "prove"], {
      cwd: this.config.repoRoot
    });
    return {
      benchmark: true,
      durationMs: Date.now() - startedAt
    };
  }
}

function defaultFixtureName(jobType: string): string | undefined {
  switch (jobType) {
    case "poker-initial-deal":
      return "poker_initial_deal";
    case "poker-showdown":
      return "poker_showdown";
    case "blackjack-initial-deal":
      return "blackjack_initial_deal";
    case "blackjack-action":
      return "blackjack_action_resolve";
    case "blackjack-showdown":
      return "blackjack_showdown";
    default:
      return undefined;
  }
}
