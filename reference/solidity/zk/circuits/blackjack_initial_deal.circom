pragma circom 2.1.6;

include "circomlib/circuits/poseidon.circom";

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
    signal input handCount;
    signal input activeHandIndex;
    signal input payout;
    signal input immediateResultCode;
    signal input handValues[4];
    signal input softMask;
    signal input handStatuses[4];
    signal input allowedActionMasks[4];

    signal input playerSlots[8];
    signal input dealerSlots[4];
    signal input playerSalt;
    signal input dealerSalt;
    signal input deckSalt;
    signal input playerKey[2];
    signal input playerCipherSalt;
    signal input dealerCipherSalt;

    component playerHash = Poseidon(10);
    playerHash.inputs[0] <== sessionId;
    for (var i = 0; i < 8; i++) {
        playerHash.inputs[1 + i] <== playerSlots[i];
    }
    playerHash.inputs[9] <== playerSalt;
    playerHash.out === playerStateCommitment;

    component dealerHash = Poseidon(6);
    dealerHash.inputs[0] <== sessionId;
    for (var j = 0; j < 4; j++) {
        dealerHash.inputs[1 + j] <== dealerSlots[j];
    }
    dealerHash.inputs[5] <== dealerSalt;
    dealerHash.out === dealerStateCommitment;

    component playerKeyHash = Poseidon(3);
    playerKeyHash.inputs[0] <== sessionId;
    playerKeyHash.inputs[1] <== playerKey[0];
    playerKeyHash.inputs[2] <== playerKey[1];
    playerKeyHash.out === playerKeyCommitment;

    component playerSummaryHash = Poseidon(13);
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

    component playerCipherHash = Poseidon(14);
    playerCipherHash.inputs[0] <== sessionId;
    playerCipherHash.inputs[1] <== handNonce;
    for (var k = 0; k < 8; k++) {
        playerCipherHash.inputs[2 + k] <== playerSlots[k];
    }
    playerCipherHash.inputs[10] <== playerSummaryHash.out;
    playerCipherHash.inputs[11] <== playerKey[0];
    playerCipherHash.inputs[12] <== playerKey[1];
    playerCipherHash.inputs[13] <== playerCipherSalt;
    playerCipherHash.out === playerCiphertextRef;

    component dealerCipherHash = Poseidon(11);
    dealerCipherHash.inputs[0] <== sessionId;
    dealerCipherHash.inputs[1] <== handNonce;
    for (var m = 0; m < 4; m++) {
        dealerCipherHash.inputs[2 + m] <== dealerSlots[m];
    }
    dealerCipherHash.inputs[6] <== dealerCipherSalt;
    dealerCipherHash.inputs[7] <== dealerUpValue;
    dealerCipherHash.inputs[8] <== handCount;
    dealerCipherHash.inputs[9] <== payout;
    dealerCipherHash.inputs[10] <== immediateResultCode;
    dealerCipherHash.out === dealerCiphertextRef;

    component deckHash = Poseidon(15);
    deckHash.inputs[0] <== sessionId;
    deckHash.inputs[1] <== handNonce;
    for (var n = 0; n < 8; n++) {
        deckHash.inputs[2 + n] <== playerSlots[n];
    }
    for (var p = 0; p < 4; p++) {
        deckHash.inputs[10 + p] <== dealerSlots[p];
    }
    deckHash.inputs[14] <== deckSalt;
    deckHash.out === deckCommitment;
}

component main {public [sessionId, handNonce, deckCommitment, playerStateCommitment, dealerStateCommitment, playerKeyCommitment, playerCiphertextRef, dealerCiphertextRef, dealerUpValue, handCount, activeHandIndex, payout, immediateResultCode, handValues, softMask, handStatuses, allowedActionMasks]} = BlackjackInitialDeal();
