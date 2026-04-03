import { access, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { generateBlackjackPayload } from "./lib/blackjack-proof.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const { phase, witnessPath } = parseArgs(process.argv.slice(2));
const witness = JSON.parse(await readWitness(witnessPath));
const payload = await generateBlackjackPayload({
  root: ROOT,
  phase,
  witness,
  name: `cli-${phase}`
});

process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);

function parseArgs(argv) {
  let phase = "";
  let witnessPath = "";

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = argv[index + 1];

    switch (arg) {
      case "--phase":
        phase = next ?? "";
        index += 1;
        break;
      case "--witness":
        witnessPath = next ?? "";
        index += 1;
        break;
      default:
        throw new Error(`unknown argument: ${arg}`);
    }
  }

  if (!phase) {
    throw new Error("missing required --phase initial-deal|peek|action|showdown");
  }

  return { phase, witnessPath };
}

async function readWitness(witnessPath) {
  if (!witnessPath || witnessPath === "-") {
    return await readStdin();
  }

  const candidates = [
    path.resolve(process.cwd(), witnessPath),
    path.resolve(ROOT, witnessPath),
    path.resolve(path.dirname(ROOT), witnessPath)
  ];

  for (const candidate of candidates) {
    try {
      await access(candidate);
      return await readFile(candidate, "utf8");
    } catch {}
  }

  throw new Error(`witness file not found: ${witnessPath}`);
}

async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(typeof chunk === "string" ? Buffer.from(chunk) : chunk);
  }
  return Buffer.concat(chunks).toString("utf8");
}
