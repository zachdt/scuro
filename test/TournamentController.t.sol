// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ScuroToken.sol";
import "../src/GameEngineRegistry.sol";
import "../src/CreatorRewards.sol";
import "../src/ProtocolSettlement.sol";
import "../src/controllers/TournamentController.sol";
import "../src/engines/SingleDraw2To7Engine.sol";
import "../src/mocks/MockPokerVerifier.sol";

contract TournamentControllerTest is Test {
    ScuroToken internal token;
    GameEngineRegistry internal registry;
    CreatorRewards internal creatorRewards;
    ProtocolSettlement internal settlement;
    TournamentController internal controller;
    SingleDraw2To7Engine internal engine;
    MockPokerVerifier internal drawVerifier;
    MockPokerVerifier internal showdownVerifier;

    address internal creator = address(0xC0FFEE);
    address internal player1 = address(0x111);
    address internal player2 = address(0x222);

    function setUp() public {
        token = new ScuroToken(address(this));
        registry = new GameEngineRegistry(address(this));
        creatorRewards = new CreatorRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(address(this), address(token), address(registry), address(creatorRewards));
        controller = new TournamentController(address(this), address(settlement), address(registry));
        engine = new SingleDraw2To7Engine();
        drawVerifier = new MockPokerVerifier();
        showdownVerifier = new MockPokerVerifier();

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(creatorRewards));
        creatorRewards.grantRole(creatorRewards.SETTLEMENT_ROLE(), address(settlement));
        settlement.setControllerAuthorization(address(controller), true);

        registry.registerEngine(
            address(engine),
            GameEngineRegistry.EngineMetadata({
                engineType: engine.ENGINE_TYPE(),
                creator: creator,
                verifier: address(drawVerifier),
                configHash: keccak256("2-7"),
                creatorRateBps: 1_000,
                active: true,
                supportsTournament: true,
                supportsPvP: true,
                supportsSolo: false
            })
        );

        token.mint(player1, 100 ether);
        token.mint(player2, 100 ether);
        vm.prank(player1);
        token.approve(address(settlement), type(uint256).max);
        vm.prank(player2);
        token.approve(address(settlement), type(uint256).max);
    }

    function test_TournamentLifecycleSettlesRewardsAndCreatorAccrual() public {
        bytes memory engineConfig = abi.encode(
            uint256(10),
            uint256(20),
            uint256(180),
            uint256(60),
            address(drawVerifier),
            address(showdownVerifier),
            address(this)
        );

        uint256 tournamentId = controller.createTournament(10 ether, 20 ether, address(engine), 1_000, engineConfig);
        uint256 gameId = controller.startGameForPlayers(tournamentId, player1, player2);

        assertEq(token.balanceOf(player1), 90 ether);
        assertEq(token.balanceOf(player2), 90 ether);

        vm.prank(player1);
        engine.bet(gameId, 990);
        vm.prank(player2);
        engine.bet(gameId, 980);

        uint8[] memory empty = new uint8[](0);
        vm.prank(player2);
        engine.discardCards(gameId, empty);
        vm.prank(player1);
        engine.discardCards(gameId, empty);

        vm.prank(player2);
        engine.bet(gameId, 0);
        vm.prank(player1);
        engine.bet(gameId, 0);

        vm.prank(player2);
        engine.submitShowdownProof(gameId, player1, false, hex"01");
        assertTrue(engine.isGameOver(gameId));

        controller.reportOutcome(gameId);

        assertEq(token.balanceOf(player1), 110 ether);
        assertEq(token.balanceOf(player2), 90 ether);
        assertEq(creatorRewards.epochAccrual(creatorRewards.currentEpoch(), creator), 4 ether);

        vm.expectRevert("TournamentController: reported");
        controller.reportOutcome(gameId);
    }

    function test_ZkInterfacesSmokeForGenericPokerFlow() public {
        bytes memory engineConfig = abi.encode(
            uint256(5),
            uint256(10),
            uint256(180),
            uint256(60),
            address(drawVerifier),
            address(showdownVerifier),
            address(this)
        );

        address[] memory players = new address[](2);
        players[0] = player1;
        players[1] = player2;

        uint256[] memory stacks = new uint256[](2);
        stacks[0] = 100;
        stacks[1] = 100;

        engine.initializeGame(99, players, stacks, 0, 50 ether, engineConfig);
        engine.initializeHandState(
            99,
            keccak256("deck"),
            keccak256("nonce"),
            [bytes32(uint256(1)), bytes32(uint256(2))],
            [bytes32(uint256(3)), bytes32(uint256(4))],
            [bytes32(uint256(5)), bytes32(uint256(6))]
        );

        vm.prank(player1);
        engine.bet(99, 5);
        vm.prank(player2);
        engine.bet(99, 0);

        vm.prank(player2);
        engine.submitDrawProof(99, bytes32(uint256(11)), bytes32(uint256(12)), hex"01");
        engine.finalizeDraw(99, player2);
        vm.prank(player1);
        engine.submitDrawProof(99, bytes32(uint256(13)), bytes32(uint256(14)), hex"01");
        engine.finalizeDraw(99, player1);

        assertEq(engine.getCurrentPhase(99), 3);
        assertEq(engine.getProofDeadline(99), block.timestamp + 60);
    }
}
