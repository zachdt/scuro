import path from "node:path";
import type { AppConfig } from "./config";
import { runCommand } from "./exec";
import type { ProofJobRecord } from "./types";

export interface QueueMessage {
  jobId: string;
  receiptHandle?: string;
}

export interface QueueClient {
  enqueue(job: ProofJobRecord): Promise<void>;
  receive(): Promise<QueueMessage | null>;
  ack(message: QueueMessage): Promise<void>;
}

class FileQueueClient implements QueueClient {
  constructor(private readonly queueDir: string) {}

  async enqueue(job: ProofJobRecord): Promise<void> {
    const filename = `${Date.now()}-${job.id}.json`;
    await Bun.write(path.join(this.queueDir, filename), JSON.stringify({ jobId: job.id }, null, 2));
  }

  async receive(): Promise<QueueMessage | null> {
    const queue = new Bun.Glob("*.json");
    const files = [];
    for await (const file of queue.scan(this.queueDir)) {
      files.push(file);
    }
    files.sort();
    const first = files[0];
    if (!first) {
      return null;
    }
    const fullPath = path.join(this.queueDir, first);
    const payload = JSON.parse(await Bun.file(fullPath).text()) as QueueMessage;
    await Bun.$`rm -f ${fullPath}`.quiet();
    return payload;
  }

  async ack(_message: QueueMessage): Promise<void> {
    return;
  }
}

class AwsSqsQueueClient implements QueueClient {
  constructor(private readonly queueUrl: string, private readonly region?: string) {}

  async enqueue(job: ProofJobRecord): Promise<void> {
    await runCommand("aws", [
      "sqs",
      "send-message",
      "--queue-url",
      this.queueUrl,
      "--message-body",
      JSON.stringify({ jobId: job.id }),
      ...(this.region ? ["--region", this.region] : [])
    ]);
  }

  async receive(): Promise<QueueMessage | null> {
    const result = await runCommand("aws", [
      "sqs",
      "receive-message",
      "--queue-url",
      this.queueUrl,
      "--max-number-of-messages",
      "1",
      "--wait-time-seconds",
      "20",
      ...(this.region ? ["--region", this.region] : [])
    ]);
    if (!result.stdout.trim()) {
      return null;
    }

    const parsed = JSON.parse(result.stdout) as {
      Messages?: Array<{ Body: string; ReceiptHandle: string }>;
    };
    const message = parsed.Messages?.[0];
    if (!message) {
      return null;
    }
    const body = JSON.parse(message.Body) as QueueMessage;
    return {
      ...body,
      receiptHandle: message.ReceiptHandle
    };
  }

  async ack(message: QueueMessage): Promise<void> {
    if (!message.receiptHandle) {
      return;
    }
    await runCommand("aws", [
      "sqs",
      "delete-message",
      "--queue-url",
      this.queueUrl,
      "--receipt-handle",
      message.receiptHandle,
      ...(this.region ? ["--region", this.region] : [])
    ]);
  }
}

export function createQueueClient(config: AppConfig): QueueClient {
  if (config.queueMode === "sqs" && config.sqsQueueUrl) {
    return new AwsSqsQueueClient(config.sqsQueueUrl, config.awsRegion);
  }
  return new FileQueueClient(config.queueDir);
}
