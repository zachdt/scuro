// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {BlackjackEngine} from "../../src/engines/BlackjackEngine.sol";

abstract contract FixtureLoaders is Script {
    using stdJson for string;

    uint8 internal constant BLACKJACK_CARD_EMPTY = 104;

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

    struct BlackjackInitialDealSubmission {
        bytes proof;
        bytes32 handNonce;
        bytes32 deckCommitment;
        bytes32 playerStateCommitment;
        bytes32 dealerStateCommitment;
        bytes32 playerCiphertextRef;
        bytes32 dealerCiphertextRef;
        BlackjackEngine.PublicSessionState publicState;
    }

    struct BlackjackPeekSubmission {
        bytes proof;
        bytes32 playerStateCommitment;
        bytes32 dealerStateCommitment;
        bytes32 playerCiphertextRef;
        bytes32 dealerCiphertextRef;
        BlackjackEngine.PublicSessionState publicState;
    }

    struct BlackjackActionSubmission {
        bytes proof;
        bytes32 newPlayerStateCommitment;
        bytes32 dealerStateCommitment;
        bytes32 playerCiphertextRef;
        bytes32 dealerCiphertextRef;
        BlackjackEngine.PublicSessionState publicState;
    }

    struct BlackjackShowdownSubmission {
        bytes proof;
        bytes32 playerStateCommitment;
        bytes32 dealerStateCommitment;
        BlackjackEngine.PublicSessionState publicState;
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

    function _loadBlackjackInitialDealSubmission() internal view returns (BlackjackInitialDealSubmission memory submission) {
        string memory payloadPath = vm.envOr("PROOF_PAYLOAD_PATH", string(""));
        if (bytes(payloadPath).length == 0) {
            BlackjackInitialDealFixture memory fixture = _loadBlackjackInitialDealFixture();
            submission.proof = fixture.proof;
            submission.handNonce = fixture.handNonce;
            submission.deckCommitment = fixture.deckCommitment;
            submission.playerStateCommitment = fixture.playerStateCommitment;
            submission.dealerStateCommitment = fixture.dealerStateCommitment;
            submission.playerCiphertextRef = fixture.playerCiphertextRef;
            submission.dealerCiphertextRef = fixture.dealerCiphertextRef;
            submission.publicState = _legacyInitialState(fixture);
            return submission;
        }
        return _loadBlackjackInitialDealSubmissionPayload(payloadPath);
    }

    function _loadBlackjackInitialDealFixture(string memory name)
        internal
        view
        returns (BlackjackInitialDealFixture memory fixture)
    {
        string memory json = vm.readFile(_fixturePath(name));
        fixture.proof = json.readBytes(".proof");
        fixture.handNonce = _bytes32FromJson(json, ".input.handNonce");
        fixture.deckCommitment = _bytes32FromJson(json, ".input.deckCommitment");
        fixture.playerStateCommitment = _bytes32FromJson(json, ".input.playerStateCommitment");
        fixture.dealerStateCommitment = _bytes32FromJson(json, ".input.dealerStateCommitment");
        fixture.playerKeyCommitment = _bytes32FromJson(json, ".input.playerKeyCommitment");
        fixture.playerCiphertextRef = _bytes32FromJson(json, ".input.playerCiphertextRef");
        fixture.dealerCiphertextRef = _bytes32FromJson(json, ".input.dealerCiphertextRef");
        fixture.dealerVisibleValue = _uintFromJson(json, ".input.dealerUpValue");
        fixture.handCount = _uint8FromJson(json, ".input.handCount");
        fixture.activeHandIndex = _uint8FromJson(json, ".input.activeHandIndex");
        fixture.payout = _uintFromJson(json, ".input.payout");
        fixture.immediateResultCode = 0; // Not used in new engine
        fixture.handValues = _toUint256x4FromJson(json, ".input.handValues");
        fixture.handStatuses = _toUint8x4FromJson(json, ".input.handStatuses");
        fixture.allowedActionMasks = _toUint8x4FromJson(json, ".input.allowedActionMasks");
        fixture.handCardCounts = _toUint8x4FromJson(json, ".input.handCardCounts");
        fixture.handPayoutKinds = _toUint8x4FromJson(json, ".input.handPayoutKinds");
        fixture.playerCards = _toUint8x8FromJson(json, ".input.playerCards");
        fixture.dealerCards = _toUint8x4FromJson(json, ".input.dealerCards");
        fixture.dealerRevealMask = _uint8FromJson(json, ".input.dealerRevealMask");
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

    function _loadBlackjackPeekSubmission() internal view returns (BlackjackPeekSubmission memory submission) {
        string memory payloadPath = vm.envOr("PROOF_PAYLOAD_PATH", string(""));
        if (bytes(payloadPath).length == 0) {
            return _loadBlackjackPeekSubmissionPayload(_fixturePath("blackjack_peek"));
        }
        return _loadBlackjackPeekSubmissionPayload(payloadPath);
    }

    function _loadBlackjackActionSubmission() internal view returns (BlackjackActionSubmission memory submission) {
        string memory payloadPath = vm.envOr("PROOF_PAYLOAD_PATH", string(""));
        if (bytes(payloadPath).length == 0) {
            BlackjackActionFixture memory fixture = _loadBlackjackActionFixture();
            submission.proof = fixture.proof;
            submission.newPlayerStateCommitment = fixture.newPlayerStateCommitment;
            submission.dealerStateCommitment = fixture.dealerStateCommitment;
            submission.playerCiphertextRef = fixture.playerCiphertextRef;
            submission.dealerCiphertextRef = fixture.dealerCiphertextRef;
            submission.publicState = _legacyActionState(fixture);
            return submission;
        }
        return _loadBlackjackActionSubmissionPayload(payloadPath);
    }

    function _loadBlackjackActionFixture(string memory name) internal view returns (BlackjackActionFixture memory fixture) {
        string memory json = vm.readFile(_fixturePath(name));
        fixture.proof = json.readBytes(".proof");
        fixture.proofSequence = _uintFromJson(json, ".input.proofSequence");
        fixture.pendingAction = _uint8FromJson(json, ".input.pendingAction");
        fixture.oldPlayerStateCommitment = _bytes32FromJson(json, ".input.oldPlayerStateCommitment");
        fixture.newPlayerStateCommitment = _bytes32FromJson(json, ".input.newPlayerStateCommitment");
        fixture.dealerStateCommitment = _bytes32FromJson(json, ".input.dealerStateCommitment");
        fixture.playerKeyCommitment = _bytes32FromJson(json, ".input.playerKeyCommitment");
        fixture.playerCiphertextRef = _bytes32FromJson(json, ".input.playerCiphertextRef");
        fixture.dealerCiphertextRef = _bytes32FromJson(json, ".input.dealerCiphertextRef");
        fixture.dealerVisibleValue = _uintFromJson(json, ".input.dealerUpValue");
        fixture.handCount = _uint8FromJson(json, ".input.handCount");
        fixture.activeHandIndex = _uint8FromJson(json, ".input.activeHandIndex");
        fixture.nextPhase = _uint8FromJson(json, ".input.phase");
        fixture.handValues = _toUint256x4FromJson(json, ".input.handValues");
        fixture.handStatuses = _toUint8x4FromJson(json, ".input.handStatuses");
        fixture.allowedActionMasks = _toUint8x4FromJson(json, ".input.allowedActionMasks");
        fixture.handCardCounts = _toUint8x4FromJson(json, ".input.handCardCounts");
        fixture.handPayoutKinds = _toUint8x4FromJson(json, ".input.handPayoutKinds");
        fixture.playerCards = _toUint8x8FromJson(json, ".input.playerCards");
        fixture.dealerCards = _toUint8x4FromJson(json, ".input.dealerCards");
        fixture.dealerRevealMask = _uint8FromJson(json, ".input.dealerRevealMask");
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

    function _loadBlackjackShowdownSubmission() internal view returns (BlackjackShowdownSubmission memory submission) {
        string memory payloadPath = vm.envOr("PROOF_PAYLOAD_PATH", string(""));
        if (bytes(payloadPath).length == 0) {
            BlackjackShowdownFixture memory fixture = _loadBlackjackShowdownFixture();
            submission.proof = fixture.proof;
            submission.playerStateCommitment = fixture.playerStateCommitment;
            submission.dealerStateCommitment = fixture.dealerStateCommitment;
            submission.publicState = _legacyShowdownState(fixture);
            return submission;
        }
        return _loadBlackjackShowdownSubmissionPayload(payloadPath);
    }

    function _loadBlackjackShowdownFixture(string memory name)
        internal
        view
        returns (BlackjackShowdownFixture memory fixture)
    {
        string memory json = vm.readFile(_fixturePath(name));
        fixture.proof = json.readBytes(".proof");
        fixture.proofSequence = _uintFromJson(json, ".input.proofSequence");
        fixture.playerStateCommitment = _bytes32FromJson(json, ".input.playerStateCommitment");
        fixture.dealerStateCommitment = _bytes32FromJson(json, ".input.dealerStateCommitment");
        fixture.payout = _uintFromJson(json, ".input.payout");
        fixture.dealerFinalValue = _uintFromJson(json, ".input.dealerFinalValue");
        fixture.handCount = _uint8FromJson(json, ".input.handCount");
        fixture.activeHandIndex = _uint8FromJson(json, ".input.activeHandIndex");
        fixture.handStatuses = _toUint8x4FromJson(json, ".input.handStatuses");
        fixture.handValues = _toUint256x4FromJson(json, ".input.handValues");
        fixture.handCardCounts = _toUint8x4FromJson(json, ".input.handCardCounts");
        fixture.handPayoutKinds = _toUint8x4FromJson(json, ".input.handPayoutKinds");
        fixture.playerCards = _toUint8x8FromJson(json, ".input.playerCards");
        fixture.dealerCards = _toUint8x4FromJson(json, ".input.dealerCards");
        fixture.dealerRevealMask = _uint8FromJson(json, ".input.dealerRevealMask");
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

    function _loadBlackjackInitialDealSubmissionPayload(string memory payloadPath)
        internal
        view
        returns (BlackjackInitialDealSubmission memory submission)
    {
        string memory json = vm.readFile(payloadPath);
        submission.proof = _bytesFromJson(json, ".proof");
        submission.handNonce = _bytes32FromJson(json, ".handNonce");
        submission.deckCommitment = _bytes32FromJson(json, ".deckCommitment");
        submission.playerStateCommitment = _bytes32FromJson(json, ".playerStateCommitment");
        submission.dealerStateCommitment = _bytes32FromJson(json, ".dealerStateCommitment");
        submission.playerCiphertextRef = _bytes32FromJson(json, ".playerCiphertextRef");
        submission.dealerCiphertextRef = _bytes32FromJson(json, ".dealerCiphertextRef");
        submission.publicState = _readBlackjackPublicState(json, ".publicState");
    }

    function _loadBlackjackPeekSubmissionPayload(string memory payloadPath)
        internal
        view
        returns (BlackjackPeekSubmission memory submission)
    {
        string memory json = vm.readFile(payloadPath);
        submission.proof = _bytesFromJson(json, ".proof");
        submission.playerStateCommitment = _bytes32FromJson(json, ".args.playerStateCommitment");
        submission.dealerStateCommitment = _bytes32FromJson(json, ".args.dealerStateCommitment");
        submission.playerCiphertextRef = _bytes32FromJson(json, ".args.playerCiphertextRef");
        submission.dealerCiphertextRef = _bytes32FromJson(json, ".args.dealerCiphertextRef");
        submission.publicState = _readBlackjackPublicState(json, ".args.publicState");
    }

    function _loadBlackjackActionSubmissionPayload(string memory payloadPath)
        internal
        view
        returns (BlackjackActionSubmission memory submission)
    {
        string memory json = vm.readFile(payloadPath);
        submission.proof = _bytesFromJson(json, ".proof");
        submission.newPlayerStateCommitment = _bytes32FromJson(json, ".args.newPlayerStateCommitment");
        submission.dealerStateCommitment = _bytes32FromJson(json, ".args.dealerStateCommitment");
        submission.playerCiphertextRef = _bytes32FromJson(json, ".args.playerCiphertextRef");
        submission.dealerCiphertextRef = _bytes32FromJson(json, ".args.dealerCiphertextRef");
        submission.publicState = _readBlackjackPublicState(json, ".args.publicState");
    }

    function _loadBlackjackShowdownSubmissionPayload(string memory payloadPath)
        internal
        view
        returns (BlackjackShowdownSubmission memory submission)
    {
        string memory json = vm.readFile(payloadPath);
        submission.proof = _bytesFromJson(json, ".proof");
        submission.playerStateCommitment = _bytes32FromJson(json, ".args.playerStateCommitment");
        submission.dealerStateCommitment = _bytes32FromJson(json, ".args.dealerStateCommitment");
        submission.publicState = _readBlackjackPublicState(json, ".args.publicState");
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

    function _readBlackjackPublicState(string memory json, string memory prefix)
        internal
        pure
        returns (BlackjackEngine.PublicSessionState memory state)
    {
        state.phase = _uint8FromJson(json, string.concat(prefix, ".phase"));
        state.decisionType = _uint8FromJson(json, string.concat(prefix, ".decisionType"));
        state.dealerRevealMask = _uint8FromJson(json, string.concat(prefix, ".dealerRevealMask"));
        state.handCount = _uint8FromJson(json, string.concat(prefix, ".handCount"));
        state.activeHandIndex = _uint8FromJson(json, string.concat(prefix, ".activeHandIndex"));
        state.peekAvailable = _uint8FromJson(json, string.concat(prefix, ".peekAvailable"));
        state.peekResolved = _uint8FromJson(json, string.concat(prefix, ".peekResolved"));
        state.dealerHasBlackjack = _uint8FromJson(json, string.concat(prefix, ".dealerHasBlackjack"));
        state.insuranceAvailable = _uint8FromJson(json, string.concat(prefix, ".insuranceAvailable"));
        state.insuranceStatus = _uint8FromJson(json, string.concat(prefix, ".insuranceStatus"));
        state.surrenderAvailable = _uint8FromJson(json, string.concat(prefix, ".surrenderAvailable"));
        state.surrenderStatus = _uint8FromJson(json, string.concat(prefix, ".surrenderStatus"));
        state.dealerUpValue = _uintFromJson(json, string.concat(prefix, ".dealerUpValue"));
        state.dealerFinalValue = _uintFromJson(json, string.concat(prefix, ".dealerFinalValue"));
        state.payout = _uintFromJson(json, string.concat(prefix, ".payout"));
        state.insuranceStake = _uintFromJson(json, string.concat(prefix, ".insuranceStake"));
        state.insurancePayout = _uintFromJson(json, string.concat(prefix, ".insurancePayout"));

        for (uint256 i = 0; i < 4; i++) {
            string memory handPrefix = string.concat(prefix, ".hands[", vm.toString(i), "]");
            state.hands[i] = BlackjackEngine.HandView({
                wager: _uintFromJson(json, string.concat(handPrefix, ".wager")),
                value: _uintFromJson(json, string.concat(handPrefix, ".value")),
                status: _uint8FromJson(json, string.concat(handPrefix, ".status")),
                allowedActionMask: _uint8FromJson(json, string.concat(handPrefix, ".allowedActionMask")),
                cardCount: _uint8FromJson(json, string.concat(handPrefix, ".cardCount")),
                cardStartIndex: _uint8FromJson(json, string.concat(handPrefix, ".cardStartIndex")),
                payoutKind: _uint8FromJson(json, string.concat(handPrefix, ".payoutKind"))
            });
        }

        state.playerCards = _toDynamicUint8FromJson(json, string.concat(prefix, ".playerCards"));
        state.dealerCards = _toDynamicUint8FromJson(json, string.concat(prefix, ".dealerCards"));
    }

    function _toDynamicUint8FromJson(string memory json, string memory path) internal pure returns (uint8[] memory out) {
        string[] memory values = json.readStringArray(path);
        out = new uint8[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            out[i] = uint8(vm.parseUint(values[i]));
        }
    }

    function _legacyInitialState(BlackjackInitialDealFixture memory fixture)
        internal
        pure
        returns (BlackjackEngine.PublicSessionState memory state)
    {
        state.phase = fixture.payout > 0 ? uint8(BlackjackEngine.SessionPhase.Completed) : uint8(BlackjackEngine.SessionPhase.AwaitingPlayerAction);
        state.decisionType = 0;
        state.dealerRevealMask = fixture.dealerRevealMask;
        state.handCount = fixture.handCount;
        state.activeHandIndex = fixture.activeHandIndex;
        state.peekAvailable = 0;
        state.peekResolved = 0;
        state.dealerHasBlackjack = 0;
        state.insuranceAvailable = 0;
        state.insuranceStatus = 0;
        state.surrenderAvailable = 0;
        state.surrenderStatus = 0;
        state.dealerUpValue = fixture.dealerVisibleValue;
        state.dealerFinalValue = fixture.dealerVisibleValue;
        state.payout = fixture.payout;
        _copyLegacyHands(state.hands, fixture.handValues, fixture.handStatuses, fixture.allowedActionMasks, fixture.handCardCounts, fixture.handPayoutKinds, fixture.handCount);
        state.playerCards = _legacyPlayerCards(fixture.playerCards);
        state.dealerCards = _legacyDealerCards(fixture.dealerCards);
    }

    function _legacyActionState(BlackjackActionFixture memory fixture)
        internal
        pure
        returns (BlackjackEngine.PublicSessionState memory state)
    {
        state.phase = _mapLegacyBlackjackPhase(fixture.nextPhase);
        state.decisionType = 0;
        state.dealerRevealMask = fixture.dealerRevealMask;
        state.handCount = fixture.handCount;
        state.activeHandIndex = fixture.activeHandIndex;
        state.peekAvailable = 0;
        state.peekResolved = 0;
        state.dealerHasBlackjack = 0;
        state.insuranceAvailable = 0;
        state.insuranceStatus = 0;
        state.surrenderAvailable = 0;
        state.surrenderStatus = 0;
        state.dealerUpValue = fixture.dealerVisibleValue;
        state.dealerFinalValue = fixture.dealerVisibleValue;
        state.payout = 0;
        _copyLegacyHands(state.hands, fixture.handValues, fixture.handStatuses, fixture.allowedActionMasks, fixture.handCardCounts, fixture.handPayoutKinds, fixture.handCount);
        state.playerCards = _legacyPlayerCards(fixture.playerCards);
        state.dealerCards = _legacyDealerCards(fixture.dealerCards);
    }

    function _legacyShowdownState(BlackjackShowdownFixture memory fixture)
        internal
        pure
        returns (BlackjackEngine.PublicSessionState memory state)
    {
        state.phase = uint8(BlackjackEngine.SessionPhase.Completed);
        state.decisionType = 0;
        state.dealerRevealMask = fixture.dealerRevealMask;
        state.handCount = fixture.handCount;
        state.activeHandIndex = fixture.activeHandIndex;
        state.peekAvailable = 0;
        state.peekResolved = 0;
        state.dealerHasBlackjack = 0;
        state.insuranceAvailable = 0;
        state.insuranceStatus = 0;
        state.surrenderAvailable = 0;
        state.surrenderStatus = 0;
        state.dealerUpValue = fixture.dealerFinalValue;
        state.dealerFinalValue = fixture.dealerFinalValue;
        state.payout = fixture.payout;
        _copyLegacyHands(state.hands, fixture.handValues, fixture.handStatuses, _zeroUint8x4(), fixture.handCardCounts, fixture.handPayoutKinds, fixture.handCount);
        state.playerCards = _legacyPlayerCards(fixture.playerCards);
        state.dealerCards = _legacyDealerCards(fixture.dealerCards);
    }

    function _copyLegacyHands(
        BlackjackEngine.HandView[4] memory hands,
        uint256[4] memory handValues,
        uint8[4] memory handStatuses,
        uint8[4] memory allowedActionMasks,
        uint8[4] memory handCardCounts,
        uint8[4] memory handPayoutKinds,
        uint8 handCount
    ) internal pure {
        uint8 offset;
        for (uint256 i = 0; i < 4; i++) {
            hands[i] = BlackjackEngine.HandView({
                wager: i < handCount ? 100 : 0,
                value: handValues[i],
                status: handStatuses[i],
                allowedActionMask: allowedActionMasks[i],
                cardCount: handCardCounts[i],
                cardStartIndex: offset,
                payoutKind: handPayoutKinds[i]
            });
            offset += handCardCounts[i];
        }
    }

    function _legacyPlayerCards(uint8[8] memory cards) internal pure returns (uint8[] memory out) {
        out = new uint8[](8);
        for (uint256 i = 0; i < 8; i++) {
            out[i] = cards[i] == 52 ? BLACKJACK_CARD_EMPTY : cards[i];
        }
    }

    function _legacyDealerCards(uint8[4] memory cards) internal pure returns (uint8[] memory out) {
        out = new uint8[](4);
        for (uint256 i = 0; i < 4; i++) {
            out[i] = cards[i] == 52 ? BLACKJACK_CARD_EMPTY : cards[i];
        }
    }

    function _mapLegacyBlackjackPhase(uint8 legacyPhase) internal pure returns (uint8) {
        if (legacyPhase == 2) return uint8(BlackjackEngine.SessionPhase.AwaitingPlayerAction);
        if (legacyPhase == 3) return uint8(BlackjackEngine.SessionPhase.AwaitingCoordinatorAction);
        if (legacyPhase == 4) return uint8(BlackjackEngine.SessionPhase.Completed);
        return uint8(BlackjackEngine.SessionPhase.AwaitingCoordinatorAction);
    }

    function _zeroUint8x4() internal pure returns (uint8[4] memory out) {}

    function _isHexString(string memory value) private pure returns (bool) {
        bytes memory raw = bytes(value);
        return raw.length >= 2 && raw[0] == "0" && (raw[1] == "x" || raw[1] == "X");
    }
}
