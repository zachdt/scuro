import path from "node:path";

export async function ensureDir(dir: string): Promise<void> {
  await Bun.$`mkdir -p ${dir}`.quiet();
}

export async function ensureStateDirs(paths: string[]): Promise<void> {
  await Promise.all(paths.map(async (dir) => {
    await Bun.$`mkdir -p ${dir}`.quiet();
  }));
}

export async function readJsonFile<T>(filePath: string): Promise<T | null> {
  const file = Bun.file(filePath);
  if (!(await file.exists())) {
    return null;
  }
  return (await file.json()) as T;
}

export async function writeJsonFile(filePath: string, value: unknown): Promise<void> {
  await Bun.write(filePath, JSON.stringify(value, null, 2) + "\n");
}
