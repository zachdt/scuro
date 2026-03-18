// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SingleDraw2To7Engine} from "../../src/engines/SingleDraw2To7Engine.sol";
import {FixtureLoaders} from "./FixtureLoaders.sol";

contract SubmitPokerDraw is FixtureLoaders {
    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 gameId = vm.envUint("GAME_ID");
        address player = vm.envAddress("PLAYER_ADDRESS");
        string memory fixtureName = vm.envString("DRAW_FIXTURE_NAME");
        SingleDraw2To7Engine engine = SingleDraw2To7Engine(vm.envAddress("TOURNAMENT_POKER_ENGINE"));
        PokerDrawFixture memory fixture = _loadPokerDrawFixture(fixtureName);

        vm.startBroadcast(adminKey);
        engine.submitDrawProof(
            gameId,
            player,
            fixture.newCommitment,
            fixture.newEncryptionKeyCommitment,
            fixture.newCiphertextRef,
            fixture.proof
        );
        vm.stopBroadcast();
    }
}
