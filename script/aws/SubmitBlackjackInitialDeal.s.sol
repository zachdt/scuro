// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BlackjackEngine} from "../../src/engines/BlackjackEngine.sol";
import {FixtureLoaders} from "./FixtureLoaders.sol";

contract SubmitBlackjackInitialDeal is FixtureLoaders {
    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 sessionId = vm.envUint("SESSION_ID");
        BlackjackEngine engine = BlackjackEngine(vm.envAddress("BLACKJACK_ENGINE"));
        BlackjackInitialDealSubmission memory submission = _loadBlackjackInitialDealSubmission();

        vm.startBroadcast(adminKey);
        engine.submitInitialDealProof(
            sessionId,
            submission.deckCommitment,
            submission.handNonce,
            submission.playerStateCommitment,
            submission.dealerStateCommitment,
            submission.playerCiphertextRef,
            submission.dealerCiphertextRef,
            submission.publicState,
            submission.proof
        );
        vm.stopBroadcast();
    }
}
