// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

abstract contract FixtureLoaders is Script {
    using stdJson for string;

    uint256 internal constant DEFAULT_ANVIL_PLAYER1_KEY =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 internal constant DEFAULT_ANVIL_PLAYER2_KEY =
        0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

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
        bytes32 newCommitment;
        bytes32 newEncryptionKeyCommitment;
        bytes32 newCiphertextRef;
    }

    struct PokerShowdownFixture {
        bytes proof;
        bool isTie;
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
        uint256 dealerVisibleValue;
        uint8 handCount;
        uint8 activeHandIndex;
        uint256 payout;
        uint8 immediateResultCode;
        uint256 softMask;
        uint256[4] handValues;
        uint8[4] handStatuses;
        uint8[4] allowedActionMasks;
        uint8[4] handCardCounts;
        uint8[4] handPayoutKinds;
        uint8[8] playerCards;
        uint8[4] dealerCards;
        uint8 dealerRevealMask;
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
        uint256 dealerVisibleValue;
        uint8 handCount;
        uint8 activeHandIndex;
        uint8 nextPhase;
        uint256 softMask;
        uint256[4] handValues;
        uint8[4] handStatuses;
        uint8[4] allowedActionMasks;
        uint8[4] handCardCounts;
        uint8[4] handPayoutKinds;
        uint8[8] playerCards;
        uint8[4] dealerCards;
        uint8 dealerRevealMask;
    }

    struct BlackjackShowdownFixture {
        bytes proof;
        uint256 proofSequence;
        bytes32 playerStateCommitment;
        bytes32 dealerStateCommitment;
        uint256 payout;
        uint256 dealerFinalValue;
        uint8 handCount;
        uint8 activeHandIndex;
        uint8[4] handStatuses;
        uint256[4] handValues;
        uint8[4] handCardCounts;
        uint8[4] handPayoutKinds;
        uint8[8] playerCards;
        uint8[4] dealerCards;
        uint8 dealerRevealMask;
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
        fixture.newCommitment = _bytes32FromString(publicSignals[6]);
        fixture.newEncryptionKeyCommitment = _bytes32FromString(publicSignals[7]);
        fixture.newCiphertextRef = _bytes32FromString(publicSignals[8]);
    }

    function _loadPokerShowdownFixture() internal view returns (PokerShowdownFixture memory fixture) {
        string memory json = vm.readFile(_fixturePath("poker_showdown"));
        string[] memory publicSignals = json.readStringArray(".publicSignals");
        fixture.proof = json.readBytes(".proof");
        fixture.isTie = vm.parseUint(publicSignals[6]) == 1;
    }

    function _loadBlackjackInitialDealFixture() internal view returns (BlackjackInitialDealFixture memory fixture) {
        return _loadBlackjackInitialDealFixture("blackjack_initial_deal");
    }

    function _loadBlackjackInitialDealForSubmission() internal view returns (BlackjackInitialDealFixture memory fixture) {
        string memory payloadPath = vm.envOr("PROOF_PAYLOAD_PATH", string(""));
        if (bytes(payloadPath).length == 0) {
            return _loadBlackjackInitialDealFixture();
        }
        return _loadBlackjackInitialDealPayload(payloadPath);
    }

    function _loadBlackjackInitialDealFixture(string memory name)
        internal
        view
        returns (BlackjackInitialDealFixture memory fixture)
    {
        string memory json = vm.readFile(_fixturePath(name));
        string[] memory publicSignals = json.readStringArray(".publicSignals");
        fixture.proof = json.readBytes(".proof");
        fixture.handNonce = _bytes32FromString(publicSignals[1]);
        fixture.deckCommitment = _bytes32FromString(publicSignals[2]);
        fixture.playerStateCommitment = _bytes32FromString(publicSignals[3]);
        fixture.dealerStateCommitment = _bytes32FromString(publicSignals[4]);
        fixture.playerKeyCommitment = _bytes32FromString(publicSignals[5]);
        fixture.playerCiphertextRef = _bytes32FromString(publicSignals[6]);
        fixture.dealerCiphertextRef = _bytes32FromString(publicSignals[7]);
        fixture.dealerVisibleValue = vm.parseUint(publicSignals[8]);
        fixture.handCount = uint8(vm.parseUint(publicSignals[10]));
        fixture.activeHandIndex = uint8(vm.parseUint(publicSignals[11]));
        fixture.payout = vm.parseUint(publicSignals[12]);
        fixture.immediateResultCode = uint8(vm.parseUint(publicSignals[13]));
        fixture.handValues = _toUint256x4(publicSignals, 14);
        fixture.softMask = vm.parseUint(publicSignals[18]);
        fixture.handStatuses = _toUint8x4(publicSignals, 19);
        fixture.allowedActionMasks = _toUint8x4(publicSignals, 23);
        fixture.handCardCounts = _toUint8x4(publicSignals, 27);
        fixture.handPayoutKinds = _toUint8x4(publicSignals, 31);
        fixture.playerCards = _toUint8x8(publicSignals, 35);
        fixture.dealerCards = _toUint8x4(publicSignals, 43);
        fixture.dealerRevealMask = uint8(vm.parseUint(publicSignals[47]));
    }

    function _loadBlackjackActionFixture() internal view returns (BlackjackActionFixture memory fixture) {
        return _loadBlackjackActionFixture("blackjack_action_resolve");
    }

    function _loadBlackjackActionForSubmission() internal view returns (BlackjackActionFixture memory fixture) {
        string memory payloadPath = vm.envOr("PROOF_PAYLOAD_PATH", string(""));
        if (bytes(payloadPath).length == 0) {
            return _loadBlackjackActionFixture();
        }
        return _loadBlackjackActionPayload(payloadPath);
    }

    function _loadBlackjackActionFixture(string memory name) internal view returns (BlackjackActionFixture memory fixture) {
        string memory json = vm.readFile(_fixturePath(name));
        string[] memory publicSignals = json.readStringArray(".publicSignals");
        fixture.proof = json.readBytes(".proof");
        fixture.proofSequence = vm.parseUint(publicSignals[1]);
        fixture.pendingAction = uint8(vm.parseUint(publicSignals[2]));
        fixture.oldPlayerStateCommitment = _bytes32FromString(publicSignals[3]);
        fixture.newPlayerStateCommitment = _bytes32FromString(publicSignals[4]);
        fixture.dealerStateCommitment = _bytes32FromString(publicSignals[5]);
        fixture.playerKeyCommitment = _bytes32FromString(publicSignals[6]);
        fixture.playerCiphertextRef = _bytes32FromString(publicSignals[7]);
        fixture.dealerCiphertextRef = _bytes32FromString(publicSignals[8]);
        fixture.dealerVisibleValue = vm.parseUint(publicSignals[9]);
        fixture.handCount = uint8(vm.parseUint(publicSignals[10]));
        fixture.activeHandIndex = uint8(vm.parseUint(publicSignals[11]));
        fixture.nextPhase = uint8(vm.parseUint(publicSignals[12]));
        fixture.handValues = _toUint256x4(publicSignals, 13);
        fixture.softMask = vm.parseUint(publicSignals[17]);
        fixture.handStatuses = _toUint8x4(publicSignals, 18);
        fixture.allowedActionMasks = _toUint8x4(publicSignals, 22);
        fixture.handCardCounts = _toUint8x4(publicSignals, 26);
        fixture.handPayoutKinds = _toUint8x4(publicSignals, 30);
        fixture.playerCards = _toUint8x8(publicSignals, 34);
        fixture.dealerCards = _toUint8x4(publicSignals, 42);
        fixture.dealerRevealMask = uint8(vm.parseUint(publicSignals[46]));
    }

    function _loadBlackjackShowdownFixture() internal view returns (BlackjackShowdownFixture memory fixture) {
        return _loadBlackjackShowdownFixture("blackjack_showdown");
    }

    function _loadBlackjackShowdownForSubmission() internal view returns (BlackjackShowdownFixture memory fixture) {
        string memory payloadPath = vm.envOr("PROOF_PAYLOAD_PATH", string(""));
        if (bytes(payloadPath).length == 0) {
            return _loadBlackjackShowdownFixture();
        }
        return _loadBlackjackShowdownPayload(payloadPath);
    }

    function _loadBlackjackShowdownFixture(string memory name)
        internal
        view
        returns (BlackjackShowdownFixture memory fixture)
    {
        string memory json = vm.readFile(_fixturePath(name));
        string[] memory publicSignals = json.readStringArray(".publicSignals");
        fixture.proof = json.readBytes(".proof");
        fixture.proofSequence = vm.parseUint(publicSignals[1]);
        fixture.playerStateCommitment = _bytes32FromString(publicSignals[2]);
        fixture.dealerStateCommitment = _bytes32FromString(publicSignals[3]);
        fixture.payout = vm.parseUint(publicSignals[4]);
        fixture.dealerFinalValue = vm.parseUint(publicSignals[5]);
        fixture.handCount = uint8(vm.parseUint(publicSignals[6]));
        fixture.activeHandIndex = uint8(vm.parseUint(publicSignals[7]));
        fixture.handStatuses = _toUint8x4(publicSignals, 8);
        fixture.handValues = _toUint256x4(publicSignals, 12);
        fixture.handCardCounts = _toUint8x4(publicSignals, 20);
        fixture.handPayoutKinds = _toUint8x4(publicSignals, 24);
        fixture.playerCards = _toUint8x8(publicSignals, 28);
        fixture.dealerCards = _toUint8x4(publicSignals, 36);
        fixture.dealerRevealMask = uint8(vm.parseUint(publicSignals[40]));
    }

    function _loadBlackjackInitialDealPayload(string memory payloadPath)
        internal
        view
        returns (BlackjackInitialDealFixture memory fixture)
    {
        string memory json = vm.readFile(payloadPath);
        fixture.proof = _bytesFromJson(json, ".proof");
        fixture.handNonce = _bytes32FromJson(json, ".handNonce");
        fixture.deckCommitment = _bytes32FromJson(json, ".deckCommitment");
        fixture.playerStateCommitment = _bytes32FromJson(json, ".playerStateCommitment");
        fixture.dealerStateCommitment = _bytes32FromJson(json, ".dealerStateCommitment");
        fixture.playerCiphertextRef = _bytes32FromJson(json, ".playerCiphertextRef");
        fixture.dealerCiphertextRef = _bytes32FromJson(json, ".dealerCiphertextRef");
        fixture.dealerVisibleValue = _uintFromJson(json, ".dealerVisibleValue");
        fixture.handCount = _uint8FromJson(json, ".handCount");
        fixture.activeHandIndex = _uint8FromJson(json, ".activeHandIndex");
        fixture.payout = _uintFromJson(json, ".payout");
        fixture.immediateResultCode = _uint8FromJson(json, ".immediateResultCode");
        fixture.handValues = _toUint256x4FromJson(json, ".handValues");
        fixture.softMask = _uintFromJson(json, ".softMask");
        fixture.handStatuses = _toUint8x4FromJson(json, ".handStatuses");
        fixture.allowedActionMasks = _toUint8x4FromJson(json, ".allowedActionMasks");
        fixture.handCardCounts = _toUint8x4FromJson(json, ".handCardCounts");
        fixture.handPayoutKinds = _toUint8x4FromJson(json, ".handPayoutKinds");
        fixture.playerCards = _toUint8x8FromJson(json, ".playerCards");
        fixture.dealerCards = _toUint8x4FromJson(json, ".dealerCards");
        fixture.dealerRevealMask = _uint8FromJson(json, ".dealerRevealMask");
    }

    function _loadBlackjackActionPayload(string memory payloadPath)
        internal
        view
        returns (BlackjackActionFixture memory fixture)
    {
        string memory json = vm.readFile(payloadPath);
        fixture.proof = _bytesFromJson(json, ".args.proof");
        fixture.newPlayerStateCommitment = _bytes32FromJson(json, ".args.newPlayerStateCommitment");
        fixture.dealerStateCommitment = _bytes32FromJson(json, ".args.dealerStateCommitment");
        fixture.playerCiphertextRef = _bytes32FromJson(json, ".args.playerCiphertextRef");
        fixture.dealerCiphertextRef = _bytes32FromJson(json, ".args.dealerCiphertextRef");
        fixture.dealerVisibleValue = _uintFromJson(json, ".args.dealerVisibleValue");
        fixture.handCount = _uint8FromJson(json, ".args.handCount");
        fixture.activeHandIndex = _uint8FromJson(json, ".args.activeHandIndex");
        fixture.nextPhase = _uint8FromJson(json, ".args.nextPhase");
        fixture.handValues = _toUint256x4FromJson(json, ".args.handValues");
        fixture.softMask = _uintFromJson(json, ".args.softMask");
        fixture.handStatuses = _toUint8x4FromJson(json, ".args.handStatuses");
        fixture.allowedActionMasks = _toUint8x4FromJson(json, ".args.allowedActionMasks");
        fixture.handCardCounts = _toUint8x4FromJson(json, ".args.handCardCounts");
        fixture.handPayoutKinds = _toUint8x4FromJson(json, ".args.handPayoutKinds");
        fixture.playerCards = _toUint8x8FromJson(json, ".args.playerCards");
        fixture.dealerCards = _toUint8x4FromJson(json, ".args.dealerCards");
        fixture.dealerRevealMask = _uint8FromJson(json, ".args.dealerRevealMask");
    }

    function _loadBlackjackShowdownPayload(string memory payloadPath)
        internal
        view
        returns (BlackjackShowdownFixture memory fixture)
    {
        string memory json = vm.readFile(payloadPath);
        fixture.proof = _bytesFromJson(json, ".args.proof");
        fixture.playerStateCommitment = _bytes32FromJson(json, ".args.playerStateCommitment");
        fixture.dealerStateCommitment = _bytes32FromJson(json, ".args.dealerStateCommitment");
        fixture.payout = _uintFromJson(json, ".args.payout");
        fixture.dealerFinalValue = _uintFromJson(json, ".args.dealerFinalValue");
        fixture.handCount = _uint8FromJson(json, ".args.handCount");
        fixture.activeHandIndex = _uint8FromJson(json, ".args.activeHandIndex");
        fixture.handStatuses = _toUint8x4FromJson(json, ".args.handStatuses");
        fixture.handValues = _toUint256x4FromJson(json, ".args.handValues");
        fixture.handCardCounts = _toUint8x4FromJson(json, ".args.handCardCounts");
        fixture.handPayoutKinds = _toUint8x4FromJson(json, ".args.handPayoutKinds");
        fixture.playerCards = _toUint8x8FromJson(json, ".args.playerCards");
        fixture.dealerCards = _toUint8x4FromJson(json, ".args.dealerCards");
        fixture.dealerRevealMask = _uint8FromJson(json, ".args.dealerRevealMask");
    }

    function _fixturePath(string memory name) internal view returns (string memory) {
        return string.concat(vm.projectRoot(), "/zk/fixtures/generated/", name, ".json");
    }

    function _bytes32FromString(string memory value) internal pure returns (bytes32) {
        if (_isHexString(value)) {
            return vm.parseBytes32(value);
        }
        return bytes32(vm.parseUint(value));
    }

    function _bytes32FromJson(string memory json, string memory path) internal pure returns (bytes32) {
        return _bytes32FromString(json.readString(path));
    }

    function _bytesFromJson(string memory json, string memory path) internal pure returns (bytes memory) {
        return vm.parseBytes(json.readString(path));
    }

    function _uintFromJson(string memory json, string memory path) internal pure returns (uint256) {
        return vm.parseUint(json.readString(path));
    }

    function _uint8FromJson(string memory json, string memory path) internal pure returns (uint8) {
        return uint8(_uintFromJson(json, path));
    }

    function _toUint256x4(string[] memory values, uint256 offset) internal pure returns (uint256[4] memory out) {
        for (uint256 i = 0; i < 4; i++) {
            out[i] = vm.parseUint(values[offset + i]);
        }
    }

    function _toUint8x4(string[] memory values, uint256 offset) internal pure returns (uint8[4] memory out) {
        for (uint256 i = 0; i < 4; i++) {
            out[i] = uint8(vm.parseUint(values[offset + i]));
        }
    }

    function _toUint8x8(string[] memory values, uint256 offset) internal pure returns (uint8[8] memory out) {
        for (uint256 i = 0; i < 8; i++) {
            out[i] = uint8(vm.parseUint(values[offset + i]));
        }
    }

    function _toUint256x4FromJson(string memory json, string memory path) internal pure returns (uint256[4] memory out) {
        string[] memory values = json.readStringArray(path);
        for (uint256 i = 0; i < 4; i++) {
            out[i] = vm.parseUint(values[i]);
        }
    }

    function _toUint8x4FromJson(string memory json, string memory path) internal pure returns (uint8[4] memory out) {
        string[] memory values = json.readStringArray(path);
        for (uint256 i = 0; i < 4; i++) {
            out[i] = uint8(vm.parseUint(values[i]));
        }
    }

    function _toUint8x8FromJson(string memory json, string memory path) internal pure returns (uint8[8] memory out) {
        string[] memory values = json.readStringArray(path);
        for (uint256 i = 0; i < 8; i++) {
            out[i] = uint8(vm.parseUint(values[i]));
        }
    }

    function _isHexString(string memory value) private pure returns (bool) {
        bytes memory raw = bytes(value);
        return raw.length >= 2 && raw[0] == "0" && (raw[1] == "x" || raw[1] == "X");
    }
}
