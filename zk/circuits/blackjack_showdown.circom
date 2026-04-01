pragma circom 2.1.6;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";
include "./blackjack_utils.circom";

template BlackjackShowdown() {
    signal input sessionId;
    signal input proofSequence;
    signal input playerStateCommitment;
    signal input dealerStateCommitment;
    signal input payout;
    signal input dealerFinalValue;
    signal input handCount;
    signal input activeHandIndex;
    signal input handStatuses[4];
    signal input handValues[4];
    signal input handWagers[4];
    signal input handCardCounts[4];
    signal input handPayoutKinds[4];
    signal input playerCards[8];
    signal input dealerCards[4];
    signal input dealerRevealMask;

    signal input dealerPrivateCards[4];
    signal input playerSalt;
    signal input dealerSalt;

    signal prefix[5];
    signal totalPlayerCards;
    signal payoutRunning[5];
    signal dealerRawTotal;
    signal dealerAceCount;
    signal dealerTotals[5];
    signal dealerAcesRemaining[5];
    signal dealerReductions[4];
    signal dealerBust;
    signal expectedDealerRevealMask;

    component handCountLt[4];
    component handCountZero[4];
    component playerMeta[8];
    component dealerMeta[4];
    component handScore[4];
    component playerLtTotal[8];
    component dealerGt21Step[4];
    component dealerAcesZeroStep[4];
    component handGt21[4];
    component playerGreater[4];
    component dealerGreater[4];
    component totalsEqual[4];
    signal handBusted[4];
    signal handIsLive[4];
    signal handWin[4];
    signal handPush[4];
    signal handLoss[4];
    signal handStatusExpected[4];
    signal handPayoutKindExpected[4];
    signal handPayoutExpected[4];
    signal handPlayable[4];
    signal handPlayerGreater[4];
    signal handDealerGreater[4];
    signal handTotalsEqual[4];
    signal dealerNotBust;
    signal handWinFromDealerBust[4];
    signal handWinFromPlayerGreater[4];
    signal handPushPayout[4];
    signal handWinPayout[4];

    prefix[0] <== 0;
    prefix[1] <== handCardCounts[0];
    prefix[2] <== handCardCounts[0] + handCardCounts[1];
    prefix[3] <== handCardCounts[0] + handCardCounts[1] + handCardCounts[2];
    prefix[4] <== handCardCounts[0] + handCardCounts[1] + handCardCounts[2] + handCardCounts[3];
    totalPlayerCards <== prefix[4];

    component totalCardsLt9 = LessThan(5);
    totalCardsLt9.in[0] <== totalPlayerCards;
    totalCardsLt9.in[1] <== 9;
    totalCardsLt9.out === 1;

    component handCountLt5 = LessThan(4);
    handCountLt5.in[0] <== handCount;
    handCountLt5.in[1] <== 5;
    handCountLt5.out === 1;

    component handCountZeroAll = IsZero();
    handCountZeroAll.in <== handCount;
    handCountZeroAll.out === 0;

    for (var i = 0; i < 8; i++) {
        playerMeta[i] = BlackjackCardMeta();
        playerMeta[i].card <== playerCards[i];

        playerLtTotal[i] = LessThan(5);
        playerLtTotal[i].in[0] <== i;
        playerLtTotal[i].in[1] <== totalPlayerCards;
        playerMeta[i].isReal === playerLtTotal[i].out;
    }

    for (var hand = 0; hand < 4; hand++) {
        handCountLt[hand] = LessThan(4);
        handCountLt[hand].in[0] <== hand;
        handCountLt[hand].in[1] <== handCount;

        handCountZero[hand] = IsZero();
        handCountZero[hand].in <== handCardCounts[hand];

        handCountLt[hand].out * handCountZero[hand].out === 0;
        (1 - handCountLt[hand].out) * handCardCounts[hand] === 0;
        (1 - handCountLt[hand].out) * handWagers[hand] === 0;
    }

    component activeIndexLt = LessThan(4);
    activeIndexLt.in[0] <== activeHandIndex;
    activeIndexLt.in[1] <== handCount;
    activeIndexLt.out === 1;

    for (var dealerIndex = 0; dealerIndex < 4; dealerIndex++) {
        dealerMeta[dealerIndex] = BlackjackCardMeta();
        dealerMeta[dealerIndex].card <== dealerPrivateCards[dealerIndex];
        dealerCards[dealerIndex] === dealerPrivateCards[dealerIndex];
    }
    dealerMeta[0].isReal === 1;
    dealerMeta[1].isReal === 1;
    dealerMeta[2].isReal * (1 - dealerMeta[1].isReal) === 0;
    dealerMeta[3].isReal * (1 - dealerMeta[2].isReal) === 0;

    expectedDealerRevealMask <== dealerMeta[0].isReal + 2 * dealerMeta[1].isReal + 4 * dealerMeta[2].isReal + 8 * dealerMeta[3].isReal;
    dealerRevealMask === expectedDealerRevealMask;

    dealerRawTotal <== dealerMeta[0].value + dealerMeta[1].value + dealerMeta[2].value + dealerMeta[3].value;
    dealerAceCount <== dealerMeta[0].isAce + dealerMeta[1].isAce + dealerMeta[2].isAce + dealerMeta[3].isAce;
    dealerTotals[0] <== dealerRawTotal;
    dealerAcesRemaining[0] <== dealerAceCount;

    for (var dealerStep = 0; dealerStep < 4; dealerStep++) {
        dealerGt21Step[dealerStep] = LessThan(7);
        dealerGt21Step[dealerStep].in[0] <== 21;
        dealerGt21Step[dealerStep].in[1] <== dealerTotals[dealerStep];

        dealerAcesZeroStep[dealerStep] = IsZero();
        dealerAcesZeroStep[dealerStep].in <== dealerAcesRemaining[dealerStep];

        dealerReductions[dealerStep] <== dealerGt21Step[dealerStep].out * (1 - dealerAcesZeroStep[dealerStep].out);
        dealerTotals[dealerStep + 1] <== dealerTotals[dealerStep] - 10 * dealerReductions[dealerStep];
        dealerAcesRemaining[dealerStep + 1] <== dealerAcesRemaining[dealerStep] - dealerReductions[dealerStep];
    }

    dealerFinalValue === dealerTotals[4];

    component dealerGt21 = LessThan(7);
    dealerGt21.in[0] <== 21;
    dealerGt21.in[1] <== dealerTotals[4];
    dealerBust <== dealerGt21.out;
    dealerNotBust <== 1 - dealerBust;

    payoutRunning[0] <== 0;

    for (var handIndex = 0; handIndex < 4; handIndex++) {
        handScore[handIndex] = BlackjackHandScore();
        handScore[handIndex].start <== prefix[handIndex];
        handScore[handIndex].end <== prefix[handIndex + 1];
        for (var card = 0; card < 8; card++) {
            handScore[handIndex].cardValues[card] <== playerMeta[card].value;
            handScore[handIndex].cardIsAces[card] <== playerMeta[card].isAce;
        }

        handValues[handIndex] === handScore[handIndex].total;
        handIsLive[handIndex] <== handCountLt[handIndex].out * (1 - handCountZero[handIndex].out);

        handGt21[handIndex] = LessThan(7);
        handGt21[handIndex].in[0] <== 21;
        handGt21[handIndex].in[1] <== handScore[handIndex].total;
        handBusted[handIndex] <== handIsLive[handIndex] * handGt21[handIndex].out;
        handPlayable[handIndex] <== handIsLive[handIndex] - handBusted[handIndex];

        playerGreater[handIndex] = LessThan(7);
        playerGreater[handIndex].in[0] <== dealerTotals[4];
        playerGreater[handIndex].in[1] <== handScore[handIndex].total;

        dealerGreater[handIndex] = LessThan(7);
        dealerGreater[handIndex].in[0] <== handScore[handIndex].total;
        dealerGreater[handIndex].in[1] <== dealerTotals[4];

        totalsEqual[handIndex] = IsEqual();
        totalsEqual[handIndex].in[0] <== handScore[handIndex].total;
        totalsEqual[handIndex].in[1] <== dealerTotals[4];

        handPlayerGreater[handIndex] <== handPlayable[handIndex] * playerGreater[handIndex].out;
        handDealerGreater[handIndex] <== handPlayable[handIndex] * dealerGreater[handIndex].out;
        handTotalsEqual[handIndex] <== handPlayable[handIndex] * totalsEqual[handIndex].out;

        handWinFromDealerBust[handIndex] <== handPlayable[handIndex] * dealerBust;
        handWinFromPlayerGreater[handIndex] <== handPlayerGreater[handIndex] * dealerNotBust;
        handWin[handIndex] <== handWinFromDealerBust[handIndex] + handWinFromPlayerGreater[handIndex];
        handPush[handIndex] <== handTotalsEqual[handIndex] * dealerNotBust;
        handLoss[handIndex] <== handBusted[handIndex] + handDealerGreater[handIndex] * dealerNotBust;

        handStatusExpected[handIndex] <== 2 * handBusted[handIndex]
            + 3 * handPush[handIndex]
            + 4 * handWin[handIndex]
            + 5 * handLoss[handIndex];
        handPayoutKindExpected[handIndex] <== handLoss[handIndex] + 2 * handPush[handIndex] + 3 * handWin[handIndex];
        handPushPayout[handIndex] <== handPush[handIndex] * handWagers[handIndex];
        handWinPayout[handIndex] <== handWin[handIndex] * (2 * handWagers[handIndex]);
        handPayoutExpected[handIndex] <== handPushPayout[handIndex] + handWinPayout[handIndex];

        handStatuses[handIndex] === handStatusExpected[handIndex];
        handPayoutKinds[handIndex] === handPayoutKindExpected[handIndex];

        payoutRunning[handIndex + 1] <== payoutRunning[handIndex] + handPayoutExpected[handIndex];
    }

    payout === payoutRunning[4];

    component playerHash = Poseidon(14);
    playerHash.inputs[0] <== sessionId;
    for (var playerHashIndex = 0; playerHashIndex < 8; playerHashIndex++) {
        playerHash.inputs[1 + playerHashIndex] <== playerCards[playerHashIndex];
    }
    playerHash.inputs[9] <== handCardCounts[0];
    playerHash.inputs[10] <== handCardCounts[1];
    playerHash.inputs[11] <== handCardCounts[2];
    playerHash.inputs[12] <== handCardCounts[3];
    playerHash.inputs[13] <== playerSalt;
    playerHash.out === playerStateCommitment;

    component dealerHash = Poseidon(6);
    dealerHash.inputs[0] <== sessionId;
    for (var dealerHashIndex = 0; dealerHashIndex < 4; dealerHashIndex++) {
        dealerHash.inputs[1 + dealerHashIndex] <== dealerPrivateCards[dealerHashIndex];
    }
    dealerHash.inputs[5] <== dealerSalt;
    dealerHash.out === dealerStateCommitment;
}

component main {public [sessionId, proofSequence, playerStateCommitment, dealerStateCommitment, payout, dealerFinalValue, handCount, activeHandIndex, handStatuses, handValues, handWagers, handCardCounts, handPayoutKinds, playerCards, dealerCards, dealerRevealMask]} = BlackjackShowdown();
