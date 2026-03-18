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

    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 player1Key = vm.envOr("PLAYER1_PRIVATE_KEY", DEFAULT_ANVIL_PLAYER1_KEY);
        address player1 = vm.addr(player1Key);
        address soloDeveloper = vm.envAddress("SOLO_DEVELOPER");

        ScuroToken token = ScuroToken(vm.envAddress("SCURO_TOKEN"));
        DeveloperRewards developerRewards = DeveloperRewards(vm.envAddress("DEVELOPER_REWARDS"));
        BlackjackController controller = BlackjackController(vm.envAddress("BLACKJACK_CONTROLLER"));
        SingleDeckBlackjackEngine engine = SingleDeckBlackjackEngine(vm.envAddress("BLACKJACK_ENGINE"));
        uint256 expressionTokenId = vm.envUint("BLACKJACK_EXPRESSION_TOKEN_ID");

        BlackjackInitialDealFixture memory initialDeal = _loadBlackjackInitialDealFixture();

        vm.startBroadcast(player1Key);
        token.approve(address(controller.settlement()), type(uint256).max);
        uint256 sessionId = controller.startHand(
            BLACKJACK_WAGER,
            keccak256("aws-blackjack-smoke"),
            initialDeal.playerKeyCommitment,
            expressionTokenId
        );
        vm.stopBroadcast();

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
            initialDeal.handCount,
            initialDeal.activeHandIndex,
            initialDeal.payout,
            initialDeal.immediateResultCode,
            initialDeal.handValues,
            initialDeal.handStatuses,
            initialDeal.allowedActionMasks,
            initialDeal.softMask,
            initialDeal.proof
        );
        vm.stopBroadcast();

        vm.startBroadcast(player1Key);
        controller.hit(sessionId);
        vm.stopBroadcast();

        BlackjackActionFixture memory actionFixture = _loadBlackjackActionFixture();
        vm.startBroadcast(adminKey);
        engine.submitActionProof(
            sessionId,
            actionFixture.newPlayerStateCommitment,
            actionFixture.dealerStateCommitment,
            actionFixture.playerCiphertextRef,
            actionFixture.dealerCiphertextRef,
            actionFixture.dealerVisibleValue,
            actionFixture.handCount,
            actionFixture.activeHandIndex,
            actionFixture.nextPhase,
            actionFixture.handValues,
            actionFixture.handStatuses,
            actionFixture.allowedActionMasks,
            actionFixture.softMask,
            actionFixture.proof
        );
        vm.stopBroadcast();

        vm.startBroadcast(player1Key);
        controller.stand(sessionId);
        vm.stopBroadcast();

        BlackjackShowdownFixture memory showdownFixture = _loadBlackjackShowdownFixture();
        vm.startBroadcast(adminKey);
        engine.submitShowdownProof(
            sessionId,
            showdownFixture.playerStateCommitment,
            showdownFixture.dealerStateCommitment,
            showdownFixture.payout,
            showdownFixture.dealerFinalValue,
            showdownFixture.handCount,
            showdownFixture.activeHandIndex,
            showdownFixture.handStatuses,
            showdownFixture.proof
        );
        controller.settle(sessionId);
        vm.stopBroadcast();

        require(token.balanceOf(player1) == (10_000 ether + 100), "SmokeBlackjackFixture: player1 balance");
        require(
            developerRewards.epochAccrual(developerRewards.currentEpoch(), soloDeveloper) == BLACKJACK_DEVELOPER_ACCRUAL,
            "SmokeBlackjackFixture: accrual"
        );
    }
}
