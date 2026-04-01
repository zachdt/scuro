// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SingleDeckBlackjackEngine} from "../../src/engines/SingleDeckBlackjackEngine.sol";
import {FixtureLoaders} from "./FixtureLoaders.sol";

contract SubmitBlackjackAction is FixtureLoaders {
    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 sessionId = vm.envUint("SESSION_ID");
        SingleDeckBlackjackEngine engine = SingleDeckBlackjackEngine(vm.envAddress("BLACKJACK_ENGINE"));
        BlackjackActionFixture memory fixture = _loadBlackjackActionFixture();

        vm.startBroadcast(adminKey);
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
        vm.stopBroadcast();
    }
}
