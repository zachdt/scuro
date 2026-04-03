import { mkdir, readFile, stat, writeFile } from "node:fs/promises";
import path from "node:path";
import { execa } from "./lib/execa.mjs";

const ROOT = path.resolve(import.meta.dirname, "..");
const CACHE_DIR = path.join(ROOT, ".cache");
const VKEY_DIR = path.join(ROOT, "vkeys");
const SRC_VERIFIER_DIR = path.resolve(ROOT, "..", "src", "verifiers", "generated");

const CIRCUITS = [
  { circuit: "poker_initial_deal", contract: "PokerInitialDealVerifier" },
  { circuit: "poker_draw_resolve", contract: "PokerDrawResolveVerifier" },
  { circuit: "poker_showdown", contract: "PokerShowdownVerifier" },
  { circuit: "blackjack_initial_deal", contract: "BlackjackInitialDealVerifier" },
  { circuit: "blackjack_peek_resolve", contract: "BlackjackPeekVerifier" },
  { circuit: "blackjack_action_resolve", contract: "BlackjackActionResolveVerifier" },
  { circuit: "blackjack_showdown", contract: "BlackjackShowdownVerifier" }
];

const requestedCircuits = process.argv.slice(2);
const selectedCircuits = selectCircuits(requestedCircuits);

const PTAU = path.join(CACHE_DIR, "pot15_final.ptau");

await mkdir(CACHE_DIR, { recursive: true });
await mkdir(VKEY_DIR, { recursive: true });
await mkdir(SRC_VERIFIER_DIR, { recursive: true });

await ensurePtau();

for (const item of selectedCircuits) {
  console.log(`building ${item.circuit}`);
  await compileCircuit(item);
  await setupGroth16(item);
  await exportVerifier(item);
}

function selectCircuits(requested) {
  if (requested.length === 0) {
    return CIRCUITS;
  }

  const selected = CIRCUITS.filter((item) => requested.includes(item.circuit));
  if (selected.length !== requested.length) {
    const known = new Set(selected.map((item) => item.circuit));
    const unknown = requested.filter((name) => !known.has(name));
    throw new Error(`unknown circuits requested: ${unknown.join(", ")}`);
  }
  return selected;
}

async function ensurePtau() {
  try {
    await stat(PTAU);
    return;
  } catch {}

  const p0 = path.join(CACHE_DIR, "pot15_0000.ptau");
  const p1 = path.join(CACHE_DIR, "pot15_0001.ptau");
  await execa("bunx", ["snarkjs", "powersoftau", "new", "bn128", "15", p0, "-v"], { cwd: ROOT });
  await execa("bunx", ["snarkjs", "powersoftau", "contribute", p0, p1, "--name=Scuro", "-e=real-zk-rollout"], {
    cwd: ROOT
  });
  await execa("bunx", ["snarkjs", "powersoftau", "prepare", "phase2", p1, PTAU], { cwd: ROOT });
}

async function compileCircuit({ circuit }) {
  const outDir = path.join(CACHE_DIR, circuit);
  await mkdir(outDir, { recursive: true });
  await execa(
    "bunx",
    ["circom2", path.join(ROOT, "circuits", `${circuit}.circom`), "--r1cs", "--wasm", "--sym", "-l", "node_modules", "-o", outDir],
    { cwd: ROOT }
  );
}

async function setupGroth16({ circuit }) {
  const outDir = path.join(CACHE_DIR, circuit);
  const r1cs = path.join(outDir, `${circuit}.r1cs`);
  const zkey0 = path.join(outDir, `${circuit}_0000.zkey`);
  const zkey = path.join(outDir, `${circuit}_final.zkey`);
  await execa("bunx", ["snarkjs", "groth16", "setup", r1cs, PTAU, zkey0], { cwd: ROOT });
  await execa("bunx", ["snarkjs", "zkey", "contribute", zkey0, zkey, "--name=Scuro", "-e=fixture-proof"], {
    cwd: ROOT
  });
  await execa("bunx", ["snarkjs", "zkey", "export", "verificationkey", zkey, path.join(VKEY_DIR, `${circuit}.vkey.json`)], {
    cwd: ROOT
  });
}

async function exportVerifier({ circuit, contract }) {
  const outDir = path.join(CACHE_DIR, circuit);
  const zkey = path.join(outDir, `${circuit}_final.zkey`);
  const verifierFile = path.join(SRC_VERIFIER_DIR, `${contract}.sol`);
  const tmpFile = path.join(outDir, `${contract}.tmp.sol`);
  await execa("bunx", ["snarkjs", "zkey", "export", "solidityverifier", zkey, tmpFile], { cwd: ROOT });

  let source = await readFile(tmpFile, "utf8");
  source = source.replace("contract Groth16Verifier", `contract ${contract}`);
  await writeFile(verifierFile, source);
}
