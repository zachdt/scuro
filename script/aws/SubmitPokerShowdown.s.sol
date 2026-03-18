// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SingleDraw2To7Engine} from "../../src/engines/SingleDraw2To7Engine.sol";
import {FixtureLoaders} from "./FixtureLoaders.sol";

contract SubmitPokerShowdown is FixtureLoaders {
    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        uint256 gameId = vm.envUint("GAME_ID");
        address winner = vm.envAddress("WINNER_ADDRESS");
        SingleDraw2To7Engine engine = SingleDraw2To7Engine(vm.envAddress("TOURNAMENT_POKER_ENGINE"));
        PokerShowdownFixture memory fixture = _loadPokerShowdownFixture();

        vm.startBroadcast(adminKey);
        engine.submitShowdownProof(gameId, winner, fixture.isTie, fixture.proof);
        vm.stopBroadcast();
    }
}
