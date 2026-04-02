import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { AbiCoder } from "ethers";
import { buildPoseidon } from "circomlibjs";
import { execa } from "./lib/execa.mjs";
import { generateBlackjackArtifact } from "./lib/blackjack-proof.mjs";

const ROOT = path.resolve(import.meta.dirname, "..");
const CACHE_DIR = path.join(ROOT, ".cache");
const FIXTURE_WITNESS_DIR = path.join(ROOT, "fixtures", "witness");
const FIXTURE_OUTPUT_DIR = path.join(ROOT, "fixtures", "generated");
const FIXTURE_INPUT_DIR = path.join(ROOT, ".cache", "inputs");
const abiCoder = AbiCoder.defaultAbiCoder();
const poseidon = await buildPoseidon();
const FIELD = poseidon.F;

const CASES = [
  { name: "poker_initial_deal", circuit: "poker_initial_deal" },
  { name: "poker_draw_resolve", circuit: "poker_draw_resolve" },
  { name: "poker_draw_resolve_player1", circuit: "poker_draw_resolve" },
  { name: "poker_showdown", circuit: "poker_showdown" },
  { name: "poker_showdown_tie", circuit: "poker_showdown" },
  { name: "blackjack_initial_deal", circuit: "blackjack_initial_deal" },
  { name: "blackjack_initial_deal_unsuited_natural", circuit: "blackjack_initial_deal" },
  { name: "blackjack_initial_deal_suited_natural", circuit: "blackjack_initial_deal" },
  { name: "blackjack_initial_deal_push_natural", circuit: "blackjack_initial_deal" },
  { name: "blackjack_initial_deal_split_pair", circuit: "blackjack_initial_deal" },
  { name: "blackjack_action_resolve", circuit: "blackjack_action_resolve" },
  { name: "blackjack_action_resolve_twentyone", circuit: "blackjack_action_resolve" },
  { name: "blackjack_action_resolve_split", circuit: "blackjack_action_resolve" },
  { name: "blackjack_showdown", circuit: "blackjack_showdown" },
  { name: "blackjack_showdown_even_money", circuit: "blackjack_showdown" }
];

await mkdir(FIXTURE_OUTPUT_DIR, { recursive: true });
await mkdir(FIXTURE_INPUT_DIR, { recursive: true });

for (const item of CASES) {
  const { name, circuit } = item;
  const witness = JSON.parse(await readFile(path.join(FIXTURE_WITNESS_DIR, `${name}.json`), "utf8"));
  const phase = blackjackPhaseForCircuit(circuit);

  if (phase) {
    const artifact = await generateBlackjackArtifact({
      root: ROOT,
      phase,
      witness,
      name
    });
    await writeFile(path.join(FIXTURE_OUTPUT_DIR, `${name}.json`), JSON.stringify(artifact, null, 2));
    continue;
  }

  const fullInput = deriveInput(circuit, witness);
  const outDir = path.join(CACHE_DIR, circuit);
  const wasm = path.join(outDir, `${circuit}_js`, `${circuit}.wasm`);
  const zkey = path.join(outDir, `${circuit}_final.zkey`);
  const proofFile = path.join(outDir, `${name}.proof.json`);
  const publicFile = path.join(outDir, `${name}.public.json`);
  const inputFile = path.join(FIXTURE_INPUT_DIR, `${name}.json`);

  await writeFile(inputFile, JSON.stringify(fullInput, null, 2));
  await execa("bunx", ["snarkjs", "groth16", "fullprove", inputFile, wasm, zkey, proofFile, publicFile], { cwd: ROOT });

  const proof = JSON.parse(await readFile(proofFile, "utf8"));
  const publicSignals = JSON.parse(await readFile(publicFile, "utf8"));

  await writeFile(
    path.join(FIXTURE_OUTPUT_DIR, `${name}.json`),
    JSON.stringify(
      {
        proof: encodeProof(proof),
        publicSignals,
        input: fullInput
      },
      null,
      2
    )
  );
}

function blackjackPhaseForCircuit(circuit) {
  switch (circuit) {
    case "blackjack_initial_deal":
      return "initial-deal";
    case "blackjack_action_resolve":
      return "action";
    case "blackjack_showdown":
      return "showdown";
    default:
      return null;
  }
}

