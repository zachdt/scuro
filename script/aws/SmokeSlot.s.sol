// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ScuroToken} from "../../src/ScuroToken.sol";
import {SlotMachineController} from "../../src/controllers/SlotMachineController.sol";
import {SlotMachineEngine} from "../../src/engines/SlotMachineEngine.sol";

contract SmokeSlot is Script {
    uint256 internal constant WAGER = 25 ether;

    function run() external {
        uint256 playerPrivateKey = vm.envUint("PLAYER1_PRIVATE_KEY");
        address player = vm.addr(playerPrivateKey);

        vm.startBroadcast(playerPrivateKey);

        ScuroToken token = ScuroToken(vm.envAddress("SCURO_TOKEN"));
        SlotMachineController controller = SlotMachineController(vm.envAddress("SLOT_MACHINE_CONTROLLER"));
        SlotMachineEngine engine = SlotMachineEngine(vm.envAddress("SLOT_MACHINE_ENGINE"));
        uint256 expressionTokenId = vm.envUint("SLOT_MACHINE_EXPRESSION_TOKEN_ID");
        uint256 presetId = vm.envOr("SLOT_BASE_PRESET_ID", uint256(1));

        token.approve(vm.envAddress("PROTOCOL_SETTLEMENT"), WAGER);
        uint256 spinId = controller.spin(WAGER, presetId, keccak256("aws-slot-smoke"), expressionTokenId);

        SlotMachineEngine.Spin memory spinData = engine.getSpin(spinId);
        require(spinData.resolved, "SmokeSlot: unresolved");
        require(controller.spinSettled(spinId), "SmokeSlot: unsettled");
        require(spinData.player == player, "SmokeSlot: wrong player");
        require(spinData.stake == WAGER, "SmokeSlot: wrong stake");
        require(token.balanceOf(player) >= 9_975 ether, "SmokeSlot: balance too low");

        vm.stopBroadcast();
    }
}
