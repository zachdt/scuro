// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { DeveloperExpressionRegistry } from "../src/DeveloperExpressionRegistry.sol";
import { DeveloperRewards } from "../src/DeveloperRewards.sol";
import { GameCatalog } from "../src/GameCatalog.sol";
import { GameDeploymentFactory } from "../src/GameDeploymentFactory.sol";
import { ProtocolSettlement } from "../src/ProtocolSettlement.sol";
import { ScuroToken } from "../src/ScuroToken.sol";
import { TournamentController } from "../src/controllers/TournamentController.sol";
import { SingleDraw2To7Engine } from "../src/engines/SingleDraw2To7Engine.sol";
import { Groth16ProofCodec } from "../src/libraries/Groth16ProofCodec.sol";
import { LaunchVerificationKeyHashes } from "../src/verifiers/LaunchVerificationKeyHashes.sol";
import { PokerVerifierBundle } from "../src/verifiers/PokerVerifierBundle.sol";
import { MockGroth16VerifierPrecompile } from "./helpers/MockGroth16VerifierPrecompile.sol";
import { ZkFixtureLoader } from "./helpers/ZkFixtureLoader.sol";

contract TournamentControllerTest is ZkFixtureLoader {
    address internal constant PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000800;

    ScuroToken internal token;
    GameCatalog internal catalog;
    GameDeploymentFactory internal factory;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    TournamentController internal controller;
    SingleDraw2To7Engine internal engine;

    address internal developer = address(0xC0FFEE);
    address internal player1 = address(0x111);
    address internal player2 = address(0x222);
    uint256 internal expressionTokenId;

    function setUp() public {
        token = new ScuroToken(address(this));
        catalog = new GameCatalog(address(this));
        expressionRegistry = new DeveloperExpressionRegistry(address(this));
        developerRewards = new DeveloperRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(
            address(token), address(catalog), address(expressionRegistry), address(developerRewards)
        );
        factory = new GameDeploymentFactory(address(this), address(catalog), address(settlement));
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(factory));

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));

        GameDeploymentFactory.PokerDeployment memory params = GameDeploymentFactory.PokerDeployment({
            coordinator: address(this),
            smallBlind: 10,
            bigBlind: 20,
            blindEscalationInterval: 180,
            actionWindow: 60,
            configHash: keccak256("single-draw-2-7-tournament"),
            developerRewardBps: 1_000
        });
        address controllerAddress;
        address engineAddress;
        (, controllerAddress, engineAddress,) = factory.deployTournamentModule(
            uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7), abi.encode(params)
        );
        controller = TournamentController(controllerAddress);
        engine = SingleDraw2To7Engine(engineAddress);

        bytes32 engineType = engine.engineType();
        vm.prank(developer);
        expressionTokenId = expressionRegistry.mintExpression(engineType, keccak256("single-draw-2-7"), "ipfs://2-7");

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
        controller.createTournament(0, 50 ether, 100, expressionTokenId);
        controller.startGameForPlayers(1, player1, player2);
        _submitInitialDealProof(1);

        vm.prank(player1);
        engine.bet(1, 10);
        vm.prank(player2);
        engine.bet(1, 0);

        _resolveDrawPhase(1);

        assertEq(engine.getCurrentPhase(1), 5);
        assertEq(engine.getProofDeadline(1), block.timestamp + 60);
    }

    function test_TournamentLifecycleUsesPrecompileAdapter() public {
        MockGroth16VerifierPrecompile precompile = _installPrecompile();
        PokerVerifierBundle bundle = PokerVerifierBundle(engine.VERIFIER_BUNDLE());
        bundle.setVerifiers(address(0), address(0), address(0));

        PokerInitialDealFixture memory initial = _loadPokerInitialDealFixture();
        PokerDrawFixture memory player0Draw = _loadPokerDrawFixture("poker_draw_resolve");
        PokerDrawFixture memory player1Draw = _loadPokerDrawFixture("poker_draw_resolve_player1");
        PokerShowdownFixture memory showdown = _loadPokerShowdownFixture("poker_showdown");

        precompile.setExpectedCall(
            LaunchVerificationKeyHashes.POKER_INITIAL_DEAL_VK_HASH,
            _flattenProof(initial.proof),
            _pokerInitialSignals(1, 1, initial)
        );
        uint256 gameId = _createTournamentGame();

        vm.prank(player1);
        engine.bet(gameId, 990);
        vm.prank(player2);
        engine.bet(gameId, 980);

        uint8[] memory empty = new uint8[](0);
        vm.prank(player2);
        engine.declareDraw(gameId, empty);
        vm.prank(player1);
        engine.declareDraw(gameId, empty);

        precompile.setExpectedCall(
            LaunchVerificationKeyHashes.POKER_DRAW_VK_HASH,
            _flattenProof(player0Draw.proof),
            _pokerDrawSignals(gameId, 1, uint256(initial.handNonce), uint256(initial.deckCommitment), player0Draw)
        );
        engine.submitDrawProof(
            gameId,
            player1,
            player0Draw.newCommitment,
            player0Draw.newEncryptionKeyCommitment,
            player0Draw.newCiphertextRef,
            player0Draw.proof
        );

        precompile.setExpectedCall(
            LaunchVerificationKeyHashes.POKER_DRAW_VK_HASH,
            _flattenProof(player1Draw.proof),
            _pokerDrawSignals(gameId, 1, uint256(initial.handNonce), uint256(initial.deckCommitment), player1Draw)
        );
        engine.submitDrawProof(
            gameId,
            player2,
            player1Draw.newCommitment,
            player1Draw.newEncryptionKeyCommitment,
            player1Draw.newCiphertextRef,
            player1Draw.proof
        );

        vm.prank(player2);
        engine.bet(gameId, 0);
        vm.prank(player1);
        engine.bet(gameId, 0);

        precompile.setExpectedCall(
            LaunchVerificationKeyHashes.POKER_SHOWDOWN_VK_HASH,
            _flattenProof(showdown.proof),
            _pokerShowdownSignals(
                gameId, 1, uint256(initial.handNonce), player0Draw.newCommitment, player1Draw.newCommitment, showdown
            )
        );
        engine.submitShowdownProof(gameId, player1, showdown.isTie, showdown.proof);
        controller.reportOutcome(gameId);

        assertEq(token.balanceOf(player1), 110 ether);
        assertEq(token.balanceOf(player2), 90 ether);
        assertEq(developerRewards.epochAccrual(developerRewards.currentEpoch(), developer), 4 ether);
    }

    function _createTournamentGame() internal returns (uint256 gameId) {
        uint256 tournamentId = controller.createTournament(10 ether, 20 ether, 1_000, expressionTokenId);
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

    function _installPrecompile() internal returns (MockGroth16VerifierPrecompile precompile) {
        MockGroth16VerifierPrecompile impl = new MockGroth16VerifierPrecompile();
        vm.etch(PRECOMPILE_ADDRESS, address(impl).code);
        precompile = MockGroth16VerifierPrecompile(PRECOMPILE_ADDRESS);
    }

    function _flattenProof(bytes memory proofData) internal pure returns (uint256[8] memory flat) {
        Groth16ProofCodec.Groth16Proof memory proof = abi.decode(proofData, (Groth16ProofCodec.Groth16Proof));
        flat[0] = proof.a[0];
        flat[1] = proof.a[1];
        flat[2] = proof.b[0][0];
        flat[3] = proof.b[0][1];
        flat[4] = proof.b[1][0];
        flat[5] = proof.b[1][1];
        flat[6] = proof.c[0];
        flat[7] = proof.c[1];
    }

    function _pokerInitialSignals(uint256 gameId, uint256 handNumber, PokerInitialDealFixture memory fixture)
        internal
        pure
        returns (uint256[] memory signals)
    {
        signals = new uint256[](10);
        signals[0] = gameId;
        signals[1] = handNumber;
        signals[2] = uint256(fixture.handNonce);
        signals[3] = uint256(fixture.deckCommitment);
        signals[4] = uint256(fixture.handCommitments[0]);
        signals[5] = uint256(fixture.handCommitments[1]);
        signals[6] = uint256(fixture.encryptionKeyCommitments[0]);
        signals[7] = uint256(fixture.encryptionKeyCommitments[1]);
        signals[8] = uint256(fixture.ciphertextRefs[0]);
        signals[9] = uint256(fixture.ciphertextRefs[1]);
    }

    function _pokerDrawSignals(
        uint256 gameId,
        uint256 handNumber,
        uint256 handNonce,
        uint256 deckCommitment,
        PokerDrawFixture memory fixture
    ) internal pure returns (uint256[] memory signals) {
        signals = new uint256[](11);
        signals[0] = gameId;
        signals[1] = handNumber;
        signals[2] = handNonce;
        signals[3] = fixture.playerIndex;
        signals[4] = deckCommitment;
        signals[5] = uint256(fixture.oldCommitment);
        signals[6] = uint256(fixture.newCommitment);
        signals[7] = uint256(fixture.newEncryptionKeyCommitment);
        signals[8] = uint256(fixture.newCiphertextRef);
        signals[9] = fixture.discardMask;
        signals[10] = fixture.proofSequence;
    }

    function _pokerShowdownSignals(
        uint256 gameId,
        uint256 handNumber,
        uint256 handNonce,
        bytes32 player0Commitment,
        bytes32 player1Commitment,
        PokerShowdownFixture memory fixture
    ) internal pure returns (uint256[] memory signals) {
        signals = new uint256[](7);
        signals[0] = gameId;
        signals[1] = handNumber;
        signals[2] = handNonce;
        signals[3] = uint256(player0Commitment);
        signals[4] = uint256(player1Commitment);
        signals[5] = fixture.winnerIndex;
        signals[6] = fixture.isTie ? 1 : 0;
    }
}
