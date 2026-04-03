import { access, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { buildPoseidon } from "circomlibjs";
import { execa } from "./execa.mjs";
import { encodeGroth16Proof } from "./groth16-proof-encoder.mjs";

const poseidon = await buildPoseidon();
const FIELD = poseidon.F;

const MAX_PLAYER_CARDS = 32;
const MAX_DEALER_CARDS = 12;
const CARD_EMPTY = 104;

const PHASE = {
  INACTIVE: 0,
  AWAITING_INITIAL_DEAL: 1,
  AWAITING_PREPLAY_DECISION: 2,
  AWAITING_PEEK_RESOLUTION: 3,
  AWAITING_POSTPEEK_DECISION: 4,
  AWAITING_PLAYER_ACTION: 5,
  AWAITING_COORDINATOR_ACTION: 6,
  COMPLETED: 7
};

const ACTION = {
  HIT: 1,
  STAND: 2,
  DOUBLE: 3,
  SPLIT: 4
};

const ALLOW = {
  HIT: 1,
  STAND: 2,
  DOUBLE: 4,
  SPLIT: 8
};

const HAND_STATUS = {
  NONE: 0,
  ACTIVE: 1,
  STAND: 2,
  BUST: 3,
  PUSH: 4,
  WIN: 5,
  LOSS: 6,
  BLACKJACK: 7,
  SURRENDERED: 8
};

const HAND_PAYOUT = {
  NONE: 0,
  LOSS: 1,
  PUSH: 2,
  EVEN_MONEY: 3,
  BLACKJACK_3_TO_2: 4,
  SURRENDER: 5
};

const DECISION = {
  NONE: 0,
  INSURANCE: 1,
  EARLY_SURRENDER: 2,
  LATE_SURRENDER: 3
};

const INSURANCE = {
  NONE: 0,
  AVAILABLE: 1,
  DECLINED: 2,
  TAKEN: 3,
  LOST: 4,
  WON: 5
};

const SURRENDER = {
  NONE: 0,
  AVAILABLE: 1,
  DECLINED: 2,
  TAKEN: 3,
  VOID: 4
};

const CIRCUIT_BY_PHASE = {
  "initial-deal": "blackjack_initial_deal",
  peek: "blackjack_peek_resolve",
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
    input: circuitInputForProver(input),
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
      stdio: "inherit"
    });

    return {
      proof: JSON.parse(await readFile(proofFile, "utf8")),
      publicSignals: JSON.parse(await readFile(publicFile, "utf8"))
    };
  } finally {
    await rm(tmpDir, { recursive: true, force: true });
  }
}

function circuitInputForProver(input) {
  const { publicState, ...circuitInput } = input;
  return circuitInput;
}

function formatBlackjackPayload(phase, artifact) {
  const common = {
    publicSignals: artifact.publicSignals,
    proof: artifact.proof
  };

  switch (phase) {
    case "initial-deal":
      return {
        ...common,
        deckCommitment: formatBytes32(artifact.input.deckCommitment),
        handNonce: formatBytes32(artifact.input.handNonce),
        playerStateCommitment: formatBytes32(artifact.input.playerStateCommitment),
        dealerStateCommitment: formatBytes32(artifact.input.dealerStateCommitment),
        playerKeyCommitment: formatBytes32(artifact.input.playerKeyCommitment),
        playerCiphertextRef: formatBytes32(artifact.input.playerCiphertextRef),
        dealerCiphertextRef: formatBytes32(artifact.input.dealerCiphertextRef),
        publicState: formatPublicState(artifact.input.publicState)
      };
    case "peek":
      return {
        ...common,
        kind: "peek",
        args: {
          playerStateCommitment: formatBytes32(artifact.input.playerStateCommitment),
          dealerStateCommitment: formatBytes32(artifact.input.dealerStateCommitment),
          playerCiphertextRef: formatBytes32(artifact.input.playerCiphertextRef),
          dealerCiphertextRef: formatBytes32(artifact.input.dealerCiphertextRef),
          publicState: formatPublicState(artifact.input.publicState),
          proof: artifact.proof
        }
      };
    case "action":
      return {
        ...common,
        kind: "action",
        args: {
          newPlayerStateCommitment: formatBytes32(artifact.input.newPlayerStateCommitment),
          dealerStateCommitment: formatBytes32(artifact.input.dealerStateCommitment),
          playerCiphertextRef: formatBytes32(artifact.input.playerCiphertextRef),
          dealerCiphertextRef: formatBytes32(artifact.input.dealerCiphertextRef),
          publicState: formatPublicState(artifact.input.publicState),
          proof: artifact.proof
        }
      };
    case "showdown":
      return {
        ...common,
        kind: "showdown",
        args: {
          playerStateCommitment: formatBytes32(artifact.input.playerStateCommitment),
          dealerStateCommitment: formatBytes32(artifact.input.dealerStateCommitment),
          publicState: formatPublicState(artifact.input.publicState),
          proof: artifact.proof
        }
      };
    default:
      throw new Error(`unsupported blackjack payload phase: ${phase}`);
  }
}

