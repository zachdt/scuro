// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeveloperExpressionRegistry} from "../src/DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "../src/DeveloperRewards.sol";
import {GameCatalog} from "../src/GameCatalog.sol";
import {GameDeploymentFactory} from "../src/GameDeploymentFactory.sol";
import {ProtocolSettlement} from "../src/ProtocolSettlement.sol";
import {ScuroToken} from "../src/ScuroToken.sol";
import {BlackjackController} from "../src/controllers/BlackjackController.sol";
import {SingleDeckBlackjackEngine} from "../src/engines/SingleDeckBlackjackEngine.sol";
import {BlackjackModuleDeployer} from "../src/factory/BlackjackModuleDeployer.sol";
import {CheminDeFerModuleDeployer} from "../src/factory/CheminDeFerModuleDeployer.sol";
import {PokerModuleDeployer} from "../src/factory/PokerModuleDeployer.sol";
import {SoloModuleDeployer} from "../src/factory/SoloModuleDeployer.sol";
import {ZkFixtureLoader} from "./helpers/ZkFixtureLoader.sol";

contract BlackjackControllerTest is ZkFixtureLoader {
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
        settlement = new ProtocolSettlement(address(token), address(catalog), address(expressionRegistry), address(developerRewards));
        factory = new GameDeploymentFactory(
            address(this),
            address(catalog),
            address(settlement),
            address(new SoloModuleDeployer()),
            address(new BlackjackModuleDeployer()),
            address(new PokerModuleDeployer()),
            address(new CheminDeFerModuleDeployer())
        );
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(factory));

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));

        GameDeploymentFactory.BlackjackDeployment memory params = GameDeploymentFactory.BlackjackDeployment({
            coordinator: address(this),
            defaultActionWindow: 60,
            configHash: keccak256("single-deck-blackjack-zk-v2"),
            developerRewardBps: 500
        });
        address controllerAddress;
        address engineAddress;
        (, controllerAddress, engineAddress, ) =
            factory.deploySoloModule(uint8(GameDeploymentFactory.SoloFamily.Blackjack), abi.encode(params));
        controller = BlackjackController(controllerAddress);
        engine = SingleDeckBlackjackEngine(engineAddress);

        bytes32 engineType = engine.engineType();
        vm.prank(developer);
        expressionTokenId =
            expressionRegistry.mintExpression(
                engineType,
                keccak256("single-deck-blackjack-zk-v2"),
                "ipfs://single-deck-blackjack-zk-v2"
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
        (address settledPlayer, uint256 totalBurned, uint256 payout, bool completed) = engine.getSettlementOutcome(sessionId);
        assertEq(settledPlayer, player);
        assertEq(totalBurned, 100);
        assertEq(payout, 200);
        assertTrue(completed);
        assertEq(controller.sessionExpressionTokenId(sessionId), expressionTokenId);
    }

    function test_BlackjackRejectsInvalidInitProofAndTimeoutAutoStands() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture();

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-timeout"));

        vm.expectRevert("Blackjack: invalid init proof");
        _submitInitialDealWithDeck(sessionId, initial, bytes32(uint256(initial.deckCommitment) + 1));

        _submitInitialDeal(sessionId, initial);

        vm.warp(block.timestamp + 61);
        controller.claimPlayerTimeout(sessionId);

        SingleDeckBlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(SingleDeckBlackjackEngine.SessionPhase.AwaitingCoordinator));
        assertEq(session.pendingAction, engine.ACTION_STAND());
    }

    function test_BlackjackSuitedNaturalPaysTwoToOne() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture("blackjack_initial_deal_suited_natural");

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-suited-natural"));
        _submitInitialDeal(sessionId, initial);

        SingleDeckBlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(SingleDeckBlackjackEngine.SessionPhase.Completed));
        assertEq(session.payout, 300);
        assertEq(session.hands[0].payoutKind, engine.HAND_PAYOUT_SUITED_BLACKJACK_2_TO_1());
        assertEq(session.dealerRevealMask, 3);
        assertEq(session.dealerCards[0], initial.dealerCards[0]);
        assertEq(session.dealerCards[1], initial.dealerCards[1]);

        controller.settle(sessionId);
        assertEq(token.balanceOf(player), 1_200);
    }

    function test_BlackjackUnsuitedNaturalPaysThreeToTwo() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture("blackjack_initial_deal_unsuited_natural");

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-unsuited-natural"));
        _submitInitialDeal(sessionId, initial);

        SingleDeckBlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(SingleDeckBlackjackEngine.SessionPhase.Completed));
        assertEq(session.payout, 250);
        assertEq(session.hands[0].payoutKind, engine.HAND_PAYOUT_BLACKJACK_3_TO_2());
        assertEq(session.dealerRevealMask, 3);

        controller.settle(sessionId);
        assertEq(token.balanceOf(player), 1_150);
    }

    function test_BlackjackDealerNaturalPushesEvenAgainstSuitedBlackjack() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture("blackjack_initial_deal_push_natural");

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-push-natural"));
        _submitInitialDeal(sessionId, initial);

        SingleDeckBlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(SingleDeckBlackjackEngine.SessionPhase.Completed));
        assertEq(session.payout, 100);
        assertEq(session.hands[0].payoutKind, engine.HAND_PAYOUT_PUSH());
        assertEq(session.immediateResultCode, 3);

        controller.settle(sessionId);
        assertEq(token.balanceOf(player), 1_000);
    }

    function test_BlackjackSplitEligibilityAndRevealStateDeriveFromCards() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture("blackjack_initial_deal_split_pair");
        BlackjackActionFixture memory action = _loadBlackjackActionFixture("blackjack_action_resolve_split");

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-split"));
        _submitInitialDeal(sessionId, initial);

        SingleDeckBlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(SingleDeckBlackjackEngine.SessionPhase.AwaitingPlayerAction));
        assertEq(session.dealerRevealMask, 1);
        assertEq(session.dealerCards[0], initial.dealerCards[0]);
        assertEq(session.dealerCards[1], engine.CARD_EMPTY());
        assertEq(session.hands[0].cardCount, 2);
        assertEq(session.hands[0].payoutKind, engine.HAND_PAYOUT_NONE());
        assertEq(session.hands[0].allowedActionMask, engine.ALLOW_HIT() | engine.ALLOW_STAND() | engine.ALLOW_DOUBLE() | engine.ALLOW_SPLIT());
        assertEq(engine.requiredAdditionalBurn(sessionId, engine.ACTION_SPLIT()), 100);

        vm.prank(player);
        controller.split(sessionId);
        _submitActionProof(sessionId, action);

        session = engine.getSession(sessionId);
        assertEq(session.handCount, 2);
        assertEq(session.activeHandIndex, 1);
        assertEq(session.dealerRevealMask, 1);
        assertEq(session.hands[0].cardCount, 2);
        assertEq(session.hands[1].cardCount, 2);
        assertEq(session.hands[0].payoutKind, engine.HAND_PAYOUT_NONE());
        assertEq(session.hands[1].payoutKind, engine.HAND_PAYOUT_NONE());
        assertEq(session.hands[1].allowedActionMask, engine.ALLOW_HIT() | engine.ALLOW_STAND() | engine.ALLOW_DOUBLE());
        assertEq(token.balanceOf(player), 800);
    }

    function test_BlackjackShowdownRevealsDealerHoleAndFinalCards() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture();
        BlackjackActionFixture memory action = _loadBlackjackActionFixture();
        BlackjackShowdownFixture memory showdown = _loadBlackjackShowdownFixture();

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-reveal"));
        _submitInitialDeal(sessionId, initial);

        SingleDeckBlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.dealerRevealMask, 1);
        assertEq(session.dealerCards[1], engine.CARD_EMPTY());

        vm.prank(player);
        controller.hit(sessionId);
        _submitActionProof(sessionId, action);

        session = engine.getSession(sessionId);
        assertEq(session.dealerRevealMask, 1);
        assertEq(session.dealerCards[1], engine.CARD_EMPTY());

        vm.prank(player);
        controller.stand(sessionId);
        _submitShowdownProof(sessionId, showdown);

        session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(SingleDeckBlackjackEngine.SessionPhase.Completed));
        assertEq(session.dealerRevealMask, 7);
        assertEq(session.dealerCards[0], showdown.dealerCards[0]);
        assertEq(session.dealerCards[1], showdown.dealerCards[1]);
        assertEq(session.dealerCards[2], showdown.dealerCards[2]);
    }

    function test_BlackjackRejectsForgedInitialPayoutKindProof() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture("blackjack_initial_deal_suited_natural");
        initial.handPayoutKinds[0] = engine.HAND_PAYOUT_BLACKJACK_3_TO_2();

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-forged-init-kind"));
        vm.expectRevert("Blackjack: invalid init proof");
        _submitInitialDeal(sessionId, initial);
    }

    function test_BlackjackRejectsForgedActionMaskProof() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture();
        BlackjackActionFixture memory action = _loadBlackjackActionFixture();

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-forged-action-mask"));
        _submitInitialDeal(sessionId, initial);

        vm.prank(player);
        controller.hit(sessionId);

        action.allowedActionMasks[0] += 1;
        vm.expectRevert("Blackjack: invalid action proof");
        _submitActionProof(sessionId, action);
    }

    function test_BlackjackRejectsForgedShowdownPayoutProof() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture();
        BlackjackActionFixture memory action = _loadBlackjackActionFixture();
        BlackjackShowdownFixture memory showdown = _loadBlackjackShowdownFixture();

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-forged-showdown-payout"));
        _submitInitialDeal(sessionId, initial);

        vm.prank(player);
        controller.hit(sessionId);
        _submitActionProof(sessionId, action);

        vm.prank(player);
        controller.stand(sessionId);

        showdown.payout += 1;
        vm.expectRevert("Blackjack: invalid showdown proof");
        _submitShowdownProof(sessionId, showdown);
    }

    function _startHand(bytes32 playerKeyCommitment, bytes32 playRef) internal returns (uint256 sessionId) {
        vm.prank(player);
        sessionId = controller.startHand(100, playRef, playerKeyCommitment, expressionTokenId);
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
            fixture.playerCards,
            fixture.dealerCards,
            fixture.handCount,
            fixture.activeHandIndex,
            fixture.payout,
            fixture.immediateResultCode,
            fixture.handValues,
            fixture.handStatuses,
            fixture.allowedActionMasks,
            fixture.handCardCounts,
            fixture.handPayoutKinds,
            fixture.dealerRevealMask,
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
            fixture.playerCards,
            fixture.dealerCards,
            fixture.handCount,
            fixture.activeHandIndex,
            fixture.nextPhase,
            fixture.handValues,
            fixture.handStatuses,
            fixture.allowedActionMasks,
            fixture.handCardCounts,
            fixture.handPayoutKinds,
            fixture.dealerRevealMask,
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
            fixture.playerCards,
            fixture.dealerCards,
            fixture.handCount,
            fixture.activeHandIndex,
            fixture.handStatuses,
            fixture.handValues,
            fixture.handCardCounts,
            fixture.handPayoutKinds,
            fixture.dealerRevealMask,
            fixture.proof
        );
    }
}
