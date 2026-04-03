// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BlackjackEngine} from "../../src/engines/BlackjackEngine.sol";
import {FixtureLoaders} from "./FixtureLoaders.sol";

contract SubmitBlackjackAction is FixtureLoaders {
    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 sessionId = vm.envUint("SESSION_ID");
        BlackjackEngine engine = BlackjackEngine(vm.envAddress("BLACKJACK_ENGINE"));
        BlackjackActionSubmission memory submission = _loadBlackjackActionSubmission();

        vm.startBroadcast(adminKey);
        engine.submitActionProof(
            sessionId,
            submission.newPlayerStateCommitment,
            submission.dealerStateCommitment,
            submission.playerCiphertextRef,
            submission.dealerCiphertextRef,
            submission.publicState,
            submission.proof
        );
        vm.stopBroadcast();
    }
}
