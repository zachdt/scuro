pragma circom 2.1.6;

include "circomlib/circuits/comparators.circom";

template BlackjackCardMeta() {
    signal input card;

    signal output isReal;
    signal output rank;
    signal output value;
    signal output isAce;
    signal output isTenValue;
    signal output suitIndex;
    signal output suitFlags[4];
    component eqRank[13];

    component lt53 = LessThan(7);
    lt53.in[0] <== card;
    lt53.in[1] <== 53;
    lt53.out === 1;

    component lt52 = LessThan(7);
    lt52.in[0] <== card;
    lt52.in[1] <== 52;
    isReal <== lt52.out;

    component lt13 = LessThan(7);
    lt13.in[0] <== card;
    lt13.in[1] <== 13;

    component lt26 = LessThan(7);
    lt26.in[0] <== card;
    lt26.in[1] <== 26;

    component lt39 = LessThan(7);
    lt39.in[0] <== card;
    lt39.in[1] <== 39;

    suitFlags[0] <== lt13.out;
    suitFlags[1] <== (1 - lt13.out) * lt26.out;
    suitFlags[2] <== (1 - lt26.out) * lt39.out;
    suitFlags[3] <== (1 - lt39.out) * isReal;

    suitIndex <== suitFlags[1] + 2 * suitFlags[2] + 3 * suitFlags[3];
    rank <== card - 13 * suitIndex;

    for (var r = 0; r < 13; r++) {
        eqRank[r] = IsEqual();
        eqRank[r].in[0] <== rank;
        eqRank[r].in[1] <== r;
    }

    isAce <== isReal * eqRank[0].out;
    isTenValue <== isReal * (eqRank[9].out + eqRank[10].out + eqRank[11].out + eqRank[12].out);
    value <== isReal * (
        11 * eqRank[0].out
        + 2 * eqRank[1].out
        + 3 * eqRank[2].out
        + 4 * eqRank[3].out
        + 5 * eqRank[4].out
        + 6 * eqRank[5].out
        + 7 * eqRank[6].out
        + 8 * eqRank[7].out
        + 9 * eqRank[8].out
        + 10 * eqRank[9].out
        + 10 * eqRank[10].out
        + 10 * eqRank[11].out
        + 10 * eqRank[12].out
    );
}

template BlackjackHandScore() {
    signal input start;
    signal input end;
    signal input cardValues[8];
    signal input cardIsAces[8];

    signal output total;
    signal output soft;

    signal inHand[8];
    signal totalRunning[9];
    signal aceRunning[9];
    signal reducedTotals[5];
    signal remainingAces[5];
    signal reductions[4];
    component ltStart[8];
    component ltEnd[8];
    component gt21[4];
    component acesZero[4];

    totalRunning[0] <== 0;
    aceRunning[0] <== 0;

    for (var i = 0; i < 8; i++) {
        ltStart[i] = LessThan(4);
        ltStart[i].in[0] <== i;
        ltStart[i].in[1] <== start;

        ltEnd[i] = LessThan(4);
        ltEnd[i].in[0] <== i;
        ltEnd[i].in[1] <== end;

        inHand[i] <== (1 - ltStart[i].out) * ltEnd[i].out;
        totalRunning[i + 1] <== totalRunning[i] + inHand[i] * cardValues[i];
        aceRunning[i + 1] <== aceRunning[i] + inHand[i] * cardIsAces[i];
    }

    reducedTotals[0] <== totalRunning[8];
    remainingAces[0] <== aceRunning[8];

    for (var j = 0; j < 4; j++) {
        gt21[j] = LessThan(7);
        gt21[j].in[0] <== 21;
        gt21[j].in[1] <== reducedTotals[j];

        acesZero[j] = IsZero();
        acesZero[j].in <== remainingAces[j];

        reductions[j] <== gt21[j].out * (1 - acesZero[j].out);
        reducedTotals[j + 1] <== reducedTotals[j] - 10 * reductions[j];
        remainingAces[j + 1] <== remainingAces[j] - reductions[j];
    }

    total <== reducedTotals[4];

    component softZero = IsZero();
    softZero.in <== remainingAces[4];
    soft <== 1 - softZero.out;
}

template PoseidonChain29() {
    signal input inputs[29];
    signal output out;

    component first = Poseidon(16);
    component second = Poseidon(14);

    for (var i = 0; i < 16; i++) {
        first.inputs[i] <== inputs[i];
    }

    second.inputs[0] <== first.out;
    for (var j = 0; j < 13; j++) {
        second.inputs[j + 1] <== inputs[j + 16];
    }

    out <== second.out;
}

template PoseidonChain18() {
    signal input inputs[18];
    signal output out;

    component first = Poseidon(16);
    component second = Poseidon(3);

    for (var i = 0; i < 16; i++) {
        first.inputs[i] <== inputs[i];
    }

    second.inputs[0] <== first.out;
    second.inputs[1] <== inputs[16];
    second.inputs[2] <== inputs[17];

    out <== second.out;
}

template PoseidonChain20() {
    signal input inputs[20];
    signal output out;

    component first = Poseidon(16);
    component second = Poseidon(5);

    for (var i = 0; i < 16; i++) {
        first.inputs[i] <== inputs[i];
    }

    second.inputs[0] <== first.out;
    for (var j = 0; j < 4; j++) {
        second.inputs[j + 1] <== inputs[j + 16];
    }

    out <== second.out;
}