function formatPublicState(publicState) {
  return {
    phase: String(publicState.phase),
    decisionType: String(publicState.decisionType),
    dealerRevealMask: String(publicState.dealerRevealMask),
    handCount: String(publicState.handCount),
    activeHandIndex: String(publicState.activeHandIndex),
    peekAvailable: String(publicState.peekAvailable),
    peekResolved: String(publicState.peekResolved),
    dealerHasBlackjack: String(publicState.dealerHasBlackjack),
    insuranceAvailable: String(publicState.insuranceAvailable),
    insuranceStatus: String(publicState.insuranceStatus),
    surrenderAvailable: String(publicState.surrenderAvailable),
    surrenderStatus: String(publicState.surrenderStatus),
    dealerUpValue: String(publicState.dealerUpValue),
    dealerFinalValue: String(publicState.dealerFinalValue),
    payout: String(publicState.payout),
    insuranceStake: String(publicState.insuranceStake),
    insurancePayout: String(publicState.insurancePayout),
    hands: publicState.hands.map((hand) => ({
      wager: String(hand.wager),
      value: String(hand.value),
      status: String(hand.status),
      allowedActionMask: String(hand.allowedActionMask),
      cardCount: String(hand.cardCount),
      cardStartIndex: String(hand.cardStartIndex),
      payoutKind: String(hand.payoutKind)
    })),
    playerCards: publicState.playerCards.map((value) => String(value)),
    dealerCards: publicState.dealerCards.map((value) => String(value))
  };
}

function deriveBlackjackInput(phase, witness) {
  switch (phase) {
    case "initial-deal":
      return deriveBlackjackInitialDeal(witness);
    case "peek":
      return deriveBlackjackPeek(witness);
    case "action":
      return deriveBlackjackActionResolve(witness);
    case "showdown":
      return deriveBlackjackShowdown(witness);
    default:
      throw new Error(`unsupported blackjack input phase: ${phase}`);
  }
}

function deriveBlackjackInitialDeal(witness) {
  const w = normalizeInitialWitness(witness);
  const playerStateCommitment = hash([w.sessionId, ...padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY), ...w.handCardCounts, w.playerSalt]);
  const dealerStateCommitment = hash([w.sessionId, ...padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY), w.dealerSalt]);
  const playerKeyCommitment = hash([w.sessionId, ...w.playerKey]);
  const deckCommitment = hash([
    w.sessionId,
    w.handNonce,
    ...padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY),
    ...padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY),
    w.deckSalt
  ]);
  const playerCiphertextRef = hash([
    w.sessionId,
    w.handNonce,
    ...padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY).slice(0, 12),
    w.playerCipherSalt
  ]);
  const dealerCiphertextRef = hash([
    w.sessionId,
    w.handNonce,
    ...padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY).slice(0, 12),
    w.dealerCipherSalt
  ]);

  return {
    sessionId: String(w.sessionId),
    handNonce: normalizeHexish(w.handNonce).toString(),
    deckCommitment,
    playerStateCommitment,
    dealerStateCommitment,
    playerKeyCommitment,
    playerCiphertextRef,
    dealerCiphertextRef,
    ...flattenPublicStateInputs(w.publicState),
    publicState: serializePublicState(w.publicState),
    privatePlayerCards: padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY).map(String),
    privateDealerCards: padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY).map(String),
    handCardCounts: w.handCardCounts.map(String),
    playerSalt: String(w.playerSalt),
    dealerSalt: String(w.dealerSalt),
    deckSalt: String(w.deckSalt),
    playerCipherSalt: String(w.playerCipherSalt),
    dealerCipherSalt: String(w.dealerCipherSalt),
    playerKey: w.playerKey.map(String)
  };
}

function deriveBlackjackPeek(witness) {
  const w = normalizePeekWitness(witness);
  const playerStateCommitment = hash([w.sessionId, ...padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY), ...w.handCardCounts, w.playerSalt]);
  const dealerStateCommitment = hash([w.sessionId, ...padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY), w.dealerSalt]);
  const playerKeyCommitment = hash([w.sessionId, ...w.playerKey]);
  const playerCiphertextRef = hash([
    w.sessionId,
    w.proofSequence,
    ...padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY).slice(0, 12),
    w.playerCipherSalt
  ]);
  const dealerCiphertextRef = hash([
    w.sessionId,
    w.proofSequence,
    ...padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY).slice(0, 12),
    w.dealerCipherSalt
  ]);

  return {
    sessionId: String(w.sessionId),
    proofSequence: String(w.proofSequence),
    deckCommitment: normalizeHexish(w.deckCommitment).toString(),
    playerStateCommitment,
    dealerStateCommitment,
    playerKeyCommitment,
    playerCiphertextRef,
    dealerCiphertextRef,
    ...flattenPublicStateInputs(w.publicState),
    publicState: serializePublicState(w.publicState),
    privatePlayerCards: padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY).map(String),
    privateDealerCards: padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY).map(String),
    handCardCounts: w.handCardCounts.map(String),
    playerSalt: String(w.playerSalt),
    dealerSalt: String(w.dealerSalt),
    playerCipherSalt: String(w.playerCipherSalt),
    dealerCipherSalt: String(w.dealerCipherSalt),
    playerKey: w.playerKey.map(String)
  };
}

