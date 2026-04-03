// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BlackjackEngine} from "../../src/engines/BlackjackEngine.sol";
import {FixtureLoaders} from "./FixtureLoaders.sol";

contract SubmitBlackjackShowdown is FixtureLoaders {
    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 sessionId = vm.envUint("SESSION_ID");
        BlackjackEngine engine = BlackjackEngine(vm.envAddress("BLACKJACK_ENGINE"));
        BlackjackShowdownSubmission memory submission = _loadBlackjackShowdownSubmission();

        vm.startBroadcast(adminKey);
        engine.submitShowdownProof(
            sessionId,
            submission.playerStateCommitment,
            submission.dealerStateCommitment,
            submission.publicState,
            submission.proof
        );
        vm.stopBroadcast();
    }
}
