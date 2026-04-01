// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SingleDeckBlackjackEngine} from "../../src/engines/SingleDeckBlackjackEngine.sol";
import {FixtureLoaders} from "./FixtureLoaders.sol";

contract SubmitBlackjackShowdown is FixtureLoaders {
    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 sessionId = vm.envUint("SESSION_ID");
        SingleDeckBlackjackEngine engine = SingleDeckBlackjackEngine(vm.envAddress("BLACKJACK_ENGINE"));
        BlackjackShowdownFixture memory fixture = _loadBlackjackShowdownFixture();

        vm.startBroadcast(adminKey);
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
        vm.stopBroadcast();
    }
}