function deriveBlackjackActionResolve(witness) {
  const w = normalizeActionWitness(witness);
  const oldPlayerStateCommitment = hash([
    w.sessionId,
    ...padArray(w.oldPlayerCards, MAX_PLAYER_CARDS, CARD_EMPTY),
    ...w.oldHandCardCounts,
    w.oldPlayerSalt
  ]);
  const newPlayerStateCommitment = hash([
    w.sessionId,
    ...padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY),
    ...w.handCardCounts,
    w.newPlayerSalt
  ]);
  const dealerStateCommitment = hash([w.sessionId, ...padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY), w.dealerSalt]);
  const playerKeyCommitment = hash([w.sessionId, ...w.playerKey]);
  const playerCiphertextRef = hash([
    w.sessionId,
    w.proofSequence,
    w.pendingAction,
    ...padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY).slice(0, 10),
    w.playerCipherSalt
  ]);
  const dealerCiphertextRef = hash([
    w.sessionId,
    w.proofSequence,
    ...padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY).slice(0, 12),
    w.dealerCipherSalt
  ]);

  return {
    sessionId: String(w.sessionId),
    proofSequence: String(w.proofSequence),
    pendingAction: String(w.pendingAction),
    deckCommitment: normalizeHexish(w.deckCommitment).toString(),
    oldPlayerStateCommitment,
    newPlayerStateCommitment,
    dealerStateCommitment,
    playerKeyCommitment,
    playerCiphertextRef,
    dealerCiphertextRef,
    ...flattenPublicStateInputs(w.publicState),
    publicState: serializePublicState(w.publicState),
    privateOldPlayerCards: padArray(w.oldPlayerCards, MAX_PLAYER_CARDS, CARD_EMPTY).map(String),
    privatePlayerCards: padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY).map(String),
    privateDealerCards: padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY).map(String),
    oldHandCardCounts: w.oldHandCardCounts.map(String),
    handCardCounts: w.handCardCounts.map(String),
    oldPlayerSalt: String(w.oldPlayerSalt),
    newPlayerSalt: String(w.newPlayerSalt),
    dealerSalt: String(w.dealerSalt),
    playerCipherSalt: String(w.playerCipherSalt),
    dealerCipherSalt: String(w.dealerCipherSalt),
    playerKey: w.playerKey.map(String)
  };
}

function deriveBlackjackShowdown(witness) {
  const w = normalizeShowdownWitness(witness);
  const playerStateCommitment = hash([w.sessionId, ...padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY), ...w.handCardCounts, w.playerSalt]);
  const dealerStateCommitment = hash([w.sessionId, ...padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY), w.dealerSalt]);
  const playerKeyCommitment = hash([w.sessionId, ...w.playerKey]);

  return {
    sessionId: String(w.sessionId),
    proofSequence: String(w.proofSequence),
    deckCommitment: normalizeHexish(w.deckCommitment).toString(),
    playerStateCommitment,
    dealerStateCommitment,
    playerKeyCommitment,
    ...flattenPublicStateInputs(w.publicState),
    publicState: serializePublicState(w.publicState),
    privatePlayerCards: padArray(w.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY).map(String),
    privateDealerCards: padArray(w.dealerCardsFull, MAX_DEALER_CARDS, CARD_EMPTY).map(String),
    handCardCounts: w.handCardCounts.map(String),
    playerSalt: String(w.playerSalt),
    dealerSalt: String(w.dealerSalt),
    playerKey: w.playerKey.map(String)
  };
}

function normalizeInitialWitness(witness) {
  const sessionId = Number(witness.sessionId ?? 1);
  const baseWager = Number(witness.baseWager ?? 100);
  const playerCards = normalizeCards(witness.playerCards);
  const dealerCardsFull = normalizeCards(witness.dealerCards ?? witness.dealerPrivateCards);
  const handCardCounts = normalizeFour(witness.handCardCounts ?? [playerCards.length, 0, 0, 0]);
  const publicState = normalizePublicState({
    phase: witness.phase,
    decisionType: witness.decisionType,
    dealerRevealMask: witness.dealerRevealMask,
    handCount: witness.handCount,
    activeHandIndex: witness.activeHandIndex,
    peekAvailable: witness.peekAvailable,
    peekResolved: witness.peekResolved,
    dealerHasBlackjack: witness.dealerHasBlackjack,
    insuranceAvailable: witness.insuranceAvailable,
    insuranceStatus: witness.insuranceStatus,
    surrenderAvailable: witness.surrenderAvailable,
    surrenderStatus: witness.surrenderStatus,
    dealerUpValue: witness.dealerUpValue,
    dealerFinalValue: witness.dealerFinalValue,
    payout: witness.payout,
    insuranceStake: witness.insuranceStake,
    insurancePayout: witness.insurancePayout,
    handWagers: witness.handWagers ?? [baseWager, 0, 0, 0],
    handValues: witness.handValues,
    handStatuses: witness.handStatuses,
    allowedActionMasks: witness.allowedActionMasks,
    handCardCounts,
    handCardStartIndices: witness.handCardStartIndices,
    handPayoutKinds: witness.handPayoutKinds,
    playerCardsVisible: witness.playerCardsVisible ?? playerCards,
    dealerCardsVisible: witness.dealerCardsVisible
  }, {
    baseWager,
    playerCards,
    dealerCardsFull,
    handCardCounts,
    phaseHint: "initial-deal"
  });

  return {
    sessionId,
    handNonce: witness.handNonce ?? "0x01",
    playerKey: normalizePlayerKey(witness.playerKey ?? [11, 29]),
    playerCards,
    dealerCardsFull,
    handCardCounts,
    publicState,
    playerSalt: Number(witness.playerSalt ?? 101),
    dealerSalt: Number(witness.dealerSalt ?? 102),
    deckSalt: Number(witness.deckSalt ?? 103),
    playerCipherSalt: Number(witness.playerCipherSalt ?? 104),
    dealerCipherSalt: Number(witness.dealerCipherSalt ?? 105)
  };
}

