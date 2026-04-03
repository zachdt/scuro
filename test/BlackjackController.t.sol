// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeveloperExpressionRegistry} from "../src/DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "../src/DeveloperRewards.sol";
import {GameCatalog} from "../src/GameCatalog.sol";
import {GameDeploymentFactory} from "../src/GameDeploymentFactory.sol";
import {ProtocolSettlement} from "../src/ProtocolSettlement.sol";
import {ScuroToken} from "../src/ScuroToken.sol";
import {BlackjackController} from "../src/controllers/BlackjackController.sol";
import {BlackjackEngine} from "../src/engines/BlackjackEngine.sol";
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
    BlackjackEngine internal engine;
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
            configHash: keccak256("double-deck-blackjack-zk-v1"),
            developerRewardBps: 500
        });
        address controllerAddress;
        address engineAddress;
        (, controllerAddress, engineAddress, ) =
            factory.deploySoloModule(uint8(GameDeploymentFactory.SoloFamily.Blackjack), abi.encode(params));
        controller = BlackjackController(controllerAddress);
        engine = BlackjackEngine(engineAddress);

        bytes32 engineType = engine.engineType();
        vm.prank(developer);
        expressionTokenId =
            expressionRegistry.mintExpression(engineType, keccak256("double-deck-blackjack-zk-v1"), "ipfs://double-deck-blackjack-zk-v1");

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
    }

    function test_BlackjackTimeoutAutoStandsGameplayStep() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture();
        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-timeout"));
        _submitInitialDeal(sessionId, initial);

        vm.warp(block.timestamp + 61);
        controller.claimPlayerTimeout(sessionId);

        BlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(BlackjackEngine.SessionPhase.AwaitingCoordinatorAction));
        assertEq(session.pendingAction, engine.ACTION_STAND());
    }

    function test_BlackjackSplitFlowUpdatesHandCountAndBurn() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture("blackjack_initial_deal_split_pair");
        BlackjackActionFixture memory action = _loadBlackjackActionFixture("blackjack_action_resolve_split");

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-split"));
        _submitInitialDeal(sessionId, initial);

        BlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(BlackjackEngine.SessionPhase.AwaitingPlayerAction));
        assertEq(session.hands[0].allowedActionMask, engine.ALLOW_HIT() | engine.ALLOW_STAND() | engine.ALLOW_DOUBLE() | engine.ALLOW_SPLIT());
        assertEq(engine.requiredAdditionalBurn(sessionId, engine.ACTION_SPLIT()), 100);

        vm.prank(player);
        controller.split(sessionId);
        _submitActionProof(sessionId, action);

        session = engine.getSession(sessionId);
        assertEq(session.handCount, 2);
        assertEq(token.balanceOf(player), 800);
    }

    function test_BlackjackNaturalPaysBlackjackPremium() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture("blackjack_initial_deal_unsuited_natural");

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-natural"));
        _submitInitialDeal(sessionId, initial);

        BlackjackEngine.SessionView memory session = engine.getSession(sessionId);
        assertEq(session.phase, uint8(BlackjackEngine.SessionPhase.Completed));
        assertEq(session.hands[0].payoutKind, engine.HAND_PAYOUT_BLACKJACK_3_TO_2());

        controller.settle(sessionId);
        assertEq(token.balanceOf(player), 1_150);
    }

    function test_BlackjackRejectsForgedActionMaskProof() public {
        BlackjackInitialDealFixture memory initial = _loadBlackjackInitialDealFixture();
        BlackjackActionFixture memory action = _loadBlackjackActionFixture();

        uint256 sessionId = _startHand(initial.playerKeyCommitment, keccak256("blackjack-forged-action-mask"));
        _submitInitialDeal(sessionId, initial);

        vm.prank(player);
        controller.hit(sessionId);

        action.publicState.hands[0].allowedActionMask += 1;
        vm.expectRevert("Blackjack: invalid action proof");
        _submitActionProof(sessionId, action);
    }

    function _startHand(bytes32 playerKeyCommitment, bytes32 playRef) internal returns (uint256 sessionId) {
        vm.prank(player);
        sessionId = controller.startHand(100, playRef, playerKeyCommitment, expressionTokenId);
    }

    function _submitInitialDeal(uint256 sessionId, BlackjackInitialDealFixture memory fixture) internal {
        engine.submitInitialDealProof(
            sessionId,
            fixture.deckCommitment,
            fixture.handNonce,
            fixture.playerStateCommitment,
            fixture.dealerStateCommitment,
            fixture.playerCiphertextRef,
            fixture.dealerCiphertextRef,
            _toBlackjackPublicState(fixture.publicState),
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
            _toBlackjackPublicState(fixture.publicState),
            fixture.proof
        );
    }

    function _submitShowdownProof(uint256 sessionId, BlackjackShowdownFixture memory fixture) internal {
        engine.submitShowdownProof(
            sessionId,
            fixture.playerStateCommitment,
            fixture.dealerStateCommitment,
            _toBlackjackPublicState(fixture.publicState),
            fixture.proof
        );
    }
}