function deriveInput(circuit, witness) {
  switch (circuit) {
    case "poker_initial_deal":
      return derivePokerInitialDeal(witness);
    case "poker_draw_resolve":
      return derivePokerDrawResolve(witness);
    case "poker_showdown":
      return derivePokerShowdown(witness);
    default:
      throw new Error(`unknown circuit ${circuit}`);
  }
}

function derivePokerInitialDeal(w) {
  const handCommitment0 = hash([w.gameId, w.handNumber, w.handNonce, ...w.hand0Cards, w.hand0Salt]);
  const handCommitment1 = hash([w.gameId, w.handNumber, w.handNonce, ...w.hand1Cards, w.hand1Salt]);
  const keyCommitment0 = hash([w.gameId, w.handNumber, ...w.key0]);
  const keyCommitment1 = hash([w.gameId, w.handNumber, ...w.key1]);
  const ciphertextRef0 = hash([w.gameId, w.handNumber, w.handNonce, ...w.hand0Cards, ...w.key0, w.cipherSalt0]);
  const ciphertextRef1 = hash([w.gameId, w.handNumber, w.handNonce, ...w.hand1Cards, ...w.key1, w.cipherSalt1]);
  const deckCommitment = hash([w.gameId, w.handNumber, w.handNonce, ...w.hand0Cards, ...w.hand1Cards, w.deckSalt]);

  return {
    ...w,
    handCommitment0,
    handCommitment1,
    keyCommitment0,
    keyCommitment1,
    ciphertextRef0,
    ciphertextRef1,
    deckCommitment
  };
}

function derivePokerDrawResolve(w) {
  const oldCommitment = hash([w.gameId, w.handNumber, w.handNonce, ...w.oldCards, w.oldSalt]);
  const newCards = [];
  for (let i = 0; i < 5; i += 1) {
    const bit = (Number(w.discardMask) >> i) & 1;
    newCards.push(bit === 1 ? w.replacementCards[i] : w.oldCards[i]);
  }
  const newCommitment = hash([w.gameId, w.handNumber, w.handNonce, ...newCards, w.newSalt]);
  const newKeyCommitment = hash([w.gameId, w.handNumber, ...w.key]);
  const newCiphertextRef = hash([
    w.gameId,
    w.handNumber,
    w.handNonce,
    ...newCards,
    ...w.key,
    w.cipherSalt,
    w.proofSequence,
    w.discardMask,
    w.playerIndex
  ]);
  const deckCommitment = hash([
    w.gameId,
    w.handNumber,
    w.handNonce,
    ...w.initialHand0Cards,
    ...w.initialHand1Cards,
    w.deckSalt
  ]);

  return {
    ...w,
    oldCommitment,
    newCommitment,
    newKeyCommitment,
    newCiphertextRef,
    deckCommitment
  };
}

function derivePokerShowdown(w) {
  const handCommitment0 = hash([w.gameId, w.handNumber, w.handNonce, ...w.hand0Cards, w.hand0Salt]);
  const handCommitment1 = hash([w.gameId, w.handNumber, w.handNonce, ...w.hand1Cards, w.hand1Salt]);
  const isTie = Number(w.hand0Score) === Number(w.hand1Score) ? 1 : 0;
  const winnerIndex = isTie === 1 ? 2 : Number(w.hand0Score) < Number(w.hand1Score) ? 0 : 1;

  return {
    ...w,
    handCommitment0,
    handCommitment1,
    winnerIndex,
    isTie
  };
}

function hash(values) {
  return normalize(FIELD.toObject(poseidon(values.map((value) => BigInt(value)))));
}

function normalize(value) {
  return BigInt(value).toString();
}

function encodeProof(proof) {
  const a = [BigInt(proof.pi_a[0]), BigInt(proof.pi_a[1])];
  const b = [
    [BigInt(proof.pi_b[0][1]), BigInt(proof.pi_b[0][0])],
    [BigInt(proof.pi_b[1][1]), BigInt(proof.pi_b[1][0])]
  ];
  const c = [BigInt(proof.pi_c[0]), BigInt(proof.pi_c[1])];
  return abiCoder.encode(["tuple(uint256[2] a, uint256[2][2] b, uint256[2] c)"], [{ a, b, c }]);
}