function normalizePeekWitness(witness) {
  const sessionId = Number(witness.sessionId ?? 1);
  const playerCards = normalizeCards(witness.playerCards);
  const dealerCardsFull = normalizeCards(witness.dealerCards ?? witness.dealerPrivateCards);
  const handCardCounts = normalizeFour(witness.handCardCounts ?? [playerCards.length, 0, 0, 0]);
  const publicState = normalizePublicState({
    phase: witness.phase,
    decisionType: witness.decisionType,
    dealerRevealMask: witness.dealerRevealMask,
    handCount: witness.handCount,
    activeHandIndex: witness.activeHandIndex,
    peekAvailable: witness.peekAvailable,
    peekResolved: witness.peekResolved,
    dealerHasBlackjack: witness.dealerHasBlackjack,
    insuranceAvailable: witness.insuranceAvailable,
    insuranceStatus: witness.insuranceStatus,
    surrenderAvailable: witness.surrenderAvailable,
    surrenderStatus: witness.surrenderStatus,
    dealerUpValue: witness.dealerUpValue,
    dealerFinalValue: witness.dealerFinalValue,
    payout: witness.payout,
    insuranceStake: witness.insuranceStake,
    insurancePayout: witness.insurancePayout,
    handWagers: witness.handWagers ?? [Number(witness.baseWager ?? 100), 0, 0, 0],
    handValues: witness.handValues,
    handStatuses: witness.handStatuses,
    allowedActionMasks: witness.allowedActionMasks,
    handCardCounts,
    handCardStartIndices: witness.handCardStartIndices,
    handPayoutKinds: witness.handPayoutKinds,
    playerCardsVisible: witness.playerCardsVisible ?? playerCards,
    dealerCardsVisible: witness.dealerCardsVisible
  }, {
    baseWager: Number(witness.baseWager ?? 100),
    playerCards,
    dealerCardsFull,
    handCardCounts,
    phaseHint: "peek"
  });

  return {
    sessionId,
    proofSequence: Number(witness.proofSequence ?? 2),
    deckCommitment: witness.deckCommitment ?? "0x02",
    playerKey: normalizePlayerKey(witness.playerKey ?? [11, 29]),
    playerCards,
    dealerCardsFull,
    handCardCounts,
    publicState,
    playerSalt: Number(witness.playerSalt ?? 101),
    dealerSalt: Number(witness.dealerSalt ?? 102),
    playerCipherSalt: Number(witness.playerCipherSalt ?? 104),
    dealerCipherSalt: Number(witness.dealerCipherSalt ?? 105)
  };
}

function normalizeActionWitness(witness) {
  const sessionId = Number(witness.sessionId ?? 1);
  const oldPlayerCards = normalizeCards(witness.oldPlayerCards);
  const playerCards = normalizeCards(witness.playerCards);
  const dealerCardsFull = normalizeCards(witness.dealerCards ?? witness.dealerPrivateCards);
  const oldHandCardCounts = normalizeFour(witness.oldHandCardCounts);
  const handCardCounts = normalizeFour(witness.handCardCounts);
  const publicState = normalizePublicState({
    phase: witness.phase,
    decisionType: witness.decisionType,
    dealerRevealMask: witness.dealerRevealMask,
    handCount: witness.handCount,
    activeHandIndex: witness.activeHandIndex,
    peekAvailable: witness.peekAvailable,
    peekResolved: witness.peekResolved,
    dealerHasBlackjack: witness.dealerHasBlackjack,
    insuranceAvailable: witness.insuranceAvailable,
    insuranceStatus: witness.insuranceStatus,
    surrenderAvailable: witness.surrenderAvailable,
    surrenderStatus: witness.surrenderStatus,
    dealerUpValue: witness.dealerUpValue,
    dealerFinalValue: witness.dealerFinalValue,
    payout: witness.payout,
    insuranceStake: witness.insuranceStake,
    insurancePayout: witness.insurancePayout,
    handWagers: witness.handWagers,
    handValues: witness.handValues,
    handStatuses: witness.handStatuses,
    allowedActionMasks: witness.allowedActionMasks,
    handCardCounts,
    handCardStartIndices: witness.handCardStartIndices,
    handPayoutKinds: witness.handPayoutKinds,
    playerCardsVisible: witness.playerCardsVisible ?? playerCards,
    dealerCardsVisible: witness.dealerCardsVisible
  }, {
    baseWager: Number(witness.baseWager ?? 100),
    playerCards,
    dealerCardsFull,
    handCardCounts,
    phaseHint: "action"
  });

  return {
    sessionId,
    proofSequence: Number(witness.proofSequence ?? 3),
    pendingAction: Number(witness.pendingAction ?? ACTION.HIT),
    deckCommitment: witness.deckCommitment ?? "0x03",
    playerKey: normalizePlayerKey(witness.playerKey ?? [11, 29]),
    oldPlayerCards,
    playerCards,
    dealerCardsFull,
    oldHandCardCounts,
    handCardCounts,
    publicState,
    oldPlayerSalt: Number(witness.oldPlayerSalt ?? 201),
    newPlayerSalt: Number(witness.newPlayerSalt ?? 202),
    dealerSalt: Number(witness.dealerSalt ?? 102),
    playerCipherSalt: Number(witness.playerCipherSalt ?? 104),
    dealerCipherSalt: Number(witness.dealerCipherSalt ?? 105)
  };
}

