// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameDeploymentFactory} from "../../src/GameDeploymentFactory.sol";
import {SlotMachineEngine} from "../../src/engines/SlotMachineEngine.sol";
import {SlotMachinePresets} from "../../src/libraries/SlotMachinePresets.sol";
import {BetaDeployCommon} from "./BetaDeployCommon.s.sol";

contract DeploySlotModule is BetaDeployCommon {
    function run() external {
        uint256 deployerPrivateKey = adminPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        logStage("DeploySlotModule");
        GameDeploymentFactory factory = GameDeploymentFactory(envAddress("GameDeploymentFactory"));
        logStageAction("SlotMachine:DeployModule");
        (uint256 moduleId, address controller, address engine) = factory.deploySoloModule(
            uint8(GameDeploymentFactory.SoloFamily.SlotMachine),
            abi.encode(
                GameDeploymentFactory.SlotDeployment({
                    vrfCoordinator: envAddress("VRFCoordinatorMock"),
                    configHash: keccak256("slot-machine-auto"),
                    developerRewardBps: 500
                })
            )
        );

        SlotMachineEngine slotEngine = SlotMachineEngine(engine);
        logStageAction("SlotMachine:RegisterBasePreset");
        uint256 basePresetId = slotEngine.registerPreset(SlotMachinePresets.basePreset(1));
        logStageAction("SlotMachine:RegisterFreePreset");
        uint256 freePresetId = slotEngine.registerPreset(SlotMachinePresets.freeSpinPreset(2));
        logStageAction("SlotMachine:RegisterPickPreset");
        uint256 pickPresetId = slotEngine.registerPreset(SlotMachinePresets.pickPreset(3));
        logStageAction("SlotMachine:RegisterHoldPreset");
        uint256 holdPresetId = slotEngine.registerPreset(SlotMachinePresets.holdPreset(4));

        logAddress("SlotMachineEngine", engine);
        logAddress("SlotMachineController", controller);
        logUint("SlotMachineModuleId", moduleId);
        logUint("SlotBasePresetId", basePresetId);
        logUint("SlotFreePresetId", freePresetId);
        logUint("SlotPickPresetId", pickPresetId);
        logUint("SlotHoldPresetId", holdPresetId);

        vm.stopBroadcast();
    }
}
