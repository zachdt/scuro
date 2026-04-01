import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { AbiCoder } from "ethers";
import { buildPoseidon } from "circomlibjs";
import { execa } from "./lib/execa.mjs";

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
  { name: "blackjack_showdown", circuit: "blackjack_showdown" }
  ,
  { name: "blackjack_showdown_even_money", circuit: "blackjack_showdown" }
];

await mkdir(FIXTURE_OUTPUT_DIR, { recursive: true });
await mkdir(FIXTURE_INPUT_DIR, { recursive: true });

for (const item of CASES) {
  const { name, circuit } = item;
  const witness = JSON.parse(await readFile(path.join(FIXTURE_WITNESS_DIR, `${name}.json`), "utf8"));
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

function deriveInput(circuit, witness) {
  switch (circuit) {
    case "poker_initial_deal":
      return derivePokerInitialDeal(witness);
    case "poker_draw_resolve":
      return derivePokerDrawResolve(witness);
    case "poker_showdown":
      return derivePokerShowdown(witness);
    case "blackjack_initial_deal":
      return deriveBlackjackInitialDeal(witness);
    case "blackjack_action_resolve":
      return deriveBlackjackActionResolve(witness);
    case "blackjack_showdown":
      return deriveBlackjackShowdown(witness);
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