function normalizeShowdownWitness(witness) {
  const sessionId = Number(witness.sessionId ?? 1);
  const playerCards = normalizeCards(witness.playerCards);
  const dealerCardsFull = normalizeCards(witness.dealerCards ?? witness.dealerPrivateCards);
  const handCardCounts = normalizeFour(witness.handCardCounts);
  const publicState = normalizePublicState({
    phase: witness.phase ?? PHASE.COMPLETED,
    decisionType: witness.decisionType,
    dealerRevealMask: witness.dealerRevealMask,
    handCount: witness.handCount,
    activeHandIndex: witness.activeHandIndex,
    peekAvailable: witness.peekAvailable,
    peekResolved: witness.peekResolved,
    dealerHasBlackjack: witness.dealerHasBlackjack,
    insuranceAvailable: witness.insuranceAvailable,
    insuranceStatus: witness.insuranceStatus,
    surrenderAvailable: witness.surrenderAvailable,
    surrenderStatus: witness.surrenderStatus,
    dealerUpValue: witness.dealerUpValue,
    dealerFinalValue: witness.dealerFinalValue,
    payout: witness.payout,
    insuranceStake: witness.insuranceStake,
    insurancePayout: witness.insurancePayout,
    handWagers: witness.handWagers,
    handValues: witness.handValues,
    handStatuses: witness.handStatuses,
    allowedActionMasks: witness.allowedActionMasks,
    handCardCounts,
    handCardStartIndices: witness.handCardStartIndices,
    handPayoutKinds: witness.handPayoutKinds,
    playerCardsVisible: witness.playerCardsVisible ?? playerCards,
    dealerCardsVisible: witness.dealerCardsVisible ?? dealerCardsFull
  }, {
    baseWager: Number(witness.baseWager ?? 100),
    playerCards,
    dealerCardsFull,
    handCardCounts,
    phaseHint: "showdown"
  });

  return {
    sessionId,
    proofSequence: Number(witness.proofSequence ?? 4),
    deckCommitment: witness.deckCommitment ?? "0x04",
    playerKey: normalizePlayerKey(witness.playerKey ?? [11, 29]),
    playerCards,
    dealerCardsFull,
    handCardCounts,
    publicState,
    playerSalt: Number(witness.playerSalt ?? 202),
    dealerSalt: Number(witness.dealerSalt ?? 102)
  };
}

