import { createWriteStream } from "node:fs";
import path from "node:path";

export interface CommandOptions {
  cwd?: string;
  env?: Record<string, string | undefined>;
  allowFailure?: boolean;
  streamOutputToPath?: string;
  streamOutputAppend?: boolean;
  maxBufferedOutputBytes?: number;
}

export interface CommandResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export type CommandRunner = (
  cmd: string,
  args: string[],
  options?: CommandOptions
) => Promise<CommandResult>;

export const runCommand: CommandRunner = async function runCommand(
  cmd: string,
  args: string[],
  options: CommandOptions = {}
): Promise<CommandResult> {
  const toolBinDir = process.env.SCURO_TOOL_BIN_DIR ?? path.dirname(process.execPath);
  const env = {
    ...process.env,
    PATH: [toolBinDir, process.env.PATH].filter(Boolean).join(":"),
    ...options.env
  };

  const proc = Bun.spawn([cmd, ...args], {
    cwd: options.cwd,
    env,
    stdout: "pipe",
    stderr: "pipe"
  });

  const maxBufferedOutputBytes = options.maxBufferedOutputBytes ?? 64 * 1024;
  const outputStream = options.streamOutputToPath
    ? createWriteStream(options.streamOutputToPath, { flags: options.streamOutputAppend ? "a" : "w" })
    : null;

  async function consumeStream(
    stream: ReadableStream<Uint8Array>,
    sink: ReturnType<typeof createWriteStream> | null
  ): Promise<string> {
    const reader = stream.getReader();
    const decoder = new TextDecoder();
    let buffered = "";

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) {
          break;
        }
        if (!value) {
          continue;
        }

        if (sink) {
          sink.write(value);
        }

        buffered += decoder.decode(value, { stream: true });
        if (buffered.length > maxBufferedOutputBytes) {
          buffered = buffered.slice(-maxBufferedOutputBytes);
        }
      }

      buffered += decoder.decode();
      if (buffered.length > maxBufferedOutputBytes) {
        buffered = buffered.slice(-maxBufferedOutputBytes);
      }
      return buffered;
    } finally {
      reader.releaseLock();
    }
  }

  const [stdout, stderr, exitCode] = await Promise.all([
    consumeStream(proc.stdout, outputStream),
    consumeStream(proc.stderr, outputStream),
    proc.exited
  ]);

  if (outputStream) {
    await new Promise<void>((resolve, reject) => {
      outputStream.end((error?: Error | null) => {
        if (error) {
          reject(error);
          return;
        }
        resolve();
      });
    });
  }

  if (exitCode !== 0 && !options.allowFailure) {
    throw new Error(`command failed: ${cmd} ${args.join(" ")}\n${stderr || stdout}`);
  }

  return { stdout, stderr, exitCode };
};
