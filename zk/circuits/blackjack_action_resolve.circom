pragma circom 2.1.6;

include "circomlib/circuits/poseidon.circom";
include "./blackjack_utils.circom";

template BlackjackActionResolve() {
    signal input sessionId;
    signal input proofSequence;
    signal input pendingAction;
    signal input deckCommitment;
    signal input oldPlayerStateCommitment;
    signal input newPlayerStateCommitment;
    signal input dealerStateCommitment;
    signal input playerKeyCommitment;
    signal input playerCiphertextRef;
    signal input dealerCiphertextRef;
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

    signal input privateOldPlayerCards[32];
    signal input privatePlayerCards[32];
    signal input privateDealerCards[12];
    signal input oldHandCardCounts[4];
    signal input oldPlayerSalt;
    signal input newPlayerSalt;
    signal input dealerSalt;
    signal input playerCipherSalt;
    signal input dealerCipherSalt;
    signal input playerKey[2];

    signal oldPlayerHashInputs[38];
    signal newPlayerHashInputs[38];
    signal dealerHashInputs[14];
    signal playerCipherInputs[14];
    signal dealerCipherInputs[15];

    component oldPlayerHash = PoseidonChain38();
    component newPlayerHash = PoseidonChain38();
    component dealerHash = PoseidonChain14();
    component playerCipherHash = PoseidonChain14();
    component dealerCipherHash = PoseidonChain15();
    component keyHash = Poseidon(3);
    component dealerMatches[12];

    oldPlayerHashInputs[0] <== sessionId;
    newPlayerHashInputs[0] <== sessionId;
    for (var i = 0; i < 32; i++) {
        oldPlayerHashInputs[i + 1] <== privateOldPlayerCards[i];
        newPlayerHashInputs[i + 1] <== privatePlayerCards[i];
        playerCards[i] === privatePlayerCards[i];
    }
    for (var j = 0; j < 4; j++) {
        oldPlayerHashInputs[j + 33] <== oldHandCardCounts[j];
        newPlayerHashInputs[j + 33] <== handCardCounts[j];
    }
    oldPlayerHashInputs[37] <== oldPlayerSalt;
    newPlayerHashInputs[37] <== newPlayerSalt;
    for (var hashIndex = 0; hashIndex < 38; hashIndex++) {
        oldPlayerHash.inputs[hashIndex] <== oldPlayerHashInputs[hashIndex];
        newPlayerHash.inputs[hashIndex] <== newPlayerHashInputs[hashIndex];
    }
    oldPlayerStateCommitment === oldPlayerHash.out;
    newPlayerStateCommitment === newPlayerHash.out;

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

    playerCipherInputs[0] <== sessionId;
    playerCipherInputs[1] <== proofSequence;
    playerCipherInputs[2] <== pendingAction;
    for (var playerCipherIndex = 0; playerCipherIndex < 10; playerCipherIndex++) {
        playerCipherInputs[playerCipherIndex + 3] <== privatePlayerCards[playerCipherIndex];
    }
    playerCipherInputs[13] <== playerCipherSalt;
    for (var pci = 0; pci < 14; pci++) {
        playerCipherHash.inputs[pci] <== playerCipherInputs[pci];
    }
    playerCiphertextRef === playerCipherHash.out;

    dealerCipherInputs[0] <== sessionId;
    dealerCipherInputs[1] <== proofSequence;
    for (var dealerCipherIndex = 0; dealerCipherIndex < 12; dealerCipherIndex++) {
        dealerCipherInputs[dealerCipherIndex + 2] <== privateDealerCards[dealerCipherIndex];
    }
    dealerCipherInputs[14] <== dealerCipherSalt;
    for (var dci = 0; dci < 15; dci++) {
        dealerCipherHash.inputs[dci] <== dealerCipherInputs[dci];
    }
    dealerCiphertextRef === dealerCipherHash.out;
}

component main {public [
    sessionId,
    proofSequence,
    pendingAction,
    deckCommitment,
    oldPlayerStateCommitment,
    newPlayerStateCommitment,
    dealerStateCommitment,
    playerKeyCommitment,
    playerCiphertextRef,
    dealerCiphertextRef,
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
]} = BlackjackActionResolve();
