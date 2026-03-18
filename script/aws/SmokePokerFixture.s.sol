// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeveloperRewards} from "../../src/DeveloperRewards.sol";
import {ScuroToken} from "../../src/ScuroToken.sol";
import {TournamentController} from "../../src/controllers/TournamentController.sol";
import {SingleDraw2To7Engine} from "../../src/engines/SingleDraw2To7Engine.sol";
import {FixtureLoaders} from "./FixtureLoaders.sol";

contract SmokePokerFixture is FixtureLoaders {
    uint256 internal constant ENTRY_FEE = 10 ether;
    uint256 internal constant REWARD_POOL = 20 ether;
    uint256 internal constant STARTING_STACK = 1_000;
    uint256 internal constant POKER_DEVELOPER_ACCRUAL = 4 ether;

    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 player1Key = vm.envOr("PLAYER1_PRIVATE_KEY", DEFAULT_ANVIL_PLAYER1_KEY);
        uint256 player2Key = vm.envOr("PLAYER2_PRIVATE_KEY", DEFAULT_ANVIL_PLAYER2_KEY);

        address player1 = vm.addr(player1Key);
        address player2 = vm.addr(player2Key);
        address pokerDeveloper = vm.envAddress("POKER_DEVELOPER");

        ScuroToken token = ScuroToken(vm.envAddress("SCURO_TOKEN"));
        DeveloperRewards developerRewards = DeveloperRewards(vm.envAddress("DEVELOPER_REWARDS"));
        TournamentController controller = TournamentController(vm.envAddress("TOURNAMENT_CONTROLLER"));
        SingleDraw2To7Engine engine = SingleDraw2To7Engine(vm.envAddress("TOURNAMENT_POKER_ENGINE"));
        uint256 expressionTokenId = vm.envUint("POKER_EXPRESSION_TOKEN_ID");

        vm.startBroadcast(player1Key);
        token.approve(address(controller.settlement()), type(uint256).max);
        vm.stopBroadcast();

        vm.startBroadcast(player2Key);
        token.approve(address(controller.settlement()), type(uint256).max);
        vm.stopBroadcast();

        uint256 tournamentId;
        uint256 gameId;
        vm.startBroadcast(adminKey);
        tournamentId = controller.createTournament(ENTRY_FEE, REWARD_POOL, STARTING_STACK, expressionTokenId);
        gameId = controller.startGameForPlayers(tournamentId, player1, player2);
        vm.stopBroadcast();

        PokerInitialDealFixture memory initialDeal = _loadPokerInitialDealFixture();
        vm.startBroadcast(adminKey);
        engine.submitInitialDealProof(
            gameId,
            initialDeal.deckCommitment,
            initialDeal.handNonce,
            initialDeal.handCommitments,
            initialDeal.encryptionKeyCommitments,
            initialDeal.ciphertextRefs,
            initialDeal.proof
        );
        vm.stopBroadcast();

        vm.startBroadcast(player1Key);
        engine.bet(gameId, 990);
        vm.stopBroadcast();

        vm.startBroadcast(player2Key);
        engine.bet(gameId, 980);
        vm.stopBroadcast();

        uint8[] memory empty = new uint8[](0);
        vm.startBroadcast(player2Key);
        engine.declareDraw(gameId, empty);
        vm.stopBroadcast();

        vm.startBroadcast(player1Key);
        engine.declareDraw(gameId, empty);
        vm.stopBroadcast();

        PokerDrawFixture memory player1Draw = _loadPokerDrawFixture("poker_draw_resolve");
        PokerDrawFixture memory player2Draw = _loadPokerDrawFixture("poker_draw_resolve_player1");
        vm.startBroadcast(adminKey);
        engine.submitDrawProof(
            gameId,
            player1,
            player1Draw.newCommitment,
            player1Draw.newEncryptionKeyCommitment,
            player1Draw.newCiphertextRef,
            player1Draw.proof
        );
        engine.submitDrawProof(
            gameId,
            player2,
            player2Draw.newCommitment,
            player2Draw.newEncryptionKeyCommitment,
            player2Draw.newCiphertextRef,
            player2Draw.proof
        );
        vm.stopBroadcast();

        vm.startBroadcast(player2Key);
        engine.bet(gameId, 0);
        vm.stopBroadcast();

        vm.startBroadcast(player1Key);
        engine.bet(gameId, 0);
        vm.stopBroadcast();

        PokerShowdownFixture memory showdown = _loadPokerShowdownFixture();
        vm.startBroadcast(adminKey);
        engine.submitShowdownProof(gameId, player1, showdown.isTie, showdown.proof);
        controller.reportOutcome(gameId);
        vm.stopBroadcast();

        require(token.balanceOf(player1) == 10_010 ether, "SmokePokerFixture: player1 balance");
        require(token.balanceOf(player2) == 9_990 ether, "SmokePokerFixture: player2 balance");
        require(
            developerRewards.epochAccrual(developerRewards.currentEpoch(), pokerDeveloper) == POKER_DEVELOPER_ACCRUAL,
            "SmokePokerFixture: accrual"
        );
    }
}
