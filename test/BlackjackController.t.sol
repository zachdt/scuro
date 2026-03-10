// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { CreatorRewards } from "../src/CreatorRewards.sol";
import { GameEngineRegistry } from "../src/GameEngineRegistry.sol";
import { ProtocolSettlement } from "../src/ProtocolSettlement.sol";
import { ScuroToken } from "../src/ScuroToken.sol";
import { BlackjackController } from "../src/controllers/BlackjackController.sol";
import { SingleDeckBlackjackEngine } from "../src/engines/SingleDeckBlackjackEngine.sol";
import { BlackjackVerifierBundle } from "../src/verifiers/BlackjackVerifierBundle.sol";
import { BlackjackActionResolveVerifier } from "../src/verifiers/generated/BlackjackActionResolveVerifier.sol";
import { BlackjackInitialDealVerifier } from "../src/verifiers/generated/BlackjackInitialDealVerifier.sol";
import { BlackjackShowdownVerifier } from "../src/verifiers/generated/BlackjackShowdownVerifier.sol";
import { ZkFixtureLoader } from "./helpers/ZkFixtureLoader.sol";

contract BlackjackControllerTest is ZkFixtureLoader {
    ScuroToken internal token;
    GameEngineRegistry internal registry;
    CreatorRewards internal creatorRewards;
    ProtocolSettlement internal settlement;
    BlackjackVerifierBundle internal verifierBundle;
    SingleDeckBlackjackEngine internal engine;
    BlackjackController internal controller;

    address internal creator = address(0xBEEF);
    address internal player = address(0x111);

    function setUp() public {
        token = new ScuroToken(address(this));
        registry = new GameEngineRegistry(address(this));
        creatorRewards = new CreatorRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(address(this), address(token), address(registry), address(creatorRewards));
        verifierBundle = new BlackjackVerifierBundle(
            address(this),
            address(new BlackjackInitialDealVerifier()),
            address(new BlackjackActionResolveVerifier()),
            address(new BlackjackShowdownVerifier())
        );
        engine = new SingleDeckBlackjackEngine(address(this), address(verifierBundle), 60);
        controller = new BlackjackController(address(this), address(settlement), address(registry), address(engine));

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(creatorRewards));
        creatorRewards.grantRole(creatorRewards.SETTLEMENT_ROLE(), address(settlement));
        settlement.setControllerAuthorization(address(controller), true);
        engine.grantRole(engine.CONTROLLER_ROLE(), address(controller));

        registry.registerEngine(
            address(engine),
            GameEngineRegistry.EngineMetadata({
                engineType: engine.ENGINE_TYPE(),
                creator: creator,
                verifier: address(verifierBundle),
                configHash: keccak256("single-deck-blackjack-zk"),
                creatorRateBps: 500,
                active: true,
                supportsTournament: false,
                supportsPvP: false,
                supportsSolo: true
            })
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
        uint256 sessionId = controller.startHand(100, keccak256("blackjack-hit-stand"), initial.playerKeyCommitment);
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
        assertEq(creatorRewards.epochAccrual(creatorRewards.currentEpoch(), creator), 5);
        (address settledPlayer, uint256 totalBurned, uint256 payout, bool completed) =
            engine.getSettlementOutcome(sessionId);
        assertEq(settledPlayer, player);
        assertEq(totalBurned, 100);
        assertEq(payout, 200);
        assertTrue(completed);
    }

    function test_BlackjackRejectsInvalidInitProofAndTimeoutAutoStands() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture();

        vm.prank(player);
        uint256 sessionId = controller.startHand(100, keccak256("blackjack-timeout"), initial.playerKeyCommitment);

        vm.expectRevert("Blackjack: invalid init proof");
        _submitInitialDealWithDeck(sessionId, initial, bytes32(uint256(initial.deckCommitment) + 1));

        _submitInitialDeal(sessionId, initial);

        vm.warp(block.timestamp + 61);
        controller.claimPlayerTimeout(sessionId);

        SingleDeckBlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(SingleDeckBlackjackEngine.SessionPhase.AwaitingCoordinator));
        assertEq(session.pendingAction, engine.ACTION_STAND());
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
}