function normalizePublicState(source, context) {
  const playerHands = partitionHands(context.playerCards, source.handCardCounts ?? context.handCardCounts);
  const dealerVisibleDefault = defaultVisibleDealerCards(context.dealerCardsFull, context.phaseHint, source.dealerRevealMask);
  const handValues = normalizeFour(source.handValues ?? playerHands.map((cards) => scoreHand(cards).total));
  const handWagers = normalizeFour(source.handWagers ?? [context.baseWager, 0, 0, 0]);
  const handCardCounts = normalizeFour(source.handCardCounts ?? context.handCardCounts);
  const handCardStartIndices = normalizeFour(source.handCardStartIndices ?? deriveCardStarts(handCardCounts));
  const handStatuses = normalizeFour(source.handStatuses ?? deriveDefaultHandStatuses(playerHands, source.phase ?? defaultPhaseForContext(context)));
  const handPayoutKinds = normalizeFour(source.handPayoutKinds ?? deriveDefaultPayoutKinds(handStatuses));
  const allowedActionMasks = normalizeFour(source.allowedActionMasks ?? deriveDefaultAllowedActionMasks({
    phase: source.phase ?? defaultPhaseForContext(context),
    handCount: source.handCount ?? inferredHandCount(handCardCounts),
    activeHandIndex: source.activeHandIndex ?? 0,
    playerHands,
    handCardCounts
  }));

  const dealerUpValue = Number(source.dealerUpValue ?? cardValue(context.dealerCardsFull[0] ?? CARD_EMPTY));
  const dealerFinalValue = Number(
    source.dealerFinalValue ?? scoreHand(context.dealerCardsFull.filter((card) => card !== CARD_EMPTY)).total
  );
  const phase = Number(source.phase ?? defaultPhaseForContext(context));
  const decisionType = Number(source.decisionType ?? defaultDecisionType(context.dealerCardsFull[0] ?? CARD_EMPTY, phase));
  const peekAvailable = Number(source.peekAvailable ?? (peekEligible(context.dealerCardsFull[0] ?? CARD_EMPTY) ? 1 : 0));
  const dealerHasBlackjack = Number(source.dealerHasBlackjack ?? (isNaturalBlackjack(context.dealerCardsFull.slice(0, 2)) ? 1 : 0));
  const dealerRevealMask = Number(source.dealerRevealMask ?? deriveRevealMask(source.dealerCardsVisible ?? dealerVisibleDefault));
  const handCount = Number(source.handCount ?? inferredHandCount(handCardCounts));
  const playerCardsVisible = normalizeCards(source.playerCardsVisible ?? context.playerCards);
  const dealerCardsVisible = normalizeCards(source.dealerCardsVisible ?? dealerVisibleDefault);

  return {
    phase,
    decisionType,
    dealerRevealMask,
    handCount,
    activeHandIndex: Number(source.activeHandIndex ?? 0),
    peekAvailable,
    peekResolved: Number(source.peekResolved ?? (phase >= PHASE.AWAITING_POSTPEEK_DECISION ? 1 : 0)),
    dealerHasBlackjack,
    insuranceAvailable: Number(source.insuranceAvailable ?? (decisionType === DECISION.INSURANCE && phase === PHASE.AWAITING_PREPLAY_DECISION ? 1 : 0)),
    insuranceStatus: Number(source.insuranceStatus ?? INSURANCE.NONE),
    surrenderAvailable: Number(source.surrenderAvailable ?? (decisionType === DECISION.EARLY_SURRENDER || decisionType === DECISION.LATE_SURRENDER ? 1 : 0)),
    surrenderStatus: Number(source.surrenderStatus ?? SURRENDER.NONE),
    dealerUpValue,
    dealerFinalValue,
    payout: Number(source.payout ?? 0),
    insuranceStake: Number(source.insuranceStake ?? 0),
    insurancePayout: Number(source.insurancePayout ?? 0),
    hands: [0, 1, 2, 3].map((index) => ({
      wager: Number(handWagers[index]),
      value: Number(handValues[index]),
      status: Number(handStatuses[index]),
      allowedActionMask: Number(allowedActionMasks[index]),
      cardCount: Number(handCardCounts[index]),
      cardStartIndex: Number(handCardStartIndices[index]),
      payoutKind: Number(handPayoutKinds[index])
    })),
    playerCards: playerCardsVisible,
    dealerCards: dealerCardsVisible
  };
}

function serializePublicState(publicState) {
  return {
    phase: String(publicState.phase),
    decisionType: String(publicState.decisionType),
    dealerRevealMask: String(publicState.dealerRevealMask),
    handCount: String(publicState.handCount),
    activeHandIndex: String(publicState.activeHandIndex),
    peekAvailable: String(publicState.peekAvailable),
    peekResolved: String(publicState.peekResolved),
    dealerHasBlackjack: String(publicState.dealerHasBlackjack),
    insuranceAvailable: String(publicState.insuranceAvailable),
    insuranceStatus: String(publicState.insuranceStatus),
    surrenderAvailable: String(publicState.surrenderAvailable),
    surrenderStatus: String(publicState.surrenderStatus),
    dealerUpValue: String(publicState.dealerUpValue),
    dealerFinalValue: String(publicState.dealerFinalValue),
    payout: String(publicState.payout),
    insuranceStake: String(publicState.insuranceStake),
    insurancePayout: String(publicState.insurancePayout),
    hands: publicState.hands.map((hand) => ({
      wager: String(hand.wager),
      value: String(hand.value),
      status: String(hand.status),
      allowedActionMask: String(hand.allowedActionMask),
      cardCount: String(hand.cardCount),
      cardStartIndex: String(hand.cardStartIndex),
      payoutKind: String(hand.payoutKind)
    })),
    playerCards: publicState.playerCards.map(String),
    dealerCards: publicState.dealerCards.map(String)
  };
}

