pragma circom 2.1.6;

include "circomlib/circuits/poseidon.circom";

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

    signal input oldPlayerSlots[8];
    signal input newPlayerSlots[8];
    signal input dealerSlots[4];
    signal input oldPlayerSalt;
    signal input newPlayerSalt;
    signal input dealerSalt;
    signal input playerKey[2];
    signal input playerCipherSalt;
    signal input dealerCipherSalt;

    component oldPlayerHash = Poseidon(10);
    oldPlayerHash.inputs[0] <== sessionId;
    for (var i = 0; i < 8; i++) {
        oldPlayerHash.inputs[1 + i] <== oldPlayerSlots[i];
    }
    oldPlayerHash.inputs[9] <== oldPlayerSalt;
    oldPlayerHash.out === oldPlayerStateCommitment;

    component newPlayerHash = Poseidon(10);
    newPlayerHash.inputs[0] <== sessionId;
    for (var j = 0; j < 8; j++) {
        newPlayerHash.inputs[1 + j] <== newPlayerSlots[j];
    }
    newPlayerHash.inputs[9] <== newPlayerSalt;
    newPlayerHash.out === newPlayerStateCommitment;

    component dealerHash = Poseidon(6);
    dealerHash.inputs[0] <== sessionId;
    for (var k = 0; k < 4; k++) {
        dealerHash.inputs[1 + k] <== dealerSlots[k];
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

    component playerCipherHash = Poseidon(16);
    playerCipherHash.inputs[0] <== sessionId;
    playerCipherHash.inputs[1] <== proofSequence;
    playerCipherHash.inputs[2] <== pendingAction;
    for (var m = 0; m < 8; m++) {
        playerCipherHash.inputs[3 + m] <== newPlayerSlots[m];
    }
    playerCipherHash.inputs[11] <== playerSummaryHash.out;
    playerCipherHash.inputs[12] <== playerKey[0];
    playerCipherHash.inputs[13] <== playerKey[1];
    playerCipherHash.inputs[14] <== playerCipherSalt;
    playerCipherHash.inputs[15] <== handCount;
    playerCipherHash.out === playerCiphertextRef;

    component dealerStatusHash = Poseidon(4);
    dealerStatusHash.inputs[0] <== handStatuses[0];
    dealerStatusHash.inputs[1] <== handStatuses[1];
    dealerStatusHash.inputs[2] <== handStatuses[2];
    dealerStatusHash.inputs[3] <== handStatuses[3];

    component dealerCipherHash = Poseidon(12);
    dealerCipherHash.inputs[0] <== sessionId;
    dealerCipherHash.inputs[1] <== proofSequence;
    dealerCipherHash.inputs[2] <== nextPhase;
    for (var n = 0; n < 4; n++) {
        dealerCipherHash.inputs[3 + n] <== dealerSlots[n];
    }
    dealerCipherHash.inputs[7] <== dealerUpValue;
    dealerCipherHash.inputs[8] <== handCount;
    dealerCipherHash.inputs[9] <== activeHandIndex;
    dealerCipherHash.inputs[10] <== dealerStatusHash.out;
    dealerCipherHash.inputs[11] <== dealerCipherSalt;
    dealerCipherHash.out === dealerCiphertextRef;
}

component main {public [sessionId, proofSequence, pendingAction, oldPlayerStateCommitment, newPlayerStateCommitment, dealerStateCommitment, playerKeyCommitment, playerCiphertextRef, dealerCiphertextRef, dealerUpValue, handCount, activeHandIndex, nextPhase, handValues, softMask, handStatuses, allowedActionMasks]} = BlackjackActionResolve();
