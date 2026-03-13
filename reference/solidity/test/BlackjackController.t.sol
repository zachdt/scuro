// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { DeveloperExpressionRegistry } from "../src/DeveloperExpressionRegistry.sol";
import { DeveloperRewards } from "../src/DeveloperRewards.sol";
import { GameCatalog } from "../src/GameCatalog.sol";
import { GameDeploymentFactory } from "../src/GameDeploymentFactory.sol";
import { ProtocolSettlement } from "../src/ProtocolSettlement.sol";
import { ScuroToken } from "../src/ScuroToken.sol";
import { BlackjackController } from "../src/controllers/BlackjackController.sol";
import { SingleDeckBlackjackEngine } from "../src/engines/SingleDeckBlackjackEngine.sol";
import { Groth16ProofCodec } from "../src/libraries/Groth16ProofCodec.sol";
import { LaunchVerificationKeyHashes } from "../src/verifiers/LaunchVerificationKeyHashes.sol";
import { BlackjackVerifierBundle } from "../src/verifiers/BlackjackVerifierBundle.sol";
import { MockGroth16VerifierPrecompile } from "./helpers/MockGroth16VerifierPrecompile.sol";
import { ZkFixtureLoader } from "./helpers/ZkFixtureLoader.sol";

contract BlackjackControllerTest is ZkFixtureLoader {
    address internal constant PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000800;

    ScuroToken internal token;
    GameCatalog internal catalog;
    GameDeploymentFactory internal factory;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    SingleDeckBlackjackEngine internal engine;
    BlackjackController internal controller;

    address internal developer = address(0xBEEF);
    address internal player = address(0x111);
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

        GameDeploymentFactory.BlackjackDeployment memory params = GameDeploymentFactory.BlackjackDeployment({
            coordinator: address(this),
            defaultActionWindow: 60,
            configHash: keccak256("single-deck-blackjack-zk"),
            developerRewardBps: 500
        });
        address controllerAddress;
        address engineAddress;
        (, controllerAddress, engineAddress,) =
            factory.deploySoloModule(uint8(GameDeploymentFactory.SoloFamily.Blackjack), abi.encode(params));
        controller = BlackjackController(controllerAddress);
        engine = SingleDeckBlackjackEngine(engineAddress);

        bytes32 engineType = engine.engineType();
        vm.prank(developer);
        expressionTokenId = expressionRegistry.mintExpression(
            engineType, keccak256("single-deck-blackjack-zk"), "ipfs://single-deck-blackjack-zk"
        );

        token.mint(player, 1_000);
        vm.prank(player);
        token.approve(address(settlement), type(uint256).max);
    }

    function test_BlackjackRealProofFlowSettlesThroughController() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture();
        BlackjackActionFixture memory action = _loadBlackjackActionFixture();
        BlackjackShowdownFixture memory showdown = _loadBlackjackShowdownFixture();

        vm.prank(player);
        uint256 sessionId =
            controller.startHand(100, keccak256("blackjack-hit-stand"), initial.playerKeyCommitment, expressionTokenId);
        assertEq(sessionId, 1);
        assertEq(token.balanceOf(player), 900);

        _submitInitialDeal(sessionId, initial);

        vm.prank(player);
        controller.hit(sessionId);
        _submitActionProof(sessionId, action);

        vm.prank(player);
        controller.stand(sessionId);
        _submitShowdownProof(sessionId, showdown);

        controller.settle(sessionId);

        assertEq(token.balanceOf(player), 1_100);
        assertEq(developerRewards.epochAccrual(developerRewards.currentEpoch(), developer), 5);
        (address settledPlayer, uint256 totalBurned, uint256 payout, bool completed) =
            engine.getSettlementOutcome(sessionId);
        assertEq(settledPlayer, player);
        assertEq(totalBurned, 100);
        assertEq(payout, 200);
        assertTrue(completed);
        assertEq(controller.sessionExpressionTokenId(sessionId), expressionTokenId);
    }

    function test_BlackjackRejectsInvalidInitProofAndTimeoutAutoStands() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture();

        vm.prank(player);
        uint256 sessionId =
            controller.startHand(100, keccak256("blackjack-timeout"), initial.playerKeyCommitment, expressionTokenId);

        vm.expectRevert("Blackjack: invalid init proof");
        _submitInitialDealWithDeck(sessionId, initial, bytes32(uint256(initial.deckCommitment) + 1));

        _submitInitialDeal(sessionId, initial);

        vm.warp(block.timestamp + 61);
        controller.claimPlayerTimeout(sessionId);

        SingleDeckBlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(SingleDeckBlackjackEngine.SessionPhase.AwaitingCoordinator));
        assertEq(session.pendingAction, engine.ACTION_STAND());
    }

    function test_BlackjackRealProofFlowUsesPrecompileAdapter() public {
        MockGroth16VerifierPrecompile precompile = _installPrecompile();
        BlackjackVerifierBundle bundle = BlackjackVerifierBundle(address(engine.VERIFIER_BUNDLE()));
        bundle.setVerifiers(address(0), address(0), address(0));

        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture();
        BlackjackActionFixture memory action = _loadBlackjackActionFixture();
        BlackjackShowdownFixture memory showdown = _loadBlackjackShowdownFixture();

        vm.prank(player);
        uint256 sessionId = controller.startHand(
            100, keccak256("blackjack-precompile"), initial.playerKeyCommitment, expressionTokenId
        );

        precompile.setExpectedCall(
            LaunchVerificationKeyHashes.BLACKJACK_INITIAL_DEAL_VK_HASH,
            _flattenProof(initial.proof),
            _blackjackInitialSignals(sessionId, initial)
        );
        _submitInitialDeal(sessionId, initial);

        vm.prank(player);
        controller.hit(sessionId);
        precompile.setExpectedCall(
            LaunchVerificationKeyHashes.BLACKJACK_ACTION_VK_HASH,
            _flattenProof(action.proof),
            _blackjackActionSignals(sessionId, action)
        );
        _submitActionProof(sessionId, action);

        vm.prank(player);
        controller.stand(sessionId);
        precompile.setExpectedCall(
            LaunchVerificationKeyHashes.BLACKJACK_SHOWDOWN_VK_HASH,
            _flattenProof(showdown.proof),
            _blackjackShowdownSignals(sessionId, showdown)
        );
        _submitShowdownProof(sessionId, showdown);

        controller.settle(sessionId);

        assertEq(token.balanceOf(player), 1_100);
        assertEq(developerRewards.epochAccrual(developerRewards.currentEpoch(), developer), 5);
    }

    function _submitInitialDeal(uint256 sessionId, BlackjackInitialDealFixture memory fixture) internal {
        _submitInitialDealWithDeck(sessionId, fixture, fixture.deckCommitment);
    }

    function _submitInitialDealWithDeck(
        uint256 sessionId,
        BlackjackInitialDealFixture memory fixture,
        bytes32 deckCommitment
    ) internal {
        engine.submitInitialDealProof(
            sessionId,
            deckCommitment,
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
    }

    function _submitActionProof(uint256 sessionId, BlackjackActionFixture memory fixture) internal {
        engine.submitActionProof(
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
    }

    function _submitShowdownProof(uint256 sessionId, BlackjackShowdownFixture memory fixture) internal {
        engine.submitShowdownProof(
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

    function _blackjackInitialSignals(uint256 sessionId, BlackjackInitialDealFixture memory fixture)
        internal
        pure
        returns (uint256[] memory signals)
    {
        signals = new uint256[](26);
        signals[0] = sessionId;
        signals[1] = uint256(fixture.handNonce);
        signals[2] = uint256(fixture.deckCommitment);
        signals[3] = uint256(fixture.playerStateCommitment);
        signals[4] = uint256(fixture.dealerStateCommitment);
        signals[5] = uint256(fixture.playerKeyCommitment);
        signals[6] = uint256(fixture.playerCiphertextRef);
        signals[7] = uint256(fixture.dealerCiphertextRef);
        signals[8] = fixture.dealerVisibleValue;
        signals[9] = fixture.handCount;
        signals[10] = fixture.activeHandIndex;
        signals[11] = fixture.payout;
        signals[12] = fixture.immediateResultCode;
        signals[13] = fixture.handValues[0];
        signals[14] = fixture.handValues[1];
        signals[15] = fixture.handValues[2];
        signals[16] = fixture.handValues[3];
        signals[17] = fixture.softMask;
        signals[18] = fixture.handStatuses[0];
        signals[19] = fixture.handStatuses[1];
        signals[20] = fixture.handStatuses[2];
        signals[21] = fixture.handStatuses[3];
        signals[22] = fixture.allowedActionMasks[0];
        signals[23] = fixture.allowedActionMasks[1];
        signals[24] = fixture.allowedActionMasks[2];
        signals[25] = fixture.allowedActionMasks[3];
    }

    function _blackjackActionSignals(uint256 sessionId, BlackjackActionFixture memory fixture)
        internal
        pure
        returns (uint256[] memory signals)
    {
        signals = new uint256[](26);
        signals[0] = sessionId;
        signals[1] = fixture.proofSequence;
        signals[2] = fixture.pendingAction;
        signals[3] = uint256(fixture.oldPlayerStateCommitment);
        signals[4] = uint256(fixture.newPlayerStateCommitment);
        signals[5] = uint256(fixture.dealerStateCommitment);
        signals[6] = uint256(fixture.playerKeyCommitment);
        signals[7] = uint256(fixture.playerCiphertextRef);
        signals[8] = uint256(fixture.dealerCiphertextRef);
        signals[9] = fixture.dealerVisibleValue;
        signals[10] = fixture.handCount;
        signals[11] = fixture.activeHandIndex;
        signals[12] = fixture.nextPhase;
        signals[13] = fixture.handValues[0];
        signals[14] = fixture.handValues[1];
        signals[15] = fixture.handValues[2];
        signals[16] = fixture.handValues[3];
        signals[17] = fixture.softMask;
        signals[18] = fixture.handStatuses[0];
        signals[19] = fixture.handStatuses[1];
        signals[20] = fixture.handStatuses[2];
        signals[21] = fixture.handStatuses[3];
        signals[22] = fixture.allowedActionMasks[0];
        signals[23] = fixture.allowedActionMasks[1];
        signals[24] = fixture.allowedActionMasks[2];
        signals[25] = fixture.allowedActionMasks[3];
    }

    function _blackjackShowdownSignals(uint256 sessionId, BlackjackShowdownFixture memory fixture)
        internal
        pure
        returns (uint256[] memory signals)
    {
        signals = new uint256[](12);
        signals[0] = sessionId;
        signals[1] = fixture.proofSequence;
        signals[2] = uint256(fixture.playerStateCommitment);
        signals[3] = uint256(fixture.dealerStateCommitment);
        signals[4] = fixture.payout;
        signals[5] = fixture.dealerFinalValue;
        signals[6] = fixture.handCount;
        signals[7] = fixture.activeHandIndex;
        signals[8] = fixture.handStatuses[0];
        signals[9] = fixture.handStatuses[1];
        signals[10] = fixture.handStatuses[2];
        signals[11] = fixture.handStatuses[3];
    }
}