function flattenPublicStateInputs(publicState) {
  return {
    phase: String(publicState.phase),
    decisionType: String(publicState.decisionType),
    dealerRevealMask: String(publicState.dealerRevealMask),
    handCount: String(publicState.handCount),
    activeHandIndex: String(publicState.activeHandIndex),
    peekAvailable: String(publicState.peekAvailable),
    peekResolved: String(publicState.peekResolved),
    dealerHasBlackjack: String(publicState.dealerHasBlackjack),
    insuranceAvailable: String(publicState.insuranceAvailable),
    insuranceStatus: String(publicState.insuranceStatus),
    surrenderAvailable: String(publicState.surrenderAvailable),
    surrenderStatus: String(publicState.surrenderStatus),
    dealerUpValue: String(publicState.dealerUpValue),
    dealerFinalValue: String(publicState.dealerFinalValue),
    payout: String(publicState.payout),
    insuranceStake: String(publicState.insuranceStake),
    insurancePayout: String(publicState.insurancePayout),
    handWagers: publicState.hands.map((hand) => String(hand.wager)),
    handValues: publicState.hands.map((hand) => String(hand.value)),
    handStatuses: publicState.hands.map((hand) => String(hand.status)),
    allowedActionMasks: publicState.hands.map((hand) => String(hand.allowedActionMask)),
    handCardCounts: publicState.hands.map((hand) => String(hand.cardCount)),
    handCardStartIndices: publicState.hands.map((hand) => String(hand.cardStartIndex)),
    handPayoutKinds: publicState.hands.map((hand) => String(hand.payoutKind)),
    playerCards: padArray(publicState.playerCards, MAX_PLAYER_CARDS, CARD_EMPTY).map(String),
    dealerCards: padArray(publicState.dealerCards, MAX_DEALER_CARDS, CARD_EMPTY).map(String)
  };
}

function encodeProof(proof) {
  return encodeGroth16Proof(proof);
}

function normalizePlayerKey(values) {
  return values.map((value) => Number(value));
}

function normalizeCards(values) {
  const numeric = (values ?? []).map((value) => Number(value));
  const legacyEmptySentinel = numeric.every((value) => value <= 52);
  return numeric.map((value) => (legacyEmptySentinel && value === 52 ? CARD_EMPTY : value));
}

function normalizeFour(values) {
  const out = [0, 0, 0, 0];
  for (let index = 0; index < Math.min(values?.length ?? 0, 4); index += 1) {
    out[index] = Number(values[index] ?? 0);
  }
  return out;
}

function padArray(values, length, fillValue) {
  const out = values.slice(0, length);
  while (out.length < length) {
    out.push(fillValue);
  }
  return out;
}

function defaultPhaseForContext(context) {
  if (context.phaseHint === "showdown") return PHASE.COMPLETED;
  if (context.phaseHint === "peek") return PHASE.AWAITING_PLAYER_ACTION;
  if (context.phaseHint === "action") return PHASE.AWAITING_PLAYER_ACTION;
  return peekEligible(context.dealerCardsFull[0] ?? CARD_EMPTY) ? PHASE.AWAITING_PREPLAY_DECISION : PHASE.AWAITING_PLAYER_ACTION;
}

function defaultDecisionType(dealerUpCard, phase) {
  if (phase === PHASE.AWAITING_POSTPEEK_DECISION) return DECISION.LATE_SURRENDER;
  if (phase !== PHASE.AWAITING_PREPLAY_DECISION) return DECISION.NONE;
  if (cardMeta(dealerUpCard).isAce) return DECISION.INSURANCE;
  if (cardMeta(dealerUpCard).isTenValue) return DECISION.EARLY_SURRENDER;
  return DECISION.NONE;
}

function inferredHandCount(handCardCounts) {
  return handCardCounts.filter((count) => Number(count) > 0).length || 1;
}

function deriveCardStarts(handCardCounts) {
  const starts = [0, 0, 0, 0];
  let offset = 0;
  for (let index = 0; index < 4; index += 1) {
    starts[index] = offset;
    offset += Number(handCardCounts[index] ?? 0);
  }
  return starts;
}

function deriveDefaultHandStatuses(playerHands, phase) {
  return normalizeFour(playerHands.map((cards, index) => {
    if (cards.length === 0) return HAND_STATUS.NONE;
    const score = scoreHand(cards).total;
    if (phase === PHASE.COMPLETED && isNaturalBlackjack(cards)) return HAND_STATUS.BLACKJACK;
    if (score > 21) return HAND_STATUS.BUST;
    if (phase === PHASE.AWAITING_PLAYER_ACTION && index === 0) return HAND_STATUS.ACTIVE;
    return HAND_STATUS.NONE;
  }));
}

function deriveDefaultPayoutKinds(handStatuses) {
  return normalizeFour(handStatuses.map((status) => {
    if (status === HAND_STATUS.BUST || status === HAND_STATUS.LOSS) return HAND_PAYOUT.LOSS;
    if (status === HAND_STATUS.PUSH) return HAND_PAYOUT.PUSH;
    if (status === HAND_STATUS.WIN) return HAND_PAYOUT.EVEN_MONEY;
    if (status === HAND_STATUS.BLACKJACK) return HAND_PAYOUT.BLACKJACK_3_TO_2;
    if (status === HAND_STATUS.SURRENDERED) return HAND_PAYOUT.SURRENDER;
    return HAND_PAYOUT.NONE;
  }));
}

function deriveDefaultAllowedActionMasks({ phase, handCount, activeHandIndex, playerHands, handCardCounts }) {
  const out = [0, 0, 0, 0];
  if (phase !== PHASE.AWAITING_PLAYER_ACTION) {
    return out;
  }
  const cards = playerHands[Number(activeHandIndex)] ?? [];
  if (!cards.length) {
    return out;
  }
  let mask = ALLOW.HIT + ALLOW.STAND;
  if (Number(handCardCounts[activeHandIndex]) === 2) {
    mask += ALLOW.DOUBLE;
    if (cards.length === 2 && sameRank(cards[0], cards[1]) && handCount < 4) {
      mask += ALLOW.SPLIT;
    }
  }
  out[Number(activeHandIndex)] = mask;
  return out;
}

