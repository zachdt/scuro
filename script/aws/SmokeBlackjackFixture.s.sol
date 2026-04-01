// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeveloperRewards} from "../../src/DeveloperRewards.sol";
import {ScuroToken} from "../../src/ScuroToken.sol";
import {BlackjackController} from "../../src/controllers/BlackjackController.sol";
import {SingleDeckBlackjackEngine} from "../../src/engines/SingleDeckBlackjackEngine.sol";
import {FixtureLoaders} from "./FixtureLoaders.sol";

contract SmokeBlackjackFixture is FixtureLoaders {
    uint256 internal constant BLACKJACK_WAGER = 100;
    uint256 internal constant BLACKJACK_DEVELOPER_ACCRUAL = 5;

    struct RuntimeContext {
        address player;
        address soloDeveloper;
        uint256 expressionTokenId;
        ScuroToken token;
        DeveloperRewards developerRewards;
        BlackjackController controller;
        SingleDeckBlackjackEngine engine;
    }

    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 player1Key = vm.envOr("PLAYER1_PRIVATE_KEY", DEFAULT_ANVIL_PLAYER1_KEY);
        RuntimeContext memory runtime = RuntimeContext({
            player: vm.addr(player1Key),
            soloDeveloper: vm.envAddress("SOLO_DEVELOPER"),
            expressionTokenId: vm.envUint("BLACKJACK_EXPRESSION_TOKEN_ID"),
            token: ScuroToken(vm.envAddress("SCURO_TOKEN")),
            developerRewards: DeveloperRewards(vm.envAddress("DEVELOPER_REWARDS")),
            controller: BlackjackController(vm.envAddress("BLACKJACK_CONTROLLER")),
            engine: SingleDeckBlackjackEngine(vm.envAddress("BLACKJACK_ENGINE"))
        });

        _runScenario(adminKey, player1Key, runtime);

        require(runtime.token.balanceOf(runtime.player) == (10_000 ether + 100), "SmokeBlackjackFixture: player1 balance");
        require(
            runtime.developerRewards.epochAccrual(runtime.developerRewards.currentEpoch(), runtime.soloDeveloper)
                == BLACKJACK_DEVELOPER_ACCRUAL,
            "SmokeBlackjackFixture: accrual"
        );
    }

    function _runScenario(uint256 adminKey, uint256 playerKey, RuntimeContext memory runtime) internal {
        BlackjackInitialDealFixture memory initialDeal = _loadBlackjackInitialDealFixture();
        uint256 sessionId =
            _startBlackjackHand(playerKey, runtime.controller, runtime.token, initialDeal.playerKeyCommitment, runtime.expressionTokenId);
        _submitInitialDeal(adminKey, runtime.engine, sessionId, initialDeal);

        vm.startBroadcast(playerKey);
        runtime.controller.hit(sessionId);
        vm.stopBroadcast();

        _submitAction(adminKey, runtime.engine, sessionId, _loadBlackjackActionFixture());

        vm.startBroadcast(playerKey);
        runtime.controller.stand(sessionId);
        vm.stopBroadcast();

        _submitShowdown(adminKey, runtime.controller, runtime.engine, sessionId, _loadBlackjackShowdownFixture());
    }

    function _startBlackjackHand(
        uint256 playerKey,
        BlackjackController controller,
        ScuroToken token,
        bytes32 playerKeyCommitment,
        uint256 expressionTokenId
    ) internal returns (uint256 sessionId) {
        vm.startBroadcast(playerKey);
        token.approve(address(controller.settlement()), type(uint256).max);
        sessionId = controller.startHand(
            BLACKJACK_WAGER,
            keccak256("aws-blackjack-smoke"),
            playerKeyCommitment,
            expressionTokenId
        );
        vm.stopBroadcast();
    }

    function _submitInitialDeal(
        uint256 adminKey,
        SingleDeckBlackjackEngine engine,
        uint256 sessionId,
        BlackjackInitialDealFixture memory initialDeal
    ) internal {
        vm.startBroadcast(adminKey);
        engine.submitInitialDealProof(
            sessionId,
            initialDeal.deckCommitment,
            initialDeal.handNonce,
            initialDeal.playerStateCommitment,
            initialDeal.dealerStateCommitment,
            initialDeal.playerCiphertextRef,
            initialDeal.dealerCiphertextRef,
            initialDeal.dealerVisibleValue,
            initialDeal.playerCards,
            initialDeal.dealerCards,
            initialDeal.handCount,
            initialDeal.activeHandIndex,
            initialDeal.payout,
            initialDeal.immediateResultCode,
            initialDeal.handValues,
            initialDeal.handStatuses,
            initialDeal.allowedActionMasks,
            initialDeal.handCardCounts,
            initialDeal.handPayoutKinds,
            initialDeal.dealerRevealMask,
            initialDeal.softMask,
            initialDeal.proof
        );
        vm.stopBroadcast();
    }

    function _submitAction(
        uint256 adminKey,
        SingleDeckBlackjackEngine engine,
        uint256 sessionId,
        BlackjackActionFixture memory actionFixture
    ) internal {
        vm.startBroadcast(adminKey);
        engine.submitActionProof(
            sessionId,
            actionFixture.newPlayerStateCommitment,
            actionFixture.dealerStateCommitment,
            actionFixture.playerCiphertextRef,
            actionFixture.dealerCiphertextRef,
            actionFixture.dealerVisibleValue,
            actionFixture.playerCards,
            actionFixture.dealerCards,
            actionFixture.handCount,
            actionFixture.activeHandIndex,
            actionFixture.nextPhase,
            actionFixture.handValues,
            actionFixture.handStatuses,
            actionFixture.allowedActionMasks,
            actionFixture.handCardCounts,
            actionFixture.handPayoutKinds,
            actionFixture.dealerRevealMask,
            actionFixture.softMask,
            actionFixture.proof
        );
        vm.stopBroadcast();
    }

    function _submitShowdown(
        uint256 adminKey,
        BlackjackController controller,
        SingleDeckBlackjackEngine engine,
        uint256 sessionId,
        BlackjackShowdownFixture memory showdownFixture
    ) internal {
        vm.startBroadcast(adminKey);
        engine.submitShowdownProof(
            sessionId,
            showdownFixture.playerStateCommitment,
            showdownFixture.dealerStateCommitment,
            showdownFixture.payout,
            showdownFixture.dealerFinalValue,
            showdownFixture.playerCards,
            showdownFixture.dealerCards,
            showdownFixture.handCount,
            showdownFixture.activeHandIndex,
            showdownFixture.handStatuses,
            showdownFixture.handValues,
            showdownFixture.handCardCounts,
            showdownFixture.handPayoutKinds,
            showdownFixture.dealerRevealMask,
            showdownFixture.proof
        );
        controller.settle(sessionId);
        vm.stopBroadcast();
    }
}
