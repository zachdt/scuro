pragma circom 2.1.6;

include "circomlib/circuits/poseidon.circom";
include "./blackjack_utils.circom";

template BlackjackShowdown() {
    signal input sessionId;
    signal input proofSequence;
    signal input deckCommitment;
    signal input playerStateCommitment;
    signal input dealerStateCommitment;
    signal input playerKeyCommitment;
    signal input phase;
    signal input decisionType;
    signal input dealerUpValue;
    signal input dealerFinalValue;
    signal input payout;
    signal input insuranceStake;
    signal input insurancePayout;
    signal input dealerRevealMask;
    signal input handCount;
    signal input activeHandIndex;
    signal input peekAvailable;
    signal input peekResolved;
    signal input dealerHasBlackjack;
    signal input insuranceAvailable;
    signal input insuranceStatus;
    signal input surrenderAvailable;
    signal input surrenderStatus;
    signal input handWagers[4];
    signal input handValues[4];
    signal input handStatuses[4];
    signal input allowedActionMasks[4];
    signal input handCardCounts[4];
    signal input handCardStartIndices[4];
    signal input handPayoutKinds[4];
    signal input playerCards[32];
    signal input dealerCards[12];

    signal input privatePlayerCards[32];
    signal input privateDealerCards[12];
    signal input playerSalt;
    signal input dealerSalt;
    signal input playerKey[2];

    signal playerHashInputs[38];
    signal dealerHashInputs[14];

    component playerHash = PoseidonChain38();
    component dealerHash = PoseidonChain14();
    component keyHash = Poseidon(3);
    component dealerMatches[12];

    playerHashInputs[0] <== sessionId;
    for (var i = 0; i < 32; i++) {
        playerHashInputs[i + 1] <== privatePlayerCards[i];
        playerCards[i] === privatePlayerCards[i];
    }
    for (var j = 0; j < 4; j++) {
        playerHashInputs[j + 33] <== handCardCounts[j];
    }
    playerHashInputs[37] <== playerSalt;
    for (var playerIndex = 0; playerIndex < 38; playerIndex++) {
        playerHash.inputs[playerIndex] <== playerHashInputs[playerIndex];
    }
    playerStateCommitment === playerHash.out;

    dealerHashInputs[0] <== sessionId;
    for (var dealerIndex = 0; dealerIndex < 12; dealerIndex++) {
        dealerHashInputs[dealerIndex + 1] <== privateDealerCards[dealerIndex];
        dealerMatches[dealerIndex] = PublicDealerCard();
        dealerMatches[dealerIndex].visible <== dealerCards[dealerIndex];
        dealerMatches[dealerIndex].hidden <== privateDealerCards[dealerIndex];
    }
    dealerHashInputs[13] <== dealerSalt;
    for (var dealerHashIndex = 0; dealerHashIndex < 14; dealerHashIndex++) {
        dealerHash.inputs[dealerHashIndex] <== dealerHashInputs[dealerHashIndex];
    }
    dealerStateCommitment === dealerHash.out;

    keyHash.inputs[0] <== sessionId;
    keyHash.inputs[1] <== playerKey[0];
    keyHash.inputs[2] <== playerKey[1];
    playerKeyCommitment === keyHash.out;
}

component main {public [
    sessionId,
    proofSequence,
    deckCommitment,
    playerStateCommitment,
    dealerStateCommitment,
    playerKeyCommitment,
    phase,
    decisionType,
    dealerUpValue,
    dealerFinalValue,
    payout,
    insuranceStake,
    insurancePayout,
    dealerRevealMask,
    handCount,
    activeHandIndex,
    peekAvailable,
    peekResolved,
    dealerHasBlackjack,
    insuranceAvailable,
    insuranceStatus,
    surrenderAvailable,
    surrenderStatus,
    handWagers,
    handValues,
    handStatuses,
    allowedActionMasks,
    handCardCounts,
    handCardStartIndices,
    handPayoutKinds,
    playerCards,
    dealerCards
]} = BlackjackShowdown();
