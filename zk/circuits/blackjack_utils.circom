pragma circom 2.1.6;

include "circomlib/circuits/poseidon.circom";
include "circomlib/circuits/comparators.circom";

template PublicDealerCard() {
    signal input visible;
    signal input hidden;

    signal diffEmpty;
    signal diffHidden;

    diffEmpty <== visible - 104;
    diffHidden <== visible - hidden;
    diffEmpty * diffHidden === 0;
}

template PoseidonChain13() {
    signal input inputs[13];
    signal output out;

    component first = Poseidon(6);
    component second = Poseidon(6);
    component third = Poseidon(3);

    for (var i = 0; i < 6; i++) {
        first.inputs[i] <== inputs[i];
    }

    for (var j = 0; j < 5; j++) {
        second.inputs[j + 1] <== inputs[j + 6];
    }
    second.inputs[0] <== first.out;

    third.inputs[0] <== second.out;
    third.inputs[1] <== inputs[11];
    third.inputs[2] <== inputs[12];

    out <== third.out;
}

template PoseidonChain14() {
    signal input inputs[14];
    signal output out;

    component first = Poseidon(6);
    component second = Poseidon(6);
    component third = Poseidon(4);

    for (var i = 0; i < 6; i++) {
        first.inputs[i] <== inputs[i];
    }

    for (var j = 0; j < 5; j++) {
        second.inputs[j + 1] <== inputs[j + 6];
    }
    second.inputs[0] <== first.out;

    third.inputs[0] <== second.out;
    third.inputs[1] <== inputs[11];
    third.inputs[2] <== inputs[12];
    third.inputs[3] <== inputs[13];

    out <== third.out;
}

template PoseidonChain15() {
    signal input inputs[15];
    signal output out;

    component first = Poseidon(6);
    component second = Poseidon(6);
    component third = Poseidon(5);

    for (var i = 0; i < 6; i++) {
        first.inputs[i] <== inputs[i];
    }

    for (var j = 0; j < 5; j++) {
        second.inputs[j + 1] <== inputs[j + 6];
    }
    second.inputs[0] <== first.out;

    third.inputs[0] <== second.out;
    third.inputs[1] <== inputs[11];
    third.inputs[2] <== inputs[12];
    third.inputs[3] <== inputs[13];
    third.inputs[4] <== inputs[14];

    out <== third.out;
}

template PoseidonChain38() {
    signal input inputs[38];
    signal output out;

    component h0 = Poseidon(6);
    component h1 = Poseidon(6);
    component h2 = Poseidon(6);
    component h3 = Poseidon(6);
    component h4 = Poseidon(6);
    component h5 = Poseidon(6);
    component h6 = Poseidon(3);

    for (var i = 0; i < 6; i++) {
        h0.inputs[i] <== inputs[i];
    }
    for (var j = 0; j < 5; j++) {
        h1.inputs[j + 1] <== inputs[j + 6];
    }
    h1.inputs[0] <== h0.out;

    for (var k = 0; k < 5; k++) {
        h2.inputs[k + 1] <== inputs[k + 11];
    }
    h2.inputs[0] <== h1.out;

    for (var l = 0; l < 5; l++) {
        h3.inputs[l + 1] <== inputs[l + 16];
    }
    h3.inputs[0] <== h2.out;

    for (var m = 0; m < 5; m++) {
        h4.inputs[m + 1] <== inputs[m + 21];
    }
    h4.inputs[0] <== h3.out;

    for (var n = 0; n < 5; n++) {
        h5.inputs[n + 1] <== inputs[n + 26];
    }
    h5.inputs[0] <== h4.out;

    h6.inputs[0] <== h5.out;
    h6.inputs[1] <== inputs[31];
    h6.inputs[2] <== inputs[32];

    component tail = Poseidon(6);
    tail.inputs[0] <== h6.out;
    tail.inputs[1] <== inputs[33];
    tail.inputs[2] <== inputs[34];
    tail.inputs[3] <== inputs[35];
    tail.inputs[4] <== inputs[36];
    tail.inputs[5] <== inputs[37];

    out <== tail.out;
}

template PoseidonChain47() {
    signal input inputs[47];
    signal output out;

    component h0 = Poseidon(6);
    component h1 = Poseidon(6);
    component h2 = Poseidon(6);
    component h3 = Poseidon(6);
    component h4 = Poseidon(6);
    component h5 = Poseidon(6);
    component h6 = Poseidon(6);
    component h7 = Poseidon(6);
    component h8 = Poseidon(6);
    component h9 = Poseidon(2);

    for (var i = 0; i < 6; i++) {
        h0.inputs[i] <== inputs[i];
    }
    for (var j = 0; j < 5; j++) {
        h1.inputs[j + 1] <== inputs[j + 6];
    }
    h1.inputs[0] <== h0.out;

    for (var k = 0; k < 5; k++) {
        h2.inputs[k + 1] <== inputs[k + 11];
    }
    h2.inputs[0] <== h1.out;

    for (var l = 0; l < 5; l++) {
        h3.inputs[l + 1] <== inputs[l + 16];
    }
    h3.inputs[0] <== h2.out;

    for (var m = 0; m < 5; m++) {
        h4.inputs[m + 1] <== inputs[m + 21];
    }
    h4.inputs[0] <== h3.out;

    for (var n = 0; n < 5; n++) {
        h5.inputs[n + 1] <== inputs[n + 26];
    }
    h5.inputs[0] <== h4.out;

    for (var o = 0; o < 5; o++) {
        h6.inputs[o + 1] <== inputs[o + 31];
    }
    h6.inputs[0] <== h5.out;

    for (var p = 0; p < 5; p++) {
        h7.inputs[p + 1] <== inputs[p + 36];
    }
    h7.inputs[0] <== h6.out;

    for (var q = 0; q < 5; q++) {
        h8.inputs[q + 1] <== inputs[q + 41];
    }
    h8.inputs[0] <== h7.out;

    h9.inputs[0] <== h8.out;
    h9.inputs[1] <== inputs[46];

    out <== h9.out;
}
