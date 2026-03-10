// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { CreatorRewards } from "../src/CreatorRewards.sol";
import { GameEngineRegistry } from "../src/GameEngineRegistry.sol";
import { ScuroToken } from "../src/ScuroToken.sol";
import { BlackjackController } from "../src/controllers/BlackjackController.sol";
import { TournamentController } from "../src/controllers/TournamentController.sol";
import { SingleDeckBlackjackEngine } from "../src/engines/SingleDeckBlackjackEngine.sol";
import { SingleDraw2To7Engine } from "../src/engines/SingleDraw2To7Engine.sol";

contract SmokeRealProofHands is Script {
    using stdJson for string;

    uint256 internal constant ENTRY_FEE = 10 ether;
    uint256 internal constant REWARD_POOL = 20 ether;
    uint256 internal constant STARTING_STACK = 1_000;
    uint256 internal constant BLACKJACK_WAGER = 100;
    uint256 internal constant POKER_CREATOR_ACCRUAL = 4 ether;
    uint256 internal constant BLACKJACK_CREATOR_ACCRUAL = 5;
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
    }

    struct BlackjackActionFixture {
        bytes proof;
        bytes32 newPlayerStateCommitment;
        bytes32 dealerStateCommitment;
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
    }

    struct BlackjackShowdownFixture {
        bytes proof;
        bytes32 playerStateCommitment;
        bytes32 dealerStateCommitment;
        uint256 payout;
        uint256 dealerFinalValue;
        uint8 handCount;
        uint8 activeHandIndex;
        uint8[4] handStatuses;
    }

    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 player1Key = vm.envOr("PLAYER1_PRIVATE_KEY", DEFAULT_ANVIL_PLAYER1_KEY);
        uint256 player2Key = vm.envOr("PLAYER2_PRIVATE_KEY", DEFAULT_ANVIL_PLAYER2_KEY);

        address admin = vm.addr(adminKey);
        address player1 = vm.addr(player1Key);
        address player2 = vm.addr(player2Key);

        ScuroToken token = ScuroToken(vm.envAddress("SCURO_TOKEN"));
        CreatorRewards creatorRewards = CreatorRewards(vm.envAddress("CREATOR_REWARDS"));
        GameEngineRegistry registry = GameEngineRegistry(vm.envAddress("REGISTRY"));
        TournamentController tournamentController = TournamentController(vm.envAddress("TOURNAMENT_CONTROLLER"));
        SingleDraw2To7Engine pokerEngine = SingleDraw2To7Engine(vm.envAddress("POKER_ENGINE"));
        BlackjackController blackjackController = BlackjackController(vm.envAddress("BLACKJACK_CONTROLLER"));
        SingleDeckBlackjackEngine blackjackEngine = SingleDeckBlackjackEngine(vm.envAddress("BLACKJACK_ENGINE"));

        address pokerVerifierBundle = vm.envAddress("POKER_VERIFIER_BUNDLE");
        address blackjackVerifierBundle = vm.envAddress("BLACKJACK_VERIFIER_BUNDLE");
        address pokerCreator = vm.envAddress("POKER_CREATOR");
        address soloCreator = vm.envAddress("SOLO_CREATOR");

        _assertVerifierMetadata(
            registry, address(pokerEngine), pokerVerifierBundle, address(blackjackEngine), blackjackVerifierBundle
        );

        vm.startBroadcast(player1Key);
        token.approve(address(tournamentController.settlement()), type(uint256).max);
        token.approve(address(blackjackController.settlement()), type(uint256).max);
        vm.stopBroadcast();

        vm.startBroadcast(player2Key);
        token.approve(address(tournamentController.settlement()), type(uint256).max);
        vm.stopBroadcast();

        uint256 tournamentId;
        uint256 gameId;
        vm.startBroadcast(adminKey);
        tournamentId = tournamentController.createTournament(
            ENTRY_FEE,
            REWARD_POOL,
            address(pokerEngine),
            STARTING_STACK,
            abi.encode(uint256(10), uint256(20), uint256(180), uint256(60), pokerVerifierBundle, admin)
        );
        gameId = tournamentController.startGameForPlayers(tournamentId, player1, player2);
        vm.stopBroadcast();

        _submitPokerInitialDeal(adminKey, pokerEngine, gameId);

        vm.startBroadcast(player1Key);
        pokerEngine.bet(gameId, 990);
        vm.stopBroadcast();

        vm.startBroadcast(player2Key);
        pokerEngine.bet(gameId, 980);
        vm.stopBroadcast();

        _resolvePokerDraw(adminKey, pokerEngine, gameId, player1, player2);

        vm.startBroadcast(player2Key);
        pokerEngine.bet(gameId, 0);
        vm.stopBroadcast();

        vm.startBroadcast(player1Key);
        pokerEngine.bet(gameId, 0);
        vm.stopBroadcast();

        _submitPokerShowdown(adminKey, pokerEngine, gameId, player1);

        vm.startBroadcast(adminKey);
        tournamentController.reportOutcome(gameId);
        vm.stopBroadcast();

        BlackjackInitialDealFixture memory blackjackInitial = _loadBlackjackInitialDealFixture();
        vm.startBroadcast(player1Key);
        uint256 sessionId = blackjackController.startHand(
            BLACKJACK_WAGER, keccak256("smoke-blackjack"), blackjackInitial.playerKeyCommitment
        );
        vm.stopBroadcast();

        _submitBlackjackInitialDeal(adminKey, blackjackEngine, sessionId, blackjackInitial);

        vm.startBroadcast(player1Key);
        blackjackController.hit(sessionId);
        vm.stopBroadcast();

        _submitBlackjackAction(adminKey, blackjackEngine, sessionId);

        vm.startBroadcast(player1Key);
        blackjackController.stand(sessionId);
        vm.stopBroadcast();

        _submitBlackjackShowdown(adminKey, blackjackEngine, sessionId);

        vm.startBroadcast(adminKey);
        blackjackController.settle(sessionId);
        vm.stopBroadcast();

        require(token.balanceOf(player1) == (10_010 ether + 100), "Smoke: player1 balance");
        require(token.balanceOf(player2) == 9_990 ether, "Smoke: player2 balance");
        require(
            creatorRewards.epochAccrual(creatorRewards.currentEpoch(), pokerCreator) == POKER_CREATOR_ACCRUAL,
            "Smoke: poker accrual"
        );
        require(
            creatorRewards.epochAccrual(creatorRewards.currentEpoch(), soloCreator) == BLACKJACK_CREATOR_ACCRUAL,
            "Smoke: blackjack accrual"
        );
        require(registry.isRegisteredForTournament(address(pokerEngine)), "Smoke: poker inactive");
        require(registry.isRegisteredForSolo(address(blackjackEngine)), "Smoke: blackjack inactive");
    }

    function _assertVerifierMetadata(
        GameEngineRegistry registry,
        address pokerEngine,
        address pokerVerifierBundle,
        address blackjackEngine,
        address blackjackVerifierBundle
    ) internal view {
        GameEngineRegistry.EngineMetadata memory pokerMetadata = registry.getEngineMetadata(pokerEngine);
        GameEngineRegistry.EngineMetadata memory blackjackMetadata = registry.getEngineMetadata(blackjackEngine);

        require(pokerMetadata.verifier == pokerVerifierBundle, "Smoke: poker verifier");
        require(blackjackMetadata.verifier == blackjackVerifierBundle, "Smoke: blackjack verifier");
    }

    function _submitPokerInitialDeal(uint256 adminKey, SingleDraw2To7Engine pokerEngine, uint256 gameId) internal {
        PokerInitialDealFixture memory fixture = _loadPokerInitialDealFixture();
        vm.startBroadcast(adminKey);
        pokerEngine.submitInitialDealProof(
            gameId,
            fixture.deckCommitment,
            fixture.handNonce,
            fixture.handCommitments,
            fixture.encryptionKeyCommitments,
            fixture.ciphertextRefs,
            fixture.proof
        );
        vm.stopBroadcast();
    }

    function _resolvePokerDraw(
        uint256 adminKey,
        SingleDraw2To7Engine pokerEngine,
        uint256 gameId,
        address player1,
        address player2
    ) internal {
        uint8[] memory empty = new uint8[](0);
        vm.startBroadcast(vm.envOr("PLAYER2_PRIVATE_KEY", DEFAULT_ANVIL_PLAYER2_KEY));
        pokerEngine.declareDraw(gameId, empty);
        vm.stopBroadcast();

        vm.startBroadcast(vm.envOr("PLAYER1_PRIVATE_KEY", DEFAULT_ANVIL_PLAYER1_KEY));
        pokerEngine.declareDraw(gameId, empty);
        vm.stopBroadcast();

        PokerDrawFixture memory player1Draw = _loadPokerDrawFixture("poker_draw_resolve");
        PokerDrawFixture memory player2Draw = _loadPokerDrawFixture("poker_draw_resolve_player1");
        vm.startBroadcast(adminKey);
        pokerEngine.submitDrawProof(
            gameId,
            player1,
            player1Draw.newCommitment,
            player1Draw.newEncryptionKeyCommitment,
            player1Draw.newCiphertextRef,
            player1Draw.proof
        );
        pokerEngine.submitDrawProof(
            gameId,
            player2,
            player2Draw.newCommitment,
            player2Draw.newEncryptionKeyCommitment,
            player2Draw.newCiphertextRef,
            player2Draw.proof
        );
        vm.stopBroadcast();
    }

    function _submitPokerShowdown(uint256 adminKey, SingleDraw2To7Engine pokerEngine, uint256 gameId, address winner)
        internal
    {
        PokerShowdownFixture memory fixture = _loadPokerShowdownFixture();
        vm.startBroadcast(adminKey);
        pokerEngine.submitShowdownProof(gameId, winner, fixture.isTie, fixture.proof);
        vm.stopBroadcast();
    }

    function _submitBlackjackInitialDeal(
        uint256 adminKey,
        SingleDeckBlackjackEngine blackjackEngine,
        uint256 sessionId,
        BlackjackInitialDealFixture memory fixture
    ) internal {
        vm.startBroadcast(adminKey);
        blackjackEngine.submitInitialDealProof(
            sessionId,
            fixture.deckCommitment,
            fixture.handNonce,
            fixture.playerStateCommitment,
            fixture.dealerStateCommitment,
            fixture.playerCiphertextRef,
            fixture.dealerCiphertextRef,
            fixture.dealerVisibleValue,
            fixture.handCount,
            fixture.activeHandIndex,
            fixture.payout,
            fixture.immediateResultCode,
            fixture.handValues,
            fixture.handStatuses,
            fixture.allowedActionMasks,
            fixture.softMask,
            fixture.proof
        );
        vm.stopBroadcast();
    }

    function _submitBlackjackAction(uint256 adminKey, SingleDeckBlackjackEngine blackjackEngine, uint256 sessionId)
        internal
    {
        BlackjackActionFixture memory fixture = _loadBlackjackActionFixture();
        vm.startBroadcast(adminKey);
        blackjackEngine.submitActionProof(
            sessionId,
            fixture.newPlayerStateCommitment,
            fixture.dealerStateCommitment,
            fixture.playerCiphertextRef,
            fixture.dealerCiphertextRef,
            fixture.dealerVisibleValue,
            fixture.handCount,
            fixture.activeHandIndex,
            fixture.nextPhase,
            fixture.handValues,
            fixture.handStatuses,
            fixture.allowedActionMasks,
            fixture.softMask,
            fixture.proof
        );
        vm.stopBroadcast();
    }

    function _submitBlackjackShowdown(uint256 adminKey, SingleDeckBlackjackEngine blackjackEngine, uint256 sessionId)
        internal
    {
        BlackjackShowdownFixture memory fixture = _loadBlackjackShowdownFixture();
        vm.startBroadcast(adminKey);
        blackjackEngine.submitShowdownProof(
            sessionId,
            fixture.playerStateCommitment,
            fixture.dealerStateCommitment,
            fixture.payout,
            fixture.dealerFinalValue,
            fixture.handCount,
            fixture.activeHandIndex,
            fixture.handStatuses,
            fixture.proof
        );
        vm.stopBroadcast();
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
        string memory json = vm.readFile(_fixturePath("blackjack_initial_deal"));
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
        fixture.handCount = uint8(vm.parseUint(publicSignals[9]));
        fixture.activeHandIndex = uint8(vm.parseUint(publicSignals[10]));
        fixture.payout = vm.parseUint(publicSignals[11]);
        fixture.immediateResultCode = uint8(vm.parseUint(publicSignals[12]));
        fixture.handValues = _toUint256x4(publicSignals, 13);
        fixture.softMask = vm.parseUint(publicSignals[17]);
        fixture.handStatuses = _toUint8x4(publicSignals, 18);
        fixture.allowedActionMasks = _toUint8x4(publicSignals, 22);
    }

    function _loadBlackjackActionFixture() internal view returns (BlackjackActionFixture memory fixture) {
        string memory json = vm.readFile(_fixturePath("blackjack_action_resolve"));
        string[] memory publicSignals = json.readStringArray(".publicSignals");

        fixture.proof = json.readBytes(".proof");
        fixture.newPlayerStateCommitment = _bytes32FromString(publicSignals[4]);
        fixture.dealerStateCommitment = _bytes32FromString(publicSignals[5]);
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
    }

    function _loadBlackjackShowdownFixture() internal view returns (BlackjackShowdownFixture memory fixture) {
        string memory json = vm.readFile(_fixturePath("blackjack_showdown"));
        string[] memory publicSignals = json.readStringArray(".publicSignals");

        fixture.proof = json.readBytes(".proof");
        fixture.playerStateCommitment = _bytes32FromString(publicSignals[2]);
        fixture.dealerStateCommitment = _bytes32FromString(publicSignals[3]);
        fixture.payout = vm.parseUint(publicSignals[4]);
        fixture.dealerFinalValue = vm.parseUint(publicSignals[5]);
        fixture.handCount = uint8(vm.parseUint(publicSignals[6]));
        fixture.activeHandIndex = uint8(vm.parseUint(publicSignals[7]));
        fixture.handStatuses = _toUint8x4(publicSignals, 8);
    }

    function _fixturePath(string memory name) internal view returns (string memory) {
        return string.concat(vm.projectRoot(), "/zk/fixtures/generated/", name, ".json");
    }

    function _bytes32FromString(string memory value) internal pure returns (bytes32) {
        return bytes32(vm.parseUint(value));
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
}
