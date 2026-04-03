pragma circom 2.1.6;

include "circomlib/circuits/poseidon.circom";
include "./blackjack_utils.circom";

template BlackjackInitialDeal() {
    signal input sessionId;
    signal input handNonce;
    signal input deckCommitment;
    signal input playerStateCommitment;
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

    signal input privatePlayerCards[32];
    signal input privateDealerCards[12];
    signal input playerSalt;
    signal input dealerSalt;
    signal input deckSalt;
    signal input playerCipherSalt;
    signal input dealerCipherSalt;
    signal input playerKey[2];

    signal playerHashInputs[38];
    signal dealerHashInputs[14];
    signal deckHashInputs[47];
    signal playerCipherInputs[15];
    signal dealerCipherInputs[15];

    component playerHash = PoseidonChain38();
    component dealerHash = PoseidonChain14();
    component deckHash = PoseidonChain47();
    component playerCipherHash = PoseidonChain15();
    component dealerCipherHash = PoseidonChain15();
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
    for (var k = 0; k < 38; k++) {
        playerHash.inputs[k] <== playerHashInputs[k];
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

    playerCipherInputs[0] <== sessionId;
    playerCipherInputs[1] <== handNonce;
    for (var playerCipherIndex = 0; playerCipherIndex < 12; playerCipherIndex++) {
        playerCipherInputs[playerCipherIndex + 2] <== privatePlayerCards[playerCipherIndex];
        dealerCipherInputs[playerCipherIndex + 2] <== privateDealerCards[playerCipherIndex];
    }
    playerCipherInputs[14] <== playerCipherSalt;
    dealerCipherInputs[0] <== sessionId;
    dealerCipherInputs[1] <== handNonce;
    dealerCipherInputs[14] <== dealerCipherSalt;
    for (var pc = 0; pc < 15; pc++) {
        playerCipherHash.inputs[pc] <== playerCipherInputs[pc];
        dealerCipherHash.inputs[pc] <== dealerCipherInputs[pc];
    }
    playerCiphertextRef === playerCipherHash.out;
    dealerCiphertextRef === dealerCipherHash.out;

    deckHashInputs[0] <== sessionId;
    deckHashInputs[1] <== handNonce;
    for (var deckPlayer = 0; deckPlayer < 32; deckPlayer++) {
        deckHashInputs[deckPlayer + 2] <== privatePlayerCards[deckPlayer];
    }
    for (var deckDealer = 0; deckDealer < 12; deckDealer++) {
        deckHashInputs[deckDealer + 34] <== privateDealerCards[deckDealer];
    }
    deckHashInputs[46] <== deckSalt;
    for (var deckIndex = 0; deckIndex < 47; deckIndex++) {
        deckHash.inputs[deckIndex] <== deckHashInputs[deckIndex];
    }
    deckCommitment === deckHash.out;
}

component main {public [
    sessionId,
    handNonce,
    deckCommitment,
    playerStateCommitment,
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
]} = BlackjackInitialDeal();
