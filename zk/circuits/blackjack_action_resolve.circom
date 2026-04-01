pragma circom 2.1.6;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";
include "./blackjack_utils.circom";

template BlackjackActionResolve() {
    signal input sessionId;
    signal input proofSequence;
    signal input pendingAction;
    signal input oldPlayerStateCommitment;
    signal input newPlayerStateCommitment;
    signal input dealerStateCommitment;
    signal input playerKeyCommitment;
    signal input playerCiphertextRef;
    signal input dealerCiphertextRef;
    signal input dealerUpValue;
    signal input handCount;
    signal input activeHandIndex;
    signal input nextPhase;
    signal input handValues[4];
    signal input softMask;
    signal input handStatuses[4];
    signal input allowedActionMasks[4];
    signal input handCardCounts[4];
    signal input handPayoutKinds[4];
    signal input playerCards[8];
    signal input dealerCards[4];
    signal input dealerRevealMask;

    signal input oldPlayerCards[8];
    signal input oldHandCardCounts[4];
    signal input dealerPrivateCards[4];
    signal input oldPlayerSalt;
    signal input newPlayerSalt;
    signal input dealerSalt;
    signal input playerKey[2];
    signal input playerCipherSalt;
    signal input dealerCipherSalt;

    component awaitingPlayerAction = IsEqual();
    awaitingPlayerAction.in[0] <== nextPhase;
    awaitingPlayerAction.in[1] <== 2;

    component activeEq[4];
    component handCountLt[4];
    component handCountZero[4];
    component playerLtTotal[8];
    component oldPlayerLtTotal[8];
    component eqCard0Selector[8];
    component eqCard1Selector[8];
    component handGt21[4];
    component handCountTwo[4];

    signal prefix[5];
    signal totalPlayerCards;
    signal activeStart;
    signal activeStartPlusOne;
    signal activeCard0;
    signal activeCard1;
    signal activeRank0;
    signal activeRank1;
    signal activeCard0Running[9];
    signal activeCard1Running[9];
    signal activeRank0Running[9];
    signal activeRank1Running[9];
    signal activeCount;
    signal activeSameRank;
    signal splitEligible;
    signal activeTwoSameRank;
    signal activeStartTerms[4];
    signal activeCountTerms[4];

    prefix[0] <== 0;
    prefix[1] <== handCardCounts[0];
    prefix[2] <== handCardCounts[0] + handCardCounts[1];
    prefix[3] <== handCardCounts[0] + handCardCounts[1] + handCardCounts[2];
    prefix[4] <== handCardCounts[0] + handCardCounts[1] + handCardCounts[2] + handCardCounts[3];
    totalPlayerCards <== prefix[4];

    component totalPlayerCardsLt9 = LessThan(5);
    totalPlayerCardsLt9.in[0] <== totalPlayerCards;
    totalPlayerCardsLt9.in[1] <== 9;
    totalPlayerCardsLt9.out === 1;

    component handCountLt5 = LessThan(4);
    handCountLt5.in[0] <== handCount;
    handCountLt5.in[1] <== 5;
    handCountLt5.out === 1;

    component handCountZeroAll = IsZero();
    handCountZeroAll.in <== handCount;
    handCountZeroAll.out === 0;

    component playerMeta[8];
    component oldPlayerMeta[8];
    for (var i = 0; i < 8; i++) {
        playerMeta[i] = BlackjackCardMeta();
        playerMeta[i].card <== playerCards[i];

        oldPlayerMeta[i] = BlackjackCardMeta();
        oldPlayerMeta[i].card <== oldPlayerCards[i];

        playerLtTotal[i] = LessThan(5);
        playerLtTotal[i].in[0] <== i;
        playerLtTotal[i].in[1] <== totalPlayerCards;
        playerMeta[i].isReal === playerLtTotal[i].out;
    }

    signal oldTotalPlayerCards;
    oldTotalPlayerCards <== oldHandCardCounts[0] + oldHandCardCounts[1] + oldHandCardCounts[2] + oldHandCardCounts[3];

    component oldTotalPlayerCardsLt9 = LessThan(5);
    oldTotalPlayerCardsLt9.in[0] <== oldTotalPlayerCards;
    oldTotalPlayerCardsLt9.in[1] <== 9;
    oldTotalPlayerCardsLt9.out === 1;

    for (var oldIndex = 0; oldIndex < 8; oldIndex++) {
        oldPlayerLtTotal[oldIndex] = LessThan(5);
        oldPlayerLtTotal[oldIndex].in[0] <== oldIndex;
        oldPlayerLtTotal[oldIndex].in[1] <== oldTotalPlayerCards;
        oldPlayerMeta[oldIndex].isReal === oldPlayerLtTotal[oldIndex].out;
    }

    component dealerMeta[4];
    for (var dealerIndex = 0; dealerIndex < 4; dealerIndex++) {
        dealerMeta[dealerIndex] = BlackjackCardMeta();
        dealerMeta[dealerIndex].card <== dealerPrivateCards[dealerIndex];
    }
    dealerMeta[0].isReal === 1;
    dealerMeta[1].isReal === 1;
    dealerPrivateCards[2] === 52;
    dealerPrivateCards[3] === 52;
    dealerRevealMask === 1;
    dealerCards[0] === dealerPrivateCards[0];
    dealerCards[1] === 52;
    dealerCards[2] === 52;
    dealerCards[3] === 52;
    dealerUpValue === dealerMeta[0].value;

    for (var hand = 0; hand < 4; hand++) {
        activeEq[hand] = IsEqual();
        activeEq[hand].in[0] <== activeHandIndex;
        activeEq[hand].in[1] <== hand;

        handCountLt[hand] = LessThan(4);
        handCountLt[hand].in[0] <== hand;
        handCountLt[hand].in[1] <== handCount;

        handCountZero[hand] = IsZero();
        handCountZero[hand].in <== handCardCounts[hand];

        handCountLt[hand].out * handCountZero[hand].out === 0;
        (1 - handCountLt[hand].out) * handCardCounts[hand] === 0;
    }

    component activeIndexLt = LessThan(4);
    activeIndexLt.in[0] <== activeHandIndex;
    activeIndexLt.in[1] <== handCount;
    activeIndexLt.out === 1;

    for (var activeTerm = 0; activeTerm < 4; activeTerm++) {
        activeStartTerms[activeTerm] <== prefix[activeTerm] * activeEq[activeTerm].out;
        activeCountTerms[activeTerm] <== handCardCounts[activeTerm] * activeEq[activeTerm].out;
    }
    activeStart <== activeStartTerms[0] + activeStartTerms[1] + activeStartTerms[2] + activeStartTerms[3];
    activeStartPlusOne <== activeStart + 1;
    activeCount <== activeCountTerms[0] + activeCountTerms[1] + activeCountTerms[2] + activeCountTerms[3];

    activeCard0Running[0] <== 0;
    activeCard1Running[0] <== 0;
    activeRank0Running[0] <== 0;
    activeRank1Running[0] <== 0;

    for (var cardIndex = 0; cardIndex < 8; cardIndex++) {
        eqCard0Selector[cardIndex] = IsEqual();
        eqCard0Selector[cardIndex].in[0] <== activeStart;
        eqCard0Selector[cardIndex].in[1] <== cardIndex;

        eqCard1Selector[cardIndex] = IsEqual();
        eqCard1Selector[cardIndex].in[0] <== activeStartPlusOne;
        eqCard1Selector[cardIndex].in[1] <== cardIndex;

        activeCard0Running[cardIndex + 1] <== activeCard0Running[cardIndex] + eqCard0Selector[cardIndex].out * playerCards[cardIndex];
        activeCard1Running[cardIndex + 1] <== activeCard1Running[cardIndex] + eqCard1Selector[cardIndex].out * playerCards[cardIndex];
        activeRank0Running[cardIndex + 1] <== activeRank0Running[cardIndex] + eqCard0Selector[cardIndex].out * playerMeta[cardIndex].rank;
        activeRank1Running[cardIndex + 1] <== activeRank1Running[cardIndex] + eqCard1Selector[cardIndex].out * playerMeta[cardIndex].rank;
    }

    activeCard0 <== activeCard0Running[8];
    activeCard1 <== activeCard1Running[8];
    activeRank0 <== activeRank0Running[8];
    activeRank1 <== activeRank1Running[8];

    component activeRanksEqual = IsEqual();
    activeRanksEqual.in[0] <== activeRank0;
    activeRanksEqual.in[1] <== activeRank1;

    component activeCountTwo = IsEqual();
    activeCountTwo.in[0] <== activeCount;
    activeCountTwo.in[1] <== 2;

    activeSameRank <== activeRanksEqual.out;
    activeTwoSameRank <== activeCountTwo.out * activeSameRank;
    splitEligible <== activeTwoSameRank;

    component handScore[4];
    signal handSoftBits[4];
    signal handBusted[4];
    signal handCountTwoFlags[4];
    signal expectedMasks[4];
    signal activeHandCanPlay[4];
    signal activeHandOpen[4];
    signal activeDoubleAllowed[4];
    signal activeSplitAllowed[4];
    for (var handIndex = 0; handIndex < 4; handIndex++) {
        handScore[handIndex] = BlackjackHandScore();
        handScore[handIndex].start <== prefix[handIndex];
        handScore[handIndex].end <== prefix[handIndex + 1];
        for (var handCard = 0; handCard < 8; handCard++) {
            handScore[handIndex].cardValues[handCard] <== playerMeta[handCard].value;
            handScore[handIndex].cardIsAces[handCard] <== playerMeta[handCard].isAce;
        }

        handValues[handIndex] === handScore[handIndex].total;
        handSoftBits[handIndex] <== handScore[handIndex].soft;

        handGt21[handIndex] = LessThan(7);
        handGt21[handIndex].in[0] <== 21;
        handGt21[handIndex].in[1] <== handScore[handIndex].total;
        handBusted[handIndex] <== handGt21[handIndex].out;

        handCountTwo[handIndex] = IsEqual();
        handCountTwo[handIndex].in[0] <== handCardCounts[handIndex];
        handCountTwo[handIndex].in[1] <== 2;
        handCountTwoFlags[handIndex] <== handCountTwo[handIndex].out;
    }

    softMask === handSoftBits[0] + 2 * handSoftBits[1] + 4 * handSoftBits[2] + 8 * handSoftBits[3];

    for (var handCheck = 0; handCheck < 4; handCheck++) {
        handStatuses[handCheck] === 2 * handBusted[handCheck];
        handPayoutKinds[handCheck] === handBusted[handCheck];

        activeHandCanPlay[handCheck] <== awaitingPlayerAction.out * activeEq[handCheck].out;
        activeHandOpen[handCheck] <== activeHandCanPlay[handCheck] * (1 - handBusted[handCheck]);
        activeDoubleAllowed[handCheck] <== activeHandOpen[handCheck] * handCountTwoFlags[handCheck];
        activeSplitAllowed[handCheck] <== activeHandOpen[handCheck] * splitEligible;
        expectedMasks[handCheck] <== 3 * activeHandOpen[handCheck]
            + 4 * activeDoubleAllowed[handCheck]
            + 8 * activeSplitAllowed[handCheck];
        allowedActionMasks[handCheck] === expectedMasks[handCheck];
    }

    component oldPlayerHash = Poseidon(14);
    oldPlayerHash.inputs[0] <== sessionId;
    for (var oldHashIndex = 0; oldHashIndex < 8; oldHashIndex++) {
        oldPlayerHash.inputs[1 + oldHashIndex] <== oldPlayerCards[oldHashIndex];
    }
    oldPlayerHash.inputs[9] <== oldHandCardCounts[0];
    oldPlayerHash.inputs[10] <== oldHandCardCounts[1];
    oldPlayerHash.inputs[11] <== oldHandCardCounts[2];
    oldPlayerHash.inputs[12] <== oldHandCardCounts[3];
    oldPlayerHash.inputs[13] <== oldPlayerSalt;
    oldPlayerHash.out === oldPlayerStateCommitment;

    component newPlayerHash = Poseidon(14);
    newPlayerHash.inputs[0] <== sessionId;
    for (var newHashIndex = 0; newHashIndex < 8; newHashIndex++) {
        newPlayerHash.inputs[1 + newHashIndex] <== playerCards[newHashIndex];
    }
    newPlayerHash.inputs[9] <== handCardCounts[0];
    newPlayerHash.inputs[10] <== handCardCounts[1];
    newPlayerHash.inputs[11] <== handCardCounts[2];
    newPlayerHash.inputs[12] <== handCardCounts[3];
    newPlayerHash.inputs[13] <== newPlayerSalt;
    newPlayerHash.out === newPlayerStateCommitment;

    component dealerHash = Poseidon(6);
    dealerHash.inputs[0] <== sessionId;
    for (var dealerHashIndex = 0; dealerHashIndex < 4; dealerHashIndex++) {
        dealerHash.inputs[1 + dealerHashIndex] <== dealerPrivateCards[dealerHashIndex];
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

    component playerCipherHash = PoseidonChain20();
    playerCipherHash.inputs[0] <== sessionId;
    playerCipherHash.inputs[1] <== proofSequence;
    playerCipherHash.inputs[2] <== pendingAction;
    for (var cipherIndex = 0; cipherIndex < 8; cipherIndex++) {
        playerCipherHash.inputs[3 + cipherIndex] <== playerCards[cipherIndex];
    }
    playerCipherHash.inputs[11] <== handCardCounts[0];
    playerCipherHash.inputs[12] <== handCardCounts[1];
    playerCipherHash.inputs[13] <== handCardCounts[2];
    playerCipherHash.inputs[14] <== handCardCounts[3];
    playerCipherHash.inputs[15] <== playerSummaryHash.out;
    playerCipherHash.inputs[16] <== playerKey[0];
    playerCipherHash.inputs[17] <== playerKey[1];
    playerCipherHash.inputs[18] <== playerCipherSalt;
    playerCipherHash.inputs[19] <== handCount;
    playerCipherHash.out === playerCiphertextRef;

    component dealerCipherHash = Poseidon(12);
    dealerCipherHash.inputs[0] <== sessionId;
    dealerCipherHash.inputs[1] <== proofSequence;
    dealerCipherHash.inputs[2] <== nextPhase;
    dealerCipherHash.inputs[3] <== dealerPrivateCards[0];
    dealerCipherHash.inputs[4] <== dealerPrivateCards[1];
    dealerCipherHash.inputs[5] <== dealerPrivateCards[2];
    dealerCipherHash.inputs[6] <== dealerPrivateCards[3];
    dealerCipherHash.inputs[7] <== dealerUpValue;
    dealerCipherHash.inputs[8] <== handCount;
    dealerCipherHash.inputs[9] <== activeHandIndex;
    dealerCipherHash.inputs[10] <== dealerRevealMask;
    dealerCipherHash.inputs[11] <== dealerCipherSalt;
    dealerCipherHash.out === dealerCiphertextRef;
}

component main {public [sessionId, proofSequence, pendingAction, oldPlayerStateCommitment, newPlayerStateCommitment, dealerStateCommitment, playerKeyCommitment, playerCiphertextRef, dealerCiphertextRef, dealerUpValue, handCount, activeHandIndex, nextPhase, handValues, softMask, handStatuses, allowedActionMasks, handCardCounts, handPayoutKinds, playerCards, dealerCards, dealerRevealMask]} = BlackjackActionResolve();
