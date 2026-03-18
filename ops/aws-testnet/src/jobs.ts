import path from "node:path";
import { randomUUID } from "node:crypto";
import type { ProofJobRecord, ProofJobRequest } from "./types";
import { readJsonFile, writeJsonFile } from "./fs";

export class JobStore {
  constructor(private readonly jobsDir: string) {}

  private filePath(id: string): string {
    return path.join(this.jobsDir, `${id}.json`);
  }

  async create(request: ProofJobRequest): Promise<ProofJobRecord> {
    const now = new Date().toISOString();
    const record: ProofJobRecord = {
      ...request,
      id: randomUUID(),
      status: "queued",
      createdAt: now,
      updatedAt: now
    };
    await writeJsonFile(this.filePath(record.id), record);
    return record;
  }

  async get(id: string): Promise<ProofJobRecord | null> {
    return readJsonFile<ProofJobRecord>(this.filePath(id));
  }

  async update(
    id: string,
    patch: Partial<ProofJobRecord>
  ): Promise<ProofJobRecord> {
    const current = await this.get(id);
    if (!current) {
      throw new Error(`job not found: ${id}`);
    }
    const next: ProofJobRecord = {
      ...current,
      ...patch,
      updatedAt: new Date().toISOString()
    };
    await writeJsonFile(this.filePath(id), next);
    return next;
  }
}
