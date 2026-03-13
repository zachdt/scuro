pragma circom 2.1.6;

include "circomlib/circuits/bitify.circom";
include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";

template PokerDrawResolve() {
    signal input gameId;
    signal input handNumber;
    signal input handNonce;
    signal input playerIndex;
    signal input deckCommitment;
    signal input oldCommitment;
    signal input newCommitment;
    signal input newKeyCommitment;
    signal input newCiphertextRef;
    signal input discardMask;
    signal input proofSequence;

    signal input initialHand0Cards[5];
    signal input initialHand1Cards[5];
    signal input oldCards[5];
    signal input replacementCards[5];
    signal input oldSalt;
    signal input newSalt;
    signal input deckSalt;
    signal input key[2];
    signal input cipherSalt;

    component discardBits = Num2Bits(5);
    discardBits.in <== discardMask;

    component playerIsOne = IsEqual();
    playerIsOne.in[0] <== playerIndex;
    playerIsOne.in[1] <== 1;

    signal newCards[5];
    for (var i = 0; i < 5; i++) {
        oldCards[i] === initialHand0Cards[i] + playerIsOne.out * (initialHand1Cards[i] - initialHand0Cards[i]);
        newCards[i] <== oldCards[i] + discardBits.out[i] * (replacementCards[i] - oldCards[i]);
    }

    component oldHash = Poseidon(9);
    oldHash.inputs[0] <== gameId;
    oldHash.inputs[1] <== handNumber;
    oldHash.inputs[2] <== handNonce;
    for (var j = 0; j < 5; j++) {
        oldHash.inputs[3 + j] <== oldCards[j];
    }
    oldHash.inputs[8] <== oldSalt;
    oldHash.out === oldCommitment;

    component newHash = Poseidon(9);
    newHash.inputs[0] <== gameId;
    newHash.inputs[1] <== handNumber;
    newHash.inputs[2] <== handNonce;
    for (var k = 0; k < 5; k++) {
        newHash.inputs[3 + k] <== newCards[k];
    }
    newHash.inputs[8] <== newSalt;
    newHash.out === newCommitment;

    component keyHash = Poseidon(4);
    keyHash.inputs[0] <== gameId;
    keyHash.inputs[1] <== handNumber;
    keyHash.inputs[2] <== key[0];
    keyHash.inputs[3] <== key[1];
    keyHash.out === newKeyCommitment;

    component cipherHash = Poseidon(14);
    cipherHash.inputs[0] <== gameId;
    cipherHash.inputs[1] <== handNumber;
    cipherHash.inputs[2] <== handNonce;
    for (var m = 0; m < 5; m++) {
        cipherHash.inputs[3 + m] <== newCards[m];
    }
    cipherHash.inputs[8] <== key[0];
    cipherHash.inputs[9] <== key[1];
    cipherHash.inputs[10] <== cipherSalt;
    cipherHash.inputs[11] <== proofSequence;
    cipherHash.inputs[12] <== discardMask;
    cipherHash.inputs[13] <== playerIndex;
    cipherHash.out === newCiphertextRef;

    component deckHash = Poseidon(14);
    deckHash.inputs[0] <== gameId;
    deckHash.inputs[1] <== handNumber;
    deckHash.inputs[2] <== handNonce;
    for (var n = 0; n < 5; n++) {
        deckHash.inputs[3 + n] <== initialHand0Cards[n];
        deckHash.inputs[8 + n] <== initialHand1Cards[n];
    }
    deckHash.inputs[13] <== deckSalt;
    deckHash.out === deckCommitment;
}

component main {public [gameId, handNumber, handNonce, playerIndex, deckCommitment, oldCommitment, newCommitment, newKeyCommitment, newCiphertextRef, discardMask, proofSequence]} = PokerDrawResolve();
