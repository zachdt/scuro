import path from "node:path";

export interface CommandOptions {
  cwd?: string;
  env?: Record<string, string | undefined>;
  allowFailure?: boolean;
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

  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited
  ]);

  if (exitCode !== 0 && !options.allowFailure) {
    throw new Error(`command failed: ${cmd} ${args.join(" ")}\n${stderr || stdout}`);
  }

  return { stdout, stderr, exitCode };
};
