// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import {BlackjackEngine} from "../../src/engines/BlackjackEngine.sol";

abstract contract ZkFixtureLoader is Test {
    using stdJson for string;

    struct PokerInitialDealFixture {
        bytes proof;
        bytes32 handNonce;
        bytes32 deckCommitment;
        bytes32[2] handCommitments;
        bytes32[2] encryptionKeyCommitments;
        bytes32[2] ciphertextRefs;
    }

    struct PokerDrawFixture {
        bytes proof;
        uint256 playerIndex;
        uint8 discardMask;
        uint256 proofSequence;
        bytes32 oldCommitment;
        bytes32 newCommitment;
        bytes32 newEncryptionKeyCommitment;
        bytes32 newCiphertextRef;
    }

    struct PokerShowdownFixture {
        bytes proof;
        uint256 winnerIndex;
        bool isTie;
    }

    struct BlackjackHandFixture {
        uint256 wager;
        uint256 value;
        uint8 status;
        uint8 allowedActionMask;
        uint8 cardCount;
        uint8 cardStartIndex;
        uint8 payoutKind;
    }

    struct BlackjackPublicStateFixture {
        uint8 phase;
        uint8 decisionType;
        uint8 dealerRevealMask;
        uint8 handCount;
        uint8 activeHandIndex;
        uint8 peekAvailable;
        uint8 peekResolved;
        uint8 dealerHasBlackjack;
        uint8 insuranceAvailable;
        uint8 insuranceStatus;
        uint8 surrenderAvailable;
        uint8 surrenderStatus;
        uint256 dealerUpValue;
        uint256 dealerFinalValue;
        uint256 payout;
        uint256 insuranceStake;
        uint256 insurancePayout;
        BlackjackHandFixture[4] hands;
        uint8[] playerCards;
        uint8[] dealerCards;
    }

    struct BlackjackInitialDealFixture {
        bytes proof;
        bytes32 handNonce;
        bytes32 deckCommitment;
        bytes32 playerStateCommitment;
        bytes32 dealerStateCommitment;
        bytes32 playerKeyCommitment;
        bytes32 playerCiphertextRef;
        bytes32 dealerCiphertextRef;
        BlackjackPublicStateFixture publicState;
    }

    struct BlackjackPeekFixture {
        bytes proof;
        uint256 proofSequence;
        bytes32 playerStateCommitment;
        bytes32 dealerStateCommitment;
        bytes32 playerKeyCommitment;
        bytes32 playerCiphertextRef;
        bytes32 dealerCiphertextRef;
        BlackjackPublicStateFixture publicState;
    }

    struct BlackjackActionFixture {
        bytes proof;
        uint256 proofSequence;
        uint8 pendingAction;
        bytes32 oldPlayerStateCommitment;
        bytes32 newPlayerStateCommitment;
        bytes32 dealerStateCommitment;
        bytes32 playerKeyCommitment;
        bytes32 playerCiphertextRef;
        bytes32 dealerCiphertextRef;
        BlackjackPublicStateFixture publicState;
    }

    struct BlackjackShowdownFixture {
        bytes proof;
        uint256 proofSequence;
        bytes32 playerStateCommitment;
        bytes32 dealerStateCommitment;
        bytes32 playerKeyCommitment;
        BlackjackPublicStateFixture publicState;
    }

    function _loadPokerInitialDealFixture() internal view returns (PokerInitialDealFixture memory fixture) {
        string memory json = vm.readFile(_fixturePath("poker_initial_deal"));
        string[] memory publicSignals = json.readStringArray(".publicSignals");

        fixture.proof = json.readBytes(".proof");
        fixture.handNonce = _bytes32FromString(publicSignals[2]);
        fixture.deckCommitment = _bytes32FromString(publicSignals[3]);
        fixture.handCommitments[0] = _bytes32FromString(publicSignals[4]);
        fixture.handCommitments[1] = _bytes32FromString(publicSignals[5]);
        fixture.encryptionKeyCommitments[0] = _bytes32FromString(publicSignals[6]);
        fixture.encryptionKeyCommitments[1] = _bytes32FromString(publicSignals[7]);
        fixture.ciphertextRefs[0] = _bytes32FromString(publicSignals[8]);
        fixture.ciphertextRefs[1] = _bytes32FromString(publicSignals[9]);
    }

    function _loadPokerDrawFixture(string memory name) internal view returns (PokerDrawFixture memory fixture) {
        string memory json = vm.readFile(_fixturePath(name));
        string[] memory publicSignals = json.readStringArray(".publicSignals");

        fixture.proof = json.readBytes(".proof");
        fixture.playerIndex = vm.parseUint(publicSignals[3]);
        fixture.oldCommitment = _bytes32FromString(publicSignals[5]);
        fixture.newCommitment = _bytes32FromString(publicSignals[6]);
        fixture.newEncryptionKeyCommitment = _bytes32FromString(publicSignals[7]);
        fixture.newCiphertextRef = _bytes32FromString(publicSignals[8]);
        fixture.discardMask = uint8(vm.parseUint(publicSignals[9]));
        fixture.proofSequence = vm.parseUint(publicSignals[10]);
    }

    function _loadPokerShowdownFixture(string memory name) internal view returns (PokerShowdownFixture memory fixture) {
        string memory json = vm.readFile(_fixturePath(name));
        string[] memory publicSignals = json.readStringArray(".publicSignals");

        fixture.proof = json.readBytes(".proof");
        fixture.winnerIndex = vm.parseUint(publicSignals[5]);
        fixture.isTie = vm.parseUint(publicSignals[6]) == 1;
    }

    function _loadBlackjackInitialDealFixture() internal view returns (BlackjackInitialDealFixture memory fixture) {
        return _loadBlackjackInitialDealFixture("blackjack_initial_deal");
    }

    function _loadBlackjackInitialDealFixture(string memory name)
        internal
        view
        returns (BlackjackInitialDealFixture memory fixture)
    {
        string memory json = vm.readFile(_fixturePath(name));
        fixture.proof = json.readBytes(".proof");
        fixture.handNonce = bytes32(vm.parseUint(json.readString(".input.handNonce")));
        fixture.deckCommitment = bytes32(vm.parseUint(json.readString(".input.deckCommitment")));
        fixture.playerStateCommitment = bytes32(vm.parseUint(json.readString(".input.playerStateCommitment")));
        fixture.dealerStateCommitment = bytes32(vm.parseUint(json.readString(".input.dealerStateCommitment")));
        fixture.playerKeyCommitment = bytes32(vm.parseUint(json.readString(".input.playerKeyCommitment")));
        fixture.playerCiphertextRef = bytes32(vm.parseUint(json.readString(".input.playerCiphertextRef")));
        fixture.dealerCiphertextRef = bytes32(vm.parseUint(json.readString(".input.dealerCiphertextRef")));
        fixture.publicState = _readBlackjackPublicState(json, ".input.publicState");
    }

    function _loadBlackjackPeekFixture() internal view returns (BlackjackPeekFixture memory fixture) {
        return _loadBlackjackPeekFixture("blackjack_peek");
    }

    function _loadBlackjackPeekFixture(string memory name) internal view returns (BlackjackPeekFixture memory fixture) {
        string memory json = vm.readFile(_fixturePath(name));

        fixture.proof = json.readBytes(".proof");
        fixture.proofSequence = vm.parseUint(json.readString(".input.proofSequence"));
        fixture.playerStateCommitment = bytes32(vm.parseUint(json.readString(".input.playerStateCommitment")));
        fixture.dealerStateCommitment = bytes32(vm.parseUint(json.readString(".input.dealerStateCommitment")));
        fixture.playerKeyCommitment = bytes32(vm.parseUint(json.readString(".input.playerKeyCommitment")));
        fixture.playerCiphertextRef = bytes32(vm.parseUint(json.readString(".input.playerCiphertextRef")));
        fixture.dealerCiphertextRef = bytes32(vm.parseUint(json.readString(".input.dealerCiphertextRef")));
        fixture.publicState = _readBlackjackPublicState(json, ".input.publicState");
    }

    function _loadBlackjackActionFixture() internal view returns (BlackjackActionFixture memory fixture) {
        return _loadBlackjackActionFixture("blackjack_action_resolve");
    }

    function _loadBlackjackActionFixture(string memory name) internal view returns (BlackjackActionFixture memory fixture) {
        string memory json = vm.readFile(_fixturePath(name));

        fixture.proof = json.readBytes(".proof");
        fixture.proofSequence = vm.parseUint(json.readString(".input.proofSequence"));
        fixture.pendingAction = uint8(vm.parseUint(json.readString(".input.pendingAction")));
        fixture.oldPlayerStateCommitment = bytes32(vm.parseUint(json.readString(".input.oldPlayerStateCommitment")));
        fixture.newPlayerStateCommitment = bytes32(vm.parseUint(json.readString(".input.newPlayerStateCommitment")));
        fixture.dealerStateCommitment = bytes32(vm.parseUint(json.readString(".input.dealerStateCommitment")));
        fixture.playerKeyCommitment = bytes32(vm.parseUint(json.readString(".input.playerKeyCommitment")));
        fixture.playerCiphertextRef = bytes32(vm.parseUint(json.readString(".input.playerCiphertextRef")));
        fixture.dealerCiphertextRef = bytes32(vm.parseUint(json.readString(".input.dealerCiphertextRef")));
        fixture.publicState = _readBlackjackPublicState(json, ".input.publicState");
    }

    function _loadBlackjackShowdownFixture() internal view returns (BlackjackShowdownFixture memory fixture) {
        return _loadBlackjackShowdownFixture("blackjack_showdown");
    }

    function _loadBlackjackShowdownFixture(string memory name)
        internal
        view
        returns (BlackjackShowdownFixture memory fixture)
    {
        string memory json = vm.readFile(_fixturePath(name));

        fixture.proof = json.readBytes(".proof");
        fixture.proofSequence = vm.parseUint(json.readString(".input.proofSequence"));
        fixture.playerStateCommitment = bytes32(vm.parseUint(json.readString(".input.playerStateCommitment")));
        fixture.dealerStateCommitment = bytes32(vm.parseUint(json.readString(".input.dealerStateCommitment")));
        fixture.playerKeyCommitment = bytes32(vm.parseUint(json.readString(".input.playerKeyCommitment")));
        fixture.publicState = _readBlackjackPublicState(json, ".input.publicState");
    }

    function _corruptProof(bytes memory proof) internal pure returns (bytes memory) {
        bytes memory mutated = bytes.concat(proof);
        mutated[mutated.length - 1] = bytes1(uint8(mutated[mutated.length - 1]) ^ 0x01);
        return mutated;
    }

    function _fixturePath(string memory name) private view returns (string memory) {
        return string.concat(vm.projectRoot(), "/zk/fixtures/generated/", name, ".json");
    }

    function _bytes32FromString(string memory value) private pure returns (bytes32) {
        return bytes32(vm.parseUint(value));
    }

    function _readBlackjackPublicState(string memory json, string memory prefix)
        private
        view
        returns (BlackjackPublicStateFixture memory fixture)
    {
        fixture.phase = uint8(vm.parseUint(json.readString(string.concat(prefix, ".phase"))));
        fixture.decisionType = uint8(vm.parseUint(json.readString(string.concat(prefix, ".decisionType"))));
        fixture.dealerRevealMask = uint8(vm.parseUint(json.readString(string.concat(prefix, ".dealerRevealMask"))));
        fixture.handCount = uint8(vm.parseUint(json.readString(string.concat(prefix, ".handCount"))));
        fixture.activeHandIndex = uint8(vm.parseUint(json.readString(string.concat(prefix, ".activeHandIndex"))));
        fixture.peekAvailable = uint8(vm.parseUint(json.readString(string.concat(prefix, ".peekAvailable"))));
        fixture.peekResolved = uint8(vm.parseUint(json.readString(string.concat(prefix, ".peekResolved"))));
        fixture.dealerHasBlackjack = uint8(vm.parseUint(json.readString(string.concat(prefix, ".dealerHasBlackjack"))));
        fixture.insuranceAvailable = uint8(vm.parseUint(json.readString(string.concat(prefix, ".insuranceAvailable"))));
        fixture.insuranceStatus = uint8(vm.parseUint(json.readString(string.concat(prefix, ".insuranceStatus"))));
        fixture.surrenderAvailable = uint8(vm.parseUint(json.readString(string.concat(prefix, ".surrenderAvailable"))));
        fixture.surrenderStatus = uint8(vm.parseUint(json.readString(string.concat(prefix, ".surrenderStatus"))));
        fixture.dealerUpValue = vm.parseUint(json.readString(string.concat(prefix, ".dealerUpValue")));
        fixture.dealerFinalValue = vm.parseUint(json.readString(string.concat(prefix, ".dealerFinalValue")));
        fixture.payout = vm.parseUint(json.readString(string.concat(prefix, ".payout")));
        fixture.insuranceStake = vm.parseUint(json.readString(string.concat(prefix, ".insuranceStake")));
        fixture.insurancePayout = vm.parseUint(json.readString(string.concat(prefix, ".insurancePayout")));
        for (uint256 i = 0; i < 4; i++) {
            string memory handPrefix = string.concat(prefix, ".hands[", vm.toString(i), "]");
            fixture.hands[i].wager = vm.parseUint(json.readString(string.concat(handPrefix, ".wager")));
            fixture.hands[i].value = vm.parseUint(json.readString(string.concat(handPrefix, ".value")));
            fixture.hands[i].status = uint8(vm.parseUint(json.readString(string.concat(handPrefix, ".status"))));
            fixture.hands[i].allowedActionMask =
                uint8(vm.parseUint(json.readString(string.concat(handPrefix, ".allowedActionMask"))));
            fixture.hands[i].cardCount = uint8(vm.parseUint(json.readString(string.concat(handPrefix, ".cardCount"))));
            fixture.hands[i].cardStartIndex =
                uint8(vm.parseUint(json.readString(string.concat(handPrefix, ".cardStartIndex"))));
            fixture.hands[i].payoutKind = uint8(vm.parseUint(json.readString(string.concat(handPrefix, ".payoutKind"))));
        }

        string[] memory playerCards = json.readStringArray(string.concat(prefix, ".playerCards"));
        string[] memory dealerCards = json.readStringArray(string.concat(prefix, ".dealerCards"));
        fixture.playerCards = _toDynamicUint8(playerCards);
        fixture.dealerCards = _toDynamicUint8(dealerCards);
    }

    function _toBlackjackPublicState(BlackjackPublicStateFixture memory fixture)
        internal
        pure
        returns (BlackjackEngine.PublicSessionState memory state)
    {
        state.phase = fixture.phase;
        state.decisionType = fixture.decisionType;
        state.dealerRevealMask = fixture.dealerRevealMask;
        state.handCount = fixture.handCount;
        state.activeHandIndex = fixture.activeHandIndex;
        state.peekAvailable = fixture.peekAvailable;
        state.peekResolved = fixture.peekResolved;
        state.dealerHasBlackjack = fixture.dealerHasBlackjack;
        state.insuranceAvailable = fixture.insuranceAvailable;
        state.insuranceStatus = fixture.insuranceStatus;
        state.surrenderAvailable = fixture.surrenderAvailable;
        state.surrenderStatus = fixture.surrenderStatus;
        state.dealerUpValue = fixture.dealerUpValue;
        state.dealerFinalValue = fixture.dealerFinalValue;
        state.payout = fixture.payout;
        state.insuranceStake = fixture.insuranceStake;
        state.insurancePayout = fixture.insurancePayout;
        for (uint256 i = 0; i < 4; i++) {
            state.hands[i] = BlackjackEngine.HandView({
                wager: fixture.hands[i].wager,
                value: fixture.hands[i].value,
                status: fixture.hands[i].status,
                allowedActionMask: fixture.hands[i].allowedActionMask,
                cardCount: fixture.hands[i].cardCount,
                cardStartIndex: fixture.hands[i].cardStartIndex,
                payoutKind: fixture.hands[i].payoutKind
            });
        }
        state.playerCards = fixture.playerCards;
        state.dealerCards = fixture.dealerCards;
    }

    function _toUint256x4(string[] memory values, uint256 offset) private pure returns (uint256[4] memory out) {
        for (uint256 i = 0; i < 4; i++) {
            out[i] = vm.parseUint(values[offset + i]);
        }
    }

    function _toUint8x4(string[] memory values, uint256 offset) private pure returns (uint8[4] memory out) {
        for (uint256 i = 0; i < 4; i++) {
            out[i] = uint8(vm.parseUint(values[offset + i]));
        }
    }

    function _toUint8x8(string[] memory values, uint256 offset) private pure returns (uint8[8] memory out) {
        for (uint256 i = 0; i < 8; i++) {
            out[i] = uint8(vm.parseUint(values[offset + i]));
        }
    }

    function _toDynamicUint8(string[] memory values) private pure returns (uint8[] memory out) {
        out = new uint8[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            out[i] = uint8(vm.parseUint(values[i]));
        }
    }
}
