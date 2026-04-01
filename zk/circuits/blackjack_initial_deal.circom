pragma circom 2.1.6;

include "circomlib/circuits/comparators.circom";
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
    signal input dealerUpValue;
    signal input baseWager;
    signal input handCount;
    signal input activeHandIndex;
    signal input payout;
    signal input immediateResultCode;
    signal input handValues[4];
    signal input softMask;
    signal input handStatuses[4];
    signal input allowedActionMasks[4];
    signal input handCardCounts[4];
    signal input handPayoutKinds[4];
    signal input playerCards[8];
    signal input dealerCards[4];
    signal input dealerRevealMask;

    signal input dealerPrivateCards[4];
    signal input playerSalt;
    signal input dealerSalt;
    signal input deckSalt;
    signal input playerKey[2];
    signal input playerCipherSalt;
    signal input dealerCipherSalt;

    component playerMeta[8];
    for (var i = 0; i < 8; i++) {
        playerMeta[i] = BlackjackCardMeta();
        playerMeta[i].card <== playerCards[i];
    }

    component dealerMeta[4];
    for (var j = 0; j < 4; j++) {
        dealerMeta[j] = BlackjackCardMeta();
        dealerMeta[j].card <== dealerPrivateCards[j];
    }

    handCount === 1;
    activeHandIndex === 0;

    handCardCounts[0] === 2;
    handCardCounts[1] === 0;
    handCardCounts[2] === 0;
    handCardCounts[3] === 0;

    for (var k = 2; k < 8; k++) {
        playerCards[k] === 52;
    }
    dealerPrivateCards[2] === 52;
    dealerPrivateCards[3] === 52;

    playerMeta[0].isReal === 1;
    playerMeta[1].isReal === 1;
    dealerMeta[0].isReal === 1;
    dealerMeta[1].isReal === 1;

    signal duplicatePlayer;
    component eqPlayer = IsEqual();
    eqPlayer.in[0] <== playerCards[0];
    eqPlayer.in[1] <== playerCards[1];
    duplicatePlayer <== eqPlayer.out;
    duplicatePlayer === 0;

    component eqPD0 = IsEqual();
    eqPD0.in[0] <== playerCards[0];
    eqPD0.in[1] <== dealerPrivateCards[0];
    eqPD0.out === 0;

    component eqPD1 = IsEqual();
    eqPD1.in[0] <== playerCards[0];
    eqPD1.in[1] <== dealerPrivateCards[1];
    eqPD1.out === 0;

    component eqPD2 = IsEqual();
    eqPD2.in[0] <== playerCards[1];
    eqPD2.in[1] <== dealerPrivateCards[0];
    eqPD2.out === 0;

    component eqPD3 = IsEqual();
    eqPD3.in[0] <== playerCards[1];
    eqPD3.in[1] <== dealerPrivateCards[1];
    eqPD3.out === 0;

    component eqDealer = IsEqual();
    eqDealer.in[0] <== dealerPrivateCards[0];
    eqDealer.in[1] <== dealerPrivateCards[1];
    eqDealer.out === 0;

    signal playerRawTotal;
    signal playerAceCount;
    signal playerValueAdjusted[5];
    signal playerAcesRemaining[5];
    signal playerReduce[4];
    signal playerValue;
    signal playerSoft;
    component playerGt21[4];
    component playerAcesZero[4];

    playerRawTotal <== playerMeta[0].value + playerMeta[1].value;
    playerAceCount <== playerMeta[0].isAce + playerMeta[1].isAce;
    playerValueAdjusted[0] <== playerRawTotal;
    playerAcesRemaining[0] <== playerAceCount;

    for (var step = 0; step < 4; step++) {
        playerGt21[step] = LessThan(7);
        playerGt21[step].in[0] <== 21;
        playerGt21[step].in[1] <== playerValueAdjusted[step];

        playerAcesZero[step] = IsZero();
        playerAcesZero[step].in <== playerAcesRemaining[step];

        playerReduce[step] <== playerGt21[step].out * (1 - playerAcesZero[step].out);

        playerValueAdjusted[step + 1] <== playerValueAdjusted[step] - 10 * playerReduce[step];
        playerAcesRemaining[step + 1] <== playerAcesRemaining[step] - playerReduce[step];
    }

    playerValue <== playerValueAdjusted[4];
    component playerSoftZero = IsZero();
    playerSoftZero.in <== playerAcesRemaining[4];
    playerSoft <== 1 - playerSoftZero.out;

    signal dealerRawTotal;
    signal dealerAceCount;
    signal dealerValueAdjusted[5];
    signal dealerAcesRemaining[5];
    signal dealerReduce[4];
    signal dealerValue;
    component dealerGt21Step[4];
    component dealerAcesZeroStep[4];

    dealerRawTotal <== dealerMeta[0].value + dealerMeta[1].value;
    dealerAceCount <== dealerMeta[0].isAce + dealerMeta[1].isAce;
    dealerValueAdjusted[0] <== dealerRawTotal;
    dealerAcesRemaining[0] <== dealerAceCount;

    for (var dealerStep = 0; dealerStep < 4; dealerStep++) {
        dealerGt21Step[dealerStep] = LessThan(7);
        dealerGt21Step[dealerStep].in[0] <== 21;
        dealerGt21Step[dealerStep].in[1] <== dealerValueAdjusted[dealerStep];

        dealerAcesZeroStep[dealerStep] = IsZero();
        dealerAcesZeroStep[dealerStep].in <== dealerAcesRemaining[dealerStep];

        dealerReduce[dealerStep] <== dealerGt21Step[dealerStep].out * (1 - dealerAcesZeroStep[dealerStep].out);

        dealerValueAdjusted[dealerStep + 1] <== dealerValueAdjusted[dealerStep] - 10 * dealerReduce[dealerStep];
        dealerAcesRemaining[dealerStep + 1] <== dealerAcesRemaining[dealerStep] - dealerReduce[dealerStep];
    }

    dealerValue <== dealerValueAdjusted[4];

    signal playerNatural;
    signal dealerNatural;
    signal sameSuit;
    signal sameRank;
    signal splitEligible;
    signal noNaturals;
    signal playerAceTen0;
    signal playerAceTen1;
    signal dealerAceTen0;
    signal dealerAceTen1;
    signal suitMatches[4];

    playerAceTen0 <== playerMeta[0].isAce * playerMeta[1].isTenValue;
    playerAceTen1 <== playerMeta[1].isAce * playerMeta[0].isTenValue;
    playerNatural <== playerAceTen0 + playerAceTen1;

    dealerAceTen0 <== dealerMeta[0].isAce * dealerMeta[1].isTenValue;
    dealerAceTen1 <== dealerMeta[1].isAce * dealerMeta[0].isTenValue;
    dealerNatural <== dealerAceTen0 + dealerAceTen1;

    for (var suit = 0; suit < 4; suit++) {
        suitMatches[suit] <== playerMeta[0].suitFlags[suit] * playerMeta[1].suitFlags[suit];
    }
    sameSuit <== suitMatches[0] + suitMatches[1] + suitMatches[2] + suitMatches[3];

    component eqRank = IsEqual();
    eqRank.in[0] <== playerMeta[0].rank;
    eqRank.in[1] <== playerMeta[1].rank;
    sameRank <== eqRank.out;
    noNaturals <== (1 - playerNatural) * (1 - dealerNatural);
    splitEligible <== sameRank * noNaturals;

    signal pushNatural;
    signal playerOnlyNatural;
    signal dealerOnlyNatural;
    signal suitedNatural;
    signal unsuitedNatural;
    signal expectedPayoutTwice;
    signal expectedImmediateResultCode;
    signal expectedStatus;
    signal expectedPayoutKind;
    signal expectedAllowedMask;
    signal expectedRevealMask;
    signal immediateReveal;
    signal pushPayoutTwice;
    signal suitedPayoutTwice;
    signal unsuitedPayoutTwice;

    pushNatural <== playerNatural * dealerNatural;
    playerOnlyNatural <== playerNatural * (1 - dealerNatural);
    dealerOnlyNatural <== dealerNatural * (1 - playerNatural);
    suitedNatural <== playerOnlyNatural * sameSuit;
    unsuitedNatural <== playerOnlyNatural * (1 - sameSuit);

    pushPayoutTwice <== pushNatural * (2 * baseWager);
    suitedPayoutTwice <== suitedNatural * (6 * baseWager);
    unsuitedPayoutTwice <== unsuitedNatural * (5 * baseWager);
    expectedPayoutTwice <== pushPayoutTwice + suitedPayoutTwice + unsuitedPayoutTwice;

    expectedImmediateResultCode <== dealerOnlyNatural * 1 + playerOnlyNatural * 2 + pushNatural * 3;
    expectedStatus <== dealerOnlyNatural * 5 + playerOnlyNatural * 4 + pushNatural * 3;
    expectedPayoutKind <== dealerOnlyNatural * 1 + pushNatural * 2 + unsuitedNatural * 4 + suitedNatural * 5;
    expectedAllowedMask <== 7 * noNaturals + 8 * splitEligible;
    immediateReveal <== pushNatural + playerOnlyNatural + dealerOnlyNatural;
    expectedRevealMask <== 1 + 2 * immediateReveal;

    2 * payout === expectedPayoutTwice;
    immediateResultCode === expectedImmediateResultCode;
    handValues[0] === playerValue;
    handValues[1] === 0;
    handValues[2] === 0;
    handValues[3] === 0;
    softMask === playerSoft;
    handStatuses[0] === expectedStatus;
    handStatuses[1] === 0;
    handStatuses[2] === 0;
    handStatuses[3] === 0;
    allowedActionMasks[0] === expectedAllowedMask;
    allowedActionMasks[1] === 0;
    allowedActionMasks[2] === 0;
    allowedActionMasks[3] === 0;
    handPayoutKinds[0] === expectedPayoutKind;
    handPayoutKinds[1] === 0;
    handPayoutKinds[2] === 0;
    handPayoutKinds[3] === 0;

    dealerRevealMask === expectedRevealMask;
    dealerCards[0] === dealerPrivateCards[0];
    dealerCards[1] === immediateReveal * dealerPrivateCards[1] + (1 - immediateReveal) * 52;
    dealerCards[2] === 52;
    dealerCards[3] === 52;

    dealerUpValue === dealerMeta[0].value;

    component playerHash = Poseidon(14);
    playerHash.inputs[0] <== sessionId;
    for (var p = 0; p < 8; p++) {
        playerHash.inputs[1 + p] <== playerCards[p];
    }
    for (var q = 0; q < 4; q++) {
        playerHash.inputs[9 + q] <== handCardCounts[q];
    }
    playerHash.inputs[13] <== playerSalt;
    playerHash.out === playerStateCommitment;

    component dealerHash = Poseidon(6);
    dealerHash.inputs[0] <== sessionId;
    for (var r = 0; r < 4; r++) {
        dealerHash.inputs[1 + r] <== dealerPrivateCards[r];
    }
    dealerHash.inputs[5] <== dealerSalt;
    dealerHash.out === dealerStateCommitment;

    component playerKeyHash = Poseidon(3);
    playerKeyHash.inputs[0] <== sessionId;
    playerKeyHash.inputs[1] <== playerKey[0];
    playerKeyHash.inputs[2] <== playerKey[1];
    playerKeyHash.out === playerKeyCommitment;

    component playerSummaryHash = PoseidonChain29();
    playerSummaryHash.inputs[0] <== handValues[0];
    playerSummaryHash.inputs[1] <== handValues[1];
    playerSummaryHash.inputs[2] <== handValues[2];
    playerSummaryHash.inputs[3] <== handValues[3];
    playerSummaryHash.inputs[4] <== softMask;
    playerSummaryHash.inputs[5] <== handStatuses[0];
    playerSummaryHash.inputs[6] <== handStatuses[1];
    playerSummaryHash.inputs[7] <== handStatuses[2];
    playerSummaryHash.inputs[8] <== handStatuses[3];
    playerSummaryHash.inputs[9] <== allowedActionMasks[0];
    playerSummaryHash.inputs[10] <== allowedActionMasks[1];
    playerSummaryHash.inputs[11] <== allowedActionMasks[2];
    playerSummaryHash.inputs[12] <== allowedActionMasks[3];
    playerSummaryHash.inputs[13] <== handCardCounts[0];
    playerSummaryHash.inputs[14] <== handCardCounts[1];
    playerSummaryHash.inputs[15] <== handCardCounts[2];
    playerSummaryHash.inputs[16] <== handCardCounts[3];
    playerSummaryHash.inputs[17] <== handPayoutKinds[0];
    playerSummaryHash.inputs[18] <== handPayoutKinds[1];
    playerSummaryHash.inputs[19] <== handPayoutKinds[2];
    playerSummaryHash.inputs[20] <== handPayoutKinds[3];
    playerSummaryHash.inputs[21] <== playerCards[0];
    playerSummaryHash.inputs[22] <== playerCards[1];
    playerSummaryHash.inputs[23] <== playerCards[2];
    playerSummaryHash.inputs[24] <== playerCards[3];
    playerSummaryHash.inputs[25] <== playerCards[4];
    playerSummaryHash.inputs[26] <== playerCards[5];
    playerSummaryHash.inputs[27] <== playerCards[6];
    playerSummaryHash.inputs[28] <== playerCards[7];

    component playerCipherHash = PoseidonChain18();
    playerCipherHash.inputs[0] <== sessionId;
    playerCipherHash.inputs[1] <== handNonce;
    for (var s = 0; s < 8; s++) {
        playerCipherHash.inputs[2 + s] <== playerCards[s];
    }
    playerCipherHash.inputs[10] <== handCardCounts[0];
    playerCipherHash.inputs[11] <== handCardCounts[1];
    playerCipherHash.inputs[12] <== handCardCounts[2];
    playerCipherHash.inputs[13] <== handCardCounts[3];
    playerCipherHash.inputs[14] <== playerSummaryHash.out;
    playerCipherHash.inputs[15] <== playerKey[0];
    playerCipherHash.inputs[16] <== playerKey[1];
    playerCipherHash.inputs[17] <== playerCipherSalt;
    playerCipherHash.out === playerCiphertextRef;

    component dealerCipherHash = Poseidon(12);
    dealerCipherHash.inputs[0] <== sessionId;
    dealerCipherHash.inputs[1] <== handNonce;
    dealerCipherHash.inputs[2] <== dealerPrivateCards[0];
    dealerCipherHash.inputs[3] <== dealerPrivateCards[1];
    dealerCipherHash.inputs[4] <== dealerPrivateCards[2];
    dealerCipherHash.inputs[5] <== dealerPrivateCards[3];
    dealerCipherHash.inputs[6] <== dealerUpValue;
    dealerCipherHash.inputs[7] <== handCount;
    dealerCipherHash.inputs[8] <== payout;
    dealerCipherHash.inputs[9] <== immediateResultCode;
    dealerCipherHash.inputs[10] <== dealerRevealMask;
    dealerCipherHash.inputs[11] <== dealerCipherSalt;
    dealerCipherHash.out === dealerCiphertextRef;

    component deckHash = Poseidon(15);
    deckHash.inputs[0] <== sessionId;
    deckHash.inputs[1] <== handNonce;
    for (var t = 0; t < 8; t++) {
        deckHash.inputs[2 + t] <== playerCards[t];
    }
    for (var u = 0; u < 4; u++) {
        deckHash.inputs[10 + u] <== dealerPrivateCards[u];
    }
    deckHash.inputs[14] <== deckSalt;
    deckHash.out === deckCommitment;
}

component main {public [sessionId, handNonce, deckCommitment, playerStateCommitment, dealerStateCommitment, playerKeyCommitment, playerCiphertextRef, dealerCiphertextRef, dealerUpValue, baseWager, handCount, activeHandIndex, payout, immediateResultCode, handValues, softMask, handStatuses, allowedActionMasks, handCardCounts, handPayoutKinds, playerCards, dealerCards, dealerRevealMask]} = BlackjackInitialDeal();
