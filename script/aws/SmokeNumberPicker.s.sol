// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {NumberPickerAdapter} from "../../src/controllers/NumberPickerAdapter.sol";
import {NumberPickerEngine} from "../../src/engines/NumberPickerEngine.sol";
import {ScuroToken} from "../../src/ScuroToken.sol";

contract SmokeNumberPicker is Script {
    uint256 internal constant WAGER = 25 ether;
    uint256 internal constant DEFAULT_PLAYER1_KEY =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    function run() external {
        uint256 playerKey = vm.envOr("PLAYER1_PRIVATE_KEY", DEFAULT_PLAYER1_KEY);
        address player = vm.addr(playerKey);

        ScuroToken token = ScuroToken(vm.envAddress("SCURO_TOKEN"));
        NumberPickerAdapter adapter = NumberPickerAdapter(vm.envAddress("NUMBER_PICKER_ADAPTER"));
        NumberPickerEngine engine = NumberPickerEngine(vm.envAddress("NUMBER_PICKER_ENGINE"));
        uint256 expressionTokenId = vm.envUint("NUMBER_PICKER_EXPRESSION_TOKEN_ID");

        vm.startBroadcast(playerKey);
        token.approve(address(adapter.settlement()), type(uint256).max);
        uint256 requestId = adapter.play(WAGER, 49, keccak256("aws-number-picker-smoke"), expressionTokenId);
        vm.stopBroadcast();

        require(adapter.requestSettled(requestId), "SmokeNumberPicker: unsettled");
        (address settledPlayer, uint256 burned, uint256 payout, bool completed) = engine.getSettlementOutcome(requestId);
        require(completed, "SmokeNumberPicker: incomplete");
        require(settledPlayer == player, "SmokeNumberPicker: wrong player");
        require(burned == WAGER, "SmokeNumberPicker: wrong burn");
        require(token.balanceOf(player) >= 9_975 ether, "SmokeNumberPicker: balance too low");
        payout;
    }
}
