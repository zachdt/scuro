pragma circom 2.1.6;

include "circomlib/circuits/poseidon.circom";

template PokerInitialDeal() {
    signal input gameId;
    signal input handNumber;
    signal input handNonce;
    signal input deckCommitment;
    signal input handCommitment0;
    signal input handCommitment1;
    signal input keyCommitment0;
    signal input keyCommitment1;
    signal input ciphertextRef0;
    signal input ciphertextRef1;

    signal input hand0Cards[5];
    signal input hand1Cards[5];
    signal input hand0Salt;
    signal input hand1Salt;
    signal input deckSalt;
    signal input key0[2];
    signal input key1[2];
    signal input cipherSalt0;
    signal input cipherSalt1;

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

    component key0Hash = Poseidon(4);
    key0Hash.inputs[0] <== gameId;
    key0Hash.inputs[1] <== handNumber;
    key0Hash.inputs[2] <== key0[0];
    key0Hash.inputs[3] <== key0[1];
    key0Hash.out === keyCommitment0;

    component key1Hash = Poseidon(4);
    key1Hash.inputs[0] <== gameId;
    key1Hash.inputs[1] <== handNumber;
    key1Hash.inputs[2] <== key1[0];
    key1Hash.inputs[3] <== key1[1];
    key1Hash.out === keyCommitment1;

    component cipher0Hash = Poseidon(11);
    cipher0Hash.inputs[0] <== gameId;
    cipher0Hash.inputs[1] <== handNumber;
    cipher0Hash.inputs[2] <== handNonce;
    for (var k = 0; k < 5; k++) {
        cipher0Hash.inputs[3 + k] <== hand0Cards[k];
    }
    cipher0Hash.inputs[8] <== key0[0];
    cipher0Hash.inputs[9] <== key0[1];
    cipher0Hash.inputs[10] <== cipherSalt0;
    cipher0Hash.out === ciphertextRef0;

    component cipher1Hash = Poseidon(11);
    cipher1Hash.inputs[0] <== gameId;
    cipher1Hash.inputs[1] <== handNumber;
    cipher1Hash.inputs[2] <== handNonce;
    for (var m = 0; m < 5; m++) {
        cipher1Hash.inputs[3 + m] <== hand1Cards[m];
    }
    cipher1Hash.inputs[8] <== key1[0];
    cipher1Hash.inputs[9] <== key1[1];
    cipher1Hash.inputs[10] <== cipherSalt1;
    cipher1Hash.out === ciphertextRef1;

    component deckHash = Poseidon(14);
    deckHash.inputs[0] <== gameId;
    deckHash.inputs[1] <== handNumber;
    deckHash.inputs[2] <== handNonce;
    for (var n = 0; n < 5; n++) {
        deckHash.inputs[3 + n] <== hand0Cards[n];
        deckHash.inputs[8 + n] <== hand1Cards[n];
    }
    deckHash.inputs[13] <== deckSalt;
    deckHash.out === deckCommitment;
}

component main {public [gameId, handNumber, handNonce, deckCommitment, handCommitment0, handCommitment1, keyCommitment0, keyCommitment1, ciphertextRef0, ciphertextRef1]} = PokerInitialDeal();
