// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SingleDraw2To7Engine} from "../../src/engines/SingleDraw2To7Engine.sol";
import {FixtureLoaders} from "./FixtureLoaders.sol";

contract SubmitPokerInitialDeal is FixtureLoaders {
    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 gameId = vm.envUint("GAME_ID");
        SingleDraw2To7Engine engine = SingleDraw2To7Engine(vm.envAddress("TOURNAMENT_POKER_ENGINE"));
        PokerInitialDealFixture memory fixture = _loadPokerInitialDealFixture();

        vm.startBroadcast(adminKey);
        engine.submitInitialDealProof(
            gameId,
            fixture.deckCommitment,
            fixture.handNonce,
            fixture.handCommitments,
            fixture.encryptionKeyCommitments,
            fixture.ciphertextRefs,
            fixture.proof
        );
        vm.stopBroadcast();
    }
}
