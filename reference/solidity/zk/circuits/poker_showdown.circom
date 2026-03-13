pragma circom 2.1.6;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";

template PokerShowdown() {
    signal input gameId;
    signal input handNumber;
    signal input handNonce;
    signal input handCommitment0;
    signal input handCommitment1;
    signal input winnerIndex;
    signal input isTie;

    signal input hand0Cards[5];
    signal input hand1Cards[5];
    signal input hand0Salt;
    signal input hand1Salt;
    signal input hand0Score;
    signal input hand1Score;

    component hand0Hash = Poseidon(9);
    hand0Hash.inputs[0] <== gameId;
    hand0Hash.inputs[1] <== handNumber;
    hand0Hash.inputs[2] <== handNonce;
    for (var i = 0; i < 5; i++) {
        hand0Hash.inputs[3 + i] <== hand0Cards[i];
    }
    hand0Hash.inputs[8] <== hand0Salt;
    hand0Hash.out === handCommitment0;

    component hand1Hash = Poseidon(9);
    hand1Hash.inputs[0] <== gameId;
    hand1Hash.inputs[1] <== handNumber;
    hand1Hash.inputs[2] <== handNonce;
    for (var j = 0; j < 5; j++) {
        hand1Hash.inputs[3 + j] <== hand1Cards[j];
    }
    hand1Hash.inputs[8] <== hand1Salt;
    hand1Hash.out === handCommitment1;

    component isEqual = IsEqual();
    isEqual.in[0] <== hand0Score;
    isEqual.in[1] <== hand1Score;
    isTie === isEqual.out;

    component lessThan = LessThan(64);
    lessThan.in[0] <== hand0Score;
    lessThan.in[1] <== hand1Score;

    signal winnerCalc;
    winnerCalc <== isEqual.out * 2 + (1 - isEqual.out) * (1 - lessThan.out);
    winnerIndex === winnerCalc;
}

component main {public [gameId, handNumber, handNonce, handCommitment0, handCommitment1, winnerIndex, isTie]} = PokerShowdown();
