import { access, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { AbiCoder } from "ethers";
import { buildPoseidon } from "circomlibjs";
import { execa } from "./execa.mjs";

const abiCoder = AbiCoder.defaultAbiCoder();
const poseidon = await buildPoseidon();
const FIELD = poseidon.F;

const CIRCUIT_BY_PHASE = {
  "initial-deal": "blackjack_initial_deal",
  action: "blackjack_action_resolve",
  showdown: "blackjack_showdown"
};

export function blackjackCircuitForPhase(phase) {
  const circuit = CIRCUIT_BY_PHASE[phase];
  if (!circuit) {
    throw new Error(`unsupported blackjack proving phase: ${phase}`);
  }
  return circuit;
}

export async function generateBlackjackArtifact({
  root,
  phase,
  witness,
  name = `blackjack-${phase}`
}) {
  const circuit = blackjackCircuitForPhase(phase);
  const input = deriveBlackjackInput(phase, witness);
  const { proof, publicSignals } = await fullProveBlackjack({
    root,
    circuit,
    input,
    name
  });

  return {
    proof: encodeProof(proof),
    publicSignals,
    input
  };
}

export async function generateBlackjackPayload(args) {
  const artifact = await generateBlackjackArtifact(args);
  return formatBlackjackPayload(args.phase, artifact);
}

async function fullProveBlackjack({ root, circuit, input, name }) {
  const cacheDir = path.join(root, ".cache", circuit);
  const wasm = path.join(cacheDir, `${circuit}_js`, `${circuit}.wasm`);
  const zkey = path.join(cacheDir, `${circuit}_final.zkey`);
  await access(wasm);
  await access(zkey);

  const tmpDir = await mkdtemp(path.join(os.tmpdir(), `scuro-${circuit}-`));
  const inputFile = path.join(tmpDir, `${name}.input.json`);
  const proofFile = path.join(tmpDir, `${name}.proof.json`);
  const publicFile = path.join(tmpDir, `${name}.public.json`);

  try {
    await writeFile(inputFile, JSON.stringify(input, null, 2));
    await execa("bunx", ["snarkjs", "groth16", "fullprove", inputFile, wasm, zkey, proofFile, publicFile], {
      cwd: root,
      stdio: "ignore"
    });

    return {
      proof: JSON.parse(await readFile(proofFile, "utf8")),
      publicSignals: JSON.parse(await readFile(publicFile, "utf8"))
    };
  } finally {
    await rm(tmpDir, { recursive: true, force: true });
  }
}

function formatBlackjackPayload(phase, artifact) {
  switch (phase) {
    case "initial-deal":
      return {
        proof: artifact.proof,
        deckCommitment: formatBytes32(artifact.input.deckCommitment),
        handNonce: formatBytes32(artifact.input.handNonce),
        playerStateCommitment: formatBytes32(artifact.input.playerStateCommitment),
        dealerStateCommitment: formatBytes32(artifact.input.dealerStateCommitment),
        playerCiphertextRef: formatBytes32(artifact.input.playerCiphertextRef),
        dealerCiphertextRef: formatBytes32(artifact.input.dealerCiphertextRef),
        dealerVisibleValue: String(artifact.input.dealerUpValue),
        playerCards: formatStringArray(artifact.input.playerCards),
        dealerCards: formatStringArray(artifact.input.dealerCards),
        handCount: String(artifact.input.handCount),
        activeHandIndex: String(artifact.input.activeHandIndex),
        payout: String(artifact.input.payout),
        immediateResultCode: String(artifact.input.immediateResultCode),
        handValues: formatStringArray(artifact.input.handValues),
        handStatuses: formatStringArray(artifact.input.handStatuses),
        allowedActionMasks: formatStringArray(artifact.input.allowedActionMasks),
        handCardCounts: formatStringArray(artifact.input.handCardCounts),
        handPayoutKinds: formatStringArray(artifact.input.handPayoutKinds),
        dealerRevealMask: String(artifact.input.dealerRevealMask),
        softMask: String(artifact.input.softMask)
      };
    case "action":
      return {
        kind: "action",
        args: {
          newPlayerStateCommitment: formatBytes32(artifact.input.newPlayerStateCommitment),
          dealerStateCommitment: formatBytes32(artifact.input.dealerStateCommitment),
          playerCiphertextRef: formatBytes32(artifact.input.playerCiphertextRef),
          dealerCiphertextRef: formatBytes32(artifact.input.dealerCiphertextRef),
          dealerVisibleValue: String(artifact.input.dealerUpValue),
          playerCards: formatStringArray(artifact.input.playerCards),
          dealerCards: formatStringArray(artifact.input.dealerCards),
          handCount: String(artifact.input.handCount),
          activeHandIndex: String(artifact.input.activeHandIndex),
          nextPhase: String(artifact.input.nextPhase),
          handValues: formatStringArray(artifact.input.handValues),
          handStatuses: formatStringArray(artifact.input.handStatuses),
          allowedActionMasks: formatStringArray(artifact.input.allowedActionMasks),
          handCardCounts: formatStringArray(artifact.input.handCardCounts),
          handPayoutKinds: formatStringArray(artifact.input.handPayoutKinds),
          dealerRevealMask: String(artifact.input.dealerRevealMask),
          softMask: String(artifact.input.softMask),
          proof: artifact.proof
        }
      };
    case "showdown":
      return {
        kind: "showdown",
        args: {
          playerStateCommitment: formatBytes32(artifact.input.playerStateCommitment),
          dealerStateCommitment: formatBytes32(artifact.input.dealerStateCommitment),
          payout: String(artifact.input.payout),
          dealerFinalValue: String(artifact.input.dealerFinalValue),
          playerCards: formatStringArray(artifact.input.playerCards),
          dealerCards: formatStringArray(artifact.input.dealerCards),
          handCount: String(artifact.input.handCount),
          activeHandIndex: String(artifact.input.activeHandIndex),
          handStatuses: formatStringArray(artifact.input.handStatuses),
          handValues: formatStringArray(artifact.input.handValues),
          handCardCounts: formatStringArray(artifact.input.handCardCounts),
          handPayoutKinds: formatStringArray(artifact.input.handPayoutKinds),
          dealerRevealMask: String(artifact.input.dealerRevealMask),
          proof: artifact.proof
        }
      };
    default:
      throw new Error(`unsupported blackjack payload phase: ${phase}`);
  }
}

function formatStringArray(values) {
  return values.map((value) => String(value));
}

function formatBytes32(value) {
  if (typeof value === "string" && value.startsWith("0x")) {
    return value;
  }
  return `0x${BigInt(value).toString(16).padStart(64, "0")}`;
}

function deriveBlackjackInput(phase, witness) {
  switch (phase) {
    case "initial-deal":
      return deriveBlackjackInitialDeal(witness);
    case "action":
      return deriveBlackjackActionResolve(witness);
    case "showdown":
      return deriveBlackjackShowdown(witness);
    default:
      throw new Error(`unsupported blackjack input phase: ${phase}`);
  }
}

function deriveBlackjackInitialDeal(w) {
  const handCardCounts = [2, 0, 0, 0];
  const [playerHand] = partitionHands(w.playerCards, handCardCounts);
  const playerScore = scoreHand(playerHand);
  const dealerScore = scoreHand(w.dealerPrivateCards.slice(0, 2));
  const playerNatural = isNaturalBlackjack(playerHand);
  const dealerNatural = isNaturalBlackjack(w.dealerPrivateCards.slice(0, 2));
  const suitedNatural = playerNatural && sameSuit(playerHand[0], playerHand[1]);
  const splitEligible = sameRank(playerHand[0], playerHand[1]) && !playerNatural && !dealerNatural;

  let payout = 0n;
  let immediateResultCode = 0;
  let handStatus = 0;
  let handPayoutKind = 0;
  let revealMask = 1;
  let dealerCards = [w.dealerPrivateCards[0], 52, 52, 52];

  if (playerNatural && dealerNatural) {
    payout = BigInt(w.baseWager);
    immediateResultCode = 3;
    handStatus = 3;
    handPayoutKind = 2;
    revealMask = 3;
    dealerCards = [w.dealerPrivateCards[0], w.dealerPrivateCards[1], 52, 52];
  } else if (playerNatural) {
    payout = suitedNatural ? BigInt(w.baseWager) * 3n : (BigInt(w.baseWager) * 5n) / 2n;
    immediateResultCode = 2;
    handStatus = 4;
    handPayoutKind = suitedNatural ? 5 : 4;
    revealMask = 3;
    dealerCards = [w.dealerPrivateCards[0], w.dealerPrivateCards[1], 52, 52];
  } else if (dealerNatural) {
    payout = 0n;
    immediateResultCode = 1;
    handStatus = 5;
    handPayoutKind = 1;
    revealMask = 3;
    dealerCards = [w.dealerPrivateCards[0], w.dealerPrivateCards[1], 52, 52];
  }

  const handValues = [playerScore.total, 0, 0, 0];
  const softMask = playerScore.soft ? 1 : 0;
  const handStatuses = [handStatus, 0, 0, 0];
  const allowedActionMasks = immediateResultCode === 0 ? [7 + (splitEligible ? 8 : 0), 0, 0, 0] : [0, 0, 0, 0];
  const handPayoutKinds = [handPayoutKind, 0, 0, 0];
  const dealerUpValue = cardValue(w.dealerPrivateCards[0]);

  const playerStateCommitment = hash([w.sessionId, ...w.playerCards, ...handCardCounts, w.playerSalt]);
  const dealerStateCommitment = hash([w.sessionId, ...w.dealerPrivateCards, w.dealerSalt]);
  const playerKeyCommitment = hash([w.sessionId, ...w.playerKey]);
  const playerSummaryHash = hashCompact([
    ...handValues,
    softMask,
    ...handStatuses,
    ...allowedActionMasks,
    ...handCardCounts,
    ...handPayoutKinds,
    ...w.playerCards
  ]);
  const dealerCiphertextRef = hash([
    w.sessionId,
    w.handNonce,
    ...w.dealerPrivateCards,
    dealerUpValue,
    1,
    payout.toString(),
    immediateResultCode,
    revealMask,
    w.dealerCipherSalt
  ]);
  const deckCommitment = hash([w.sessionId, w.handNonce, ...w.playerCards, ...w.dealerPrivateCards, w.deckSalt]);

  return {
    ...w,
    handCount: "1",
    activeHandIndex: "0",
    payout: payout.toString(),
    immediateResultCode: immediateResultCode.toString(),
    handValues: handValues.map(String),
    softMask: String(softMask),
    handStatuses: handStatuses.map(String),
    allowedActionMasks: allowedActionMasks.map(String),
    handCardCounts: handCardCounts.map(String),
    handPayoutKinds: handPayoutKinds.map(String),
    dealerCards: dealerCards.map(String),
    dealerRevealMask: String(revealMask),
    dealerUpValue: String(dealerUpValue),
    playerStateCommitment,
    dealerStateCommitment,
    playerKeyCommitment,
    playerCiphertextRef: hashCompact([
      w.sessionId,
      w.handNonce,
      ...w.playerCards,
      ...handCardCounts,
      playerSummaryHash,
      ...w.playerKey,
      w.playerCipherSalt
    ]),
    dealerCiphertextRef,
    deckCommitment
  };
}

function deriveBlackjackActionResolve(w) {
  const hands = partitionHands(w.playerCards, w.handCardCounts);
  const handScores = hands.map(scoreHand);
  const handValues = handScores.map((score) => score.total);
  while (handValues.length < 4) handValues.push(0);
  const softMask = handScores.reduce((mask, score, index) => mask + (score.soft ? 1 << index : 0), 0);
  const handStatuses = handScores.map((score) => (score.total > 21 ? 2 : 0));
  while (handStatuses.length < 4) handStatuses.push(0);
  const handPayoutKinds = handStatuses.map((status) => (status === 2 ? 1 : 0));
  while (handPayoutKinds.length < 4) handPayoutKinds.push(0);

  const activeScore = handScores[Number(w.activeHandIndex)] ?? { total: 0 };
  const activeCards = hands[Number(w.activeHandIndex)] ?? [];
  const splitEligible =
    String(w.nextPhase) === "2" &&
    Number(w.handCardCounts[Number(w.activeHandIndex)] ?? 0) === 2 &&
    activeCards.length === 2 &&
    sameRank(activeCards[0], activeCards[1]);

  const allowedActionMasks = [0, 0, 0, 0];
  if (String(w.nextPhase) === "2") {
    const activeIndex = Number(w.activeHandIndex);
    if (activeScore.total <= 21 && activeIndex < 4) {
      allowedActionMasks[activeIndex] = 3 + (Number(w.handCardCounts[activeIndex]) === 2 ? 4 : 0) + (splitEligible ? 8 : 0);
    }
  }

  const dealerCards = [w.dealerPrivateCards[0], 52, 52, 52];
  const dealerRevealMask = 1;
  const dealerUpValue = cardValue(w.dealerPrivateCards[0]);

  const oldPlayerStateCommitment = hash([w.sessionId, ...w.oldPlayerCards, ...w.oldHandCardCounts, w.oldPlayerSalt]);
  const newPlayerStateCommitment = hash([w.sessionId, ...w.playerCards, ...w.handCardCounts, w.newPlayerSalt]);
  const dealerStateCommitment = hash([w.sessionId, ...w.dealerPrivateCards, w.dealerSalt]);
  const playerKeyCommitment = hash([w.sessionId, ...w.playerKey]);
  const playerSummaryHash = hashCompact([
    ...handValues,
    softMask,
    ...handStatuses,
    ...allowedActionMasks,
    ...w.handCardCounts,
    ...handPayoutKinds,
    ...w.playerCards
  ]);
  const playerCiphertextRef = hashCompact([
    w.sessionId,
    w.proofSequence,
    w.pendingAction,
    ...w.playerCards,
    ...w.handCardCounts,
    playerSummaryHash,
    ...w.playerKey,
    w.playerCipherSalt,
    w.handCount
  ]);
  const dealerCiphertextRef = hash([
    w.sessionId,
    w.proofSequence,
    w.nextPhase,
    ...w.dealerPrivateCards,
    dealerUpValue,
    w.handCount,
    w.activeHandIndex,
    dealerRevealMask,
    w.dealerCipherSalt
  ]);

  return {
    ...w,
    dealerCards: dealerCards.map(String),
    dealerRevealMask: String(dealerRevealMask),
    dealerUpValue: String(dealerUpValue),
    handValues: handValues.map(String),
    softMask: String(softMask),
    handStatuses: handStatuses.map(String),
    allowedActionMasks: allowedActionMasks.map(String),
    handPayoutKinds: handPayoutKinds.map(String),
    oldPlayerStateCommitment,
    newPlayerStateCommitment,
    dealerStateCommitment,
    playerKeyCommitment,
    playerCiphertextRef,
    dealerCiphertextRef
  };
}

function deriveBlackjackShowdown(w) {
  const hands = partitionHands(w.playerCards, w.handCardCounts);
  const handScores = hands.map(scoreHand);
  const dealerScore = scoreHand(w.dealerPrivateCards.filter((card) => Number(card) !== 52));
  const dealerCards = w.dealerPrivateCards.slice();
  const dealerRevealMask = dealerCards.reduce((mask, card, index) => mask + (Number(card) !== 52 ? 1 << index : 0), 0);

  const handValues = handScores.map((score) => score.total);
  while (handValues.length < 4) handValues.push(0);

  const handStatuses = [];
  const handPayoutKinds = [];
  let payout = 0n;
  for (let index = 0; index < 4; index += 1) {
    const cards = hands[index] ?? [];
    const wager = BigInt(w.handWagers[index] ?? 0);
    const value = handValues[index];
    if (cards.length === 0) {
      handStatuses.push(0);
      handPayoutKinds.push(0);
      continue;
    }
    if (value > 21) {
      handStatuses.push(2);
      handPayoutKinds.push(1);
      continue;
    }
    if (dealerScore.total > 21 || value > dealerScore.total) {
      handStatuses.push(4);
      handPayoutKinds.push(3);
      payout += wager * 2n;
      continue;
    }
    if (value === dealerScore.total) {
      handStatuses.push(3);
      handPayoutKinds.push(2);
      payout += wager;
      continue;
    }
    handStatuses.push(5);
    handPayoutKinds.push(1);
  }
  while (handStatuses.length < 4) handStatuses.push(0);
  while (handPayoutKinds.length < 4) handPayoutKinds.push(0);

  const playerStateCommitment = hash([w.sessionId, ...w.playerCards, ...w.handCardCounts, w.playerSalt]);
  const dealerStateCommitment = hash([w.sessionId, ...w.dealerPrivateCards, w.dealerSalt]);

  return {
    ...w,
    dealerCards: dealerCards.map(String),
    dealerRevealMask: String(dealerRevealMask),
    handValues: handValues.map(String),
    handStatuses: handStatuses.map(String),
    handPayoutKinds: handPayoutKinds.map(String),
    payout: payout.toString(),
    dealerFinalValue: String(dealerScore.total),
    playerStateCommitment,
    dealerStateCommitment
  };
}

function hash(values) {
  return normalize(FIELD.toObject(poseidon(values.map((value) => BigInt(value)))));
}

function hashCompact(values) {
  if (values.length <= 16) {
    return hash(values);
  }

  let acc = hash(values.slice(0, 16));
  for (let index = 16; index < values.length; index += 15) {
    acc = hash([acc, ...values.slice(index, index + 15)]);
  }
  return acc;
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

function cardMeta(card) {
  const numeric = Number(card);
  if (numeric === 52) {
    return { real: false, rank: 52, suit: -1, value: 0, isAce: false, isTenValue: false };
  }

  const rank = numeric % 13;
  const suit = Math.floor(numeric / 13);
  const isAce = rank === 0;
  const isTenValue = rank >= 9;
  const value = isAce ? 11 : isTenValue ? 10 : rank + 1;
  return { real: true, rank, suit, value, isAce, isTenValue };
}

function cardValue(card) {
  return cardMeta(card).value;
}

function sameSuit(cardA, cardB) {
  return cardMeta(cardA).suit === cardMeta(cardB).suit;
}

function sameRank(cardA, cardB) {
  return cardMeta(cardA).rank === cardMeta(cardB).rank;
}

function scoreHand(cards) {
  let total = 0;
  let aces = 0;
  for (const card of cards) {
    const meta = cardMeta(card);
    if (!meta.real) continue;
    total += meta.value;
    if (meta.isAce) aces += 1;
  }
  while (total > 21 && aces > 0) {
    total -= 10;
    aces -= 1;
  }
  return { total, soft: aces > 0 };
}

function isNaturalBlackjack(cards) {
  if (cards.length !== 2) return false;
  const first = cardMeta(cards[0]);
  const second = cardMeta(cards[1]);
  return (first.isAce && second.isTenValue) || (second.isAce && first.isTenValue);
}

function partitionHands(playerCards, handCardCounts) {
  const cards = playerCards.map(Number);
  const counts = handCardCounts.map(Number);
  const hands = [];
  let offset = 0;
  for (const count of counts) {
    if (count === 0) {
      hands.push([]);
      continue;
    }
    hands.push(cards.slice(offset, offset + count).filter((card) => card !== 52));
    offset += count;
  }
  return hands;
}
