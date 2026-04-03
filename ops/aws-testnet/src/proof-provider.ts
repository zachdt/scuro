import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import type { AppConfig } from "./config";
import type { CommandRunner } from "./exec";
import { runCommand } from "./exec";
import type { ProofJobRecord } from "./types";

export interface ResolvedFixture {
  fixtureName: string;
  payload: Record<string, unknown>;
}

export interface ResolvedGeneratedBlackjackPayload {
  phase: "initial-deal" | "peek" | "action" | "showdown";
  payloadPath: string;
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

  constructor(
    private readonly config: AppConfig,
    private readonly commandRunner: CommandRunner = runCommand
  ) {}

  async execute(job: ProofJobRecord): Promise<unknown> {
    const phase = blackjackPhase(job.jobType);
    if (phase) {
      const witnessPath = await this.resolveWitnessPath(job, phase);
      const result = await this.commandRunner(
        "bun",
        ["run", "--cwd", "zk", "prove:blackjack", "--phase", phase, "--witness", witnessPath],
        { cwd: this.config.repoRoot }
      );
      const payload = JSON.parse(result.stdout) as Record<string, unknown>;
      const payloadPath = path.join(this.config.jobsDir, `${job.id}-${phase}-payload.json`);
      await mkdir(path.dirname(payloadPath), { recursive: true });
      await writeFile(payloadPath, JSON.stringify(payload, null, 2));

      return {
        phase,
        payloadPath,
        payload
      } satisfies ResolvedGeneratedBlackjackPayload;
    }

    if (job.jobType !== "benchmark-live-proof") {
      throw new Error(`live mode is not enabled for gameplay jobs in v1: ${job.jobType}`);
    }

    const startedAt = Date.now();
    await this.commandRunner("bun", ["run", "--cwd", "zk", "prove"], {
      cwd: this.config.repoRoot
    });
    return {
      benchmark: true,
      durationMs: Date.now() - startedAt
    };
  }

  private async resolveWitnessPath(
    job: ProofJobRecord,
    phase: "initial-deal" | "peek" | "action" | "showdown"
  ): Promise<string> {
    const payload = job.payload ?? {};
    if (typeof payload.witnessPath === "string" && payload.witnessPath.length > 0) {
      return path.isAbsolute(payload.witnessPath)
        ? payload.witnessPath
        : path.resolve(this.config.repoRoot, payload.witnessPath);
    }

    if (typeof payload.witness === "object" && payload.witness) {
      const witnessPath = path.join(this.config.jobsDir, `${job.id}-${phase}-witness.json`);
      await mkdir(path.dirname(witnessPath), { recursive: true });
      await writeFile(witnessPath, JSON.stringify(payload.witness, null, 2));
      return witnessPath;
    }

    throw new Error(`live blackjack gameplay jobs require payload.witnessPath or payload.witness: ${job.jobType}`);
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
    case "blackjack-peek":
      return "blackjack_peek";
    case "blackjack-action":
      return "blackjack_action_resolve";
    case "blackjack-showdown":
      return "blackjack_showdown";
    default:
      return undefined;
  }
}

function blackjackPhase(jobType: string): "initial-deal" | "peek" | "action" | "showdown" | undefined {
  switch (jobType) {
    case "blackjack-initial-deal":
      return "initial-deal";
    case "blackjack-peek":
      return "peek";
    case "blackjack-action":
      return "action";
    case "blackjack-showdown":
      return "showdown";
    default:
      return undefined;
  }
}
