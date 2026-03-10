pragma circom 2.1.6;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";

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

    signal input playerSlots[8];
    signal input dealerSlots[4];
    signal input playerSalt;
    signal input dealerSalt;
    signal input wager;
    signal input payoutWitness;

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

    component statusHash = Poseidon(4);
    statusHash.inputs[0] <== handStatuses[0];
    statusHash.inputs[1] <== handStatuses[1];
    statusHash.inputs[2] <== handStatuses[2];
    statusHash.inputs[3] <== handStatuses[3];

    component payoutHash = Poseidon(9);
    payoutHash.inputs[0] <== sessionId;
    payoutHash.inputs[1] <== proofSequence;
    payoutHash.inputs[2] <== payout;
    payoutHash.inputs[3] <== payoutWitness;
    payoutHash.inputs[4] <== dealerFinalValue;
    payoutHash.inputs[5] <== handCount;
    payoutHash.inputs[6] <== activeHandIndex;
    payoutHash.inputs[7] <== wager;
    payoutHash.inputs[8] <== statusHash.out;
}

component main {public [sessionId, proofSequence, playerStateCommitment, dealerStateCommitment, payout, dealerFinalValue, handCount, activeHandIndex, handStatuses]} = BlackjackShowdown();