function defaultVisibleDealerCards(dealerCardsFull, phaseHint, explicitMask) {
  const revealMask = explicitMask !== undefined ? Number(explicitMask) : phaseHint === "showdown" ? deriveRevealMask(dealerCardsFull) : 1;
  return dealerCardsFull.map((card, index) => ((revealMask >> index) & 1 ? card : CARD_EMPTY));
}

function deriveRevealMask(cards) {
  return cards.reduce((mask, card, index) => mask + (Number(card) !== CARD_EMPTY ? 1 << index : 0), 0);
}

function peekEligible(card) {
  const meta = cardMeta(card);
  return meta.isAce || meta.isTenValue;
}

function hash(values) {
  const inputs = values.map((value) => BigInt(normalizeHexish(value)));

  switch (inputs.length) {
    case 13:
      return normalize(poseidonChain13(inputs));
    case 14:
      return normalize(poseidonChain14(inputs));
    case 15:
      return normalize(poseidonChain15(inputs));
    case 38:
      return normalize(poseidonChain38(inputs));
    case 47:
      return normalize(poseidonChain47(inputs));
    default:
      if (inputs.length < 1 || inputs.length > 16) {
        throw new Error(`unsupported poseidon arity: ${inputs.length}`);
      }
      return normalize(poseidonRaw(inputs));
  }
}

function poseidonRaw(values) {
  return FIELD.toObject(poseidon(values));
}

function poseidonChain13(inputs) {
  const first = poseidonRaw(inputs.slice(0, 6));
  const second = poseidonRaw([first, ...inputs.slice(6, 11)]);
  return poseidonRaw([second, inputs[11], inputs[12]]);
}

function poseidonChain14(inputs) {
  const first = poseidonRaw(inputs.slice(0, 6));
  const second = poseidonRaw([first, ...inputs.slice(6, 11)]);
  return poseidonRaw([second, inputs[11], inputs[12], inputs[13]]);
}

function poseidonChain15(inputs) {
  const first = poseidonRaw(inputs.slice(0, 6));
  const second = poseidonRaw([first, ...inputs.slice(6, 11)]);
  return poseidonRaw([second, inputs[11], inputs[12], inputs[13], inputs[14]]);
}

function poseidonChain38(inputs) {
  const h0 = poseidonRaw(inputs.slice(0, 6));
  const h1 = poseidonRaw([h0, ...inputs.slice(6, 11)]);
  const h2 = poseidonRaw([h1, ...inputs.slice(11, 16)]);
  const h3 = poseidonRaw([h2, ...inputs.slice(16, 21)]);
  const h4 = poseidonRaw([h3, ...inputs.slice(21, 26)]);
  const h5 = poseidonRaw([h4, ...inputs.slice(26, 31)]);
  const h6 = poseidonRaw([h5, inputs[31], inputs[32]]);
  return poseidonRaw([h6, ...inputs.slice(33, 38)]);
}

function poseidonChain47(inputs) {
  const h0 = poseidonRaw(inputs.slice(0, 6));
  const h1 = poseidonRaw([h0, ...inputs.slice(6, 11)]);
  const h2 = poseidonRaw([h1, ...inputs.slice(11, 16)]);
  const h3 = poseidonRaw([h2, ...inputs.slice(16, 21)]);
  const h4 = poseidonRaw([h3, ...inputs.slice(21, 26)]);
  const h5 = poseidonRaw([h4, ...inputs.slice(26, 31)]);
  const h6 = poseidonRaw([h5, ...inputs.slice(31, 36)]);
  const h7 = poseidonRaw([h6, ...inputs.slice(36, 41)]);
  const h8 = poseidonRaw([h7, ...inputs.slice(41, 46)]);
  return poseidonRaw([h8, inputs[46]]);
}

function normalize(value) {
  return BigInt(value).toString();
}

function normalizeHexish(value) {
  if (typeof value === "string" && value.startsWith("0x")) {
    return BigInt(value);
  }
  return BigInt(value);
}

function formatBytes32(value) {
  if (typeof value === "string" && value.startsWith("0x")) {
    return value;
  }
  return `0x${BigInt(value).toString(16).padStart(64, "0")}`;
}

function cardMeta(card) {
  const numeric = Number(card);
  if (numeric === CARD_EMPTY) {
    return { real: false, rank: CARD_EMPTY, suit: -1, value: 0, isAce: false, isTenValue: false };
  }

  const rank = numeric % 13;
  const suit = Math.floor((numeric % 52) / 13);
  const isAce = rank === 0;
  const isTenValue = rank >= 9;
  const value = isAce ? 11 : isTenValue ? 10 : rank + 1;
  return { real: true, rank, suit, value, isAce, isTenValue };
}

function cardValue(card) {
  return cardMeta(card).value;
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
    hands.push(cards.slice(offset, offset + count).filter((card) => card !== CARD_EMPTY));
    offset += count;
  }
  return hands;
}
