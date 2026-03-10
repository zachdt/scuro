// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeveloperExpressionRegistry} from "../src/DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "../src/DeveloperRewards.sol";
import {GameEngineRegistry} from "../src/GameEngineRegistry.sol";
import {ProtocolSettlement} from "../src/ProtocolSettlement.sol";
import {ScuroToken} from "../src/ScuroToken.sol";
import {TournamentController} from "../src/controllers/TournamentController.sol";
import {SingleDraw2To7Engine} from "../src/engines/SingleDraw2To7Engine.sol";
import {PokerVerifierBundle} from "../src/verifiers/PokerVerifierBundle.sol";
import {PokerDrawResolveVerifier} from "../src/verifiers/generated/PokerDrawResolveVerifier.sol";
import {PokerInitialDealVerifier} from "../src/verifiers/generated/PokerInitialDealVerifier.sol";
import {PokerShowdownVerifier} from "../src/verifiers/generated/PokerShowdownVerifier.sol";
import {ZkFixtureLoader} from "./helpers/ZkFixtureLoader.sol";

contract TournamentControllerTest is ZkFixtureLoader {
    ScuroToken internal token;
    GameEngineRegistry internal registry;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    TournamentController internal controller;
    SingleDraw2To7Engine internal engine;
    PokerVerifierBundle internal verifierBundle;

    address internal developer = address(0xC0FFEE);
    address internal player1 = address(0x111);
    address internal player2 = address(0x222);
    uint256 internal expressionTokenId;

    function setUp() public {
        token = new ScuroToken(address(this));
        registry = new GameEngineRegistry(address(this));
        expressionRegistry = new DeveloperExpressionRegistry(address(this));
        developerRewards = new DeveloperRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(
            address(this),
            address(token),
            address(registry),
            address(expressionRegistry),
            address(developerRewards)
        );
        controller = new TournamentController(address(this), address(settlement), address(registry));
        verifierBundle = new PokerVerifierBundle(
            address(this),
            address(new PokerInitialDealVerifier()),
            address(new PokerDrawResolveVerifier()),
            address(new PokerShowdownVerifier())
        );
        engine = new SingleDraw2To7Engine(address(this));

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));
        settlement.setControllerAuthorization(address(controller), true);
        engine.grantRole(engine.CONTROLLER_ROLE(), address(controller));

        registry.registerEngine(
            address(engine),
            GameEngineRegistry.EngineMetadata({
                engineType: engine.ENGINE_TYPE(),
                verifier: address(verifierBundle),
                configHash: keccak256("2-7"),
                developerRewardBps: 1_000,
                active: true,
                supportsTournament: true,
                supportsPvP: true,
                supportsSolo: false
            })
        );

        bytes32 engineType = engine.ENGINE_TYPE();
        vm.prank(developer);
        expressionTokenId =
            expressionRegistry.mintExpression(engineType, keccak256("single-draw-2-7"), "ipfs://2-7");

        token.mint(player1, 100 ether);
        token.mint(player2, 100 ether);
        vm.prank(player1);
        token.approve(address(settlement), type(uint256).max);
        vm.prank(player2);
        token.approve(address(settlement), type(uint256).max);
    }

    function test_TournamentLifecycleSettlesRewardsAndDeveloperAccrual() public {
        uint256 gameId = _createTournamentGame();

        vm.prank(player1);
        engine.bet(gameId, 990);
        vm.prank(player2);
        engine.bet(gameId, 980);

        _resolveDrawPhase(gameId);

        vm.prank(player2);
        engine.bet(gameId, 0);
        vm.prank(player1);
        engine.bet(gameId, 0);

        PokerShowdownFixture memory showdown = _loadPokerShowdownFixture("poker_showdown");
        engine.submitShowdownProof(gameId, player1, showdown.isTie, showdown.proof);
        assertTrue(engine.isGameOver(gameId));

        controller.reportOutcome(gameId);

        assertEq(token.balanceOf(player1), 110 ether);
        assertEq(token.balanceOf(player2), 90 ether);
        assertEq(developerRewards.epochAccrual(developerRewards.currentEpoch(), developer), 4 ether);

        vm.expectRevert("TournamentController: reported");
        controller.reportOutcome(gameId);
    }

    function test_ZkInterfacesSmokeForGenericPokerFlow() public {
        address[] memory players = new address[](2);
        players[0] = player1;
        players[1] = player2;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 100;
        stacks[1] = 100;

        engine.initializeGame(1, players, stacks, 0, 50 ether, _defaultPokerConfig());
        _submitInitialDealProof(1);

        vm.prank(player1);
        engine.bet(1, 10);
        vm.prank(player2);
        engine.bet(1, 0);

        _resolveDrawPhase(1);

        assertEq(engine.getCurrentPhase(1), 5);
        assertEq(engine.getProofDeadline(1), block.timestamp + 60);
    }

    function _createTournamentGame() internal returns (uint256 gameId) {
        uint256 tournamentId =
            controller.createTournament(10 ether, 20 ether, address(engine), 1_000, _defaultPokerConfig(), expressionTokenId);
        gameId = controller.startGameForPlayers(tournamentId, player1, player2);
        _submitInitialDealProof(gameId);
    }

    function _submitInitialDealProof(uint256 gameId) internal {
        PokerInitialDealFixture memory fixture = _loadPokerInitialDealFixture();
        engine.submitInitialDealProof(
            gameId,
            fixture.deckCommitment,
            fixture.handNonce,
            fixture.handCommitments,
            fixture.encryptionKeyCommitments,
            fixture.ciphertextRefs,
            fixture.proof
        );
    }

    function _resolveDrawPhase(uint256 gameId) internal {
        uint8[] memory empty = new uint8[](0);
        vm.prank(player2);
        engine.declareDraw(gameId, empty);
        vm.prank(player1);
        engine.declareDraw(gameId, empty);

        PokerDrawFixture memory player0Draw = _loadPokerDrawFixture("poker_draw_resolve");
        PokerDrawFixture memory player1Draw = _loadPokerDrawFixture("poker_draw_resolve_player1");
        engine.submitDrawProof(
            gameId,
            player1,
            player0Draw.newCommitment,
            player0Draw.newEncryptionKeyCommitment,
            player0Draw.newCiphertextRef,
            player0Draw.proof
        );
        engine.submitDrawProof(
            gameId,
            player2,
            player1Draw.newCommitment,
            player1Draw.newEncryptionKeyCommitment,
            player1Draw.newCiphertextRef,
            player1Draw.proof
        );
    }

    function _defaultPokerConfig() internal view returns (bytes memory) {
        return abi.encode(uint256(10), uint256(20), uint256(180), uint256(60), address(verifierBundle), address(this));
    }
}
