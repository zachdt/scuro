// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { GameCatalog } from "../../src/GameCatalog.sol";
import { SlotMachineController } from "../../src/controllers/SlotMachineController.sol";
import { SlotMachineEngine } from "../../src/engines/SlotMachineEngine.sol";
import { SlotMachinePresets } from "../../src/libraries/SlotMachinePresets.sol";
import { TestnetDeployCommon } from "./TestnetDeployCommon.s.sol";

contract DeploySlotModule is TestnetDeployCommon {
    function run() external {
        uint256 deployerPrivateKey = adminPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        logStage("DeploySlotModule");
        GameCatalog catalog = GameCatalog(envAddress("GameCatalog"));
        address settlement = envAddress("ProtocolSettlement");
        address vrfCoordinator = envAddress("VRFCoordinatorMock");

        logStageAction("SlotMachine:Engine");
        SlotMachineEngine slotEngine =
            new SlotMachineEngine(vm.addr(deployerPrivateKey), address(catalog), vrfCoordinator);
        logStageAction("SlotMachine:Controller");
        SlotMachineController slotController =
            new SlotMachineController(settlement, address(catalog), address(slotEngine));
        logStageAction("SlotMachine:RegisterModule");
        uint256 moduleId = catalog.registerModule(
            GameCatalog.Module({
                controller: address(slotController),
                engine: address(slotEngine),
                engineType: slotEngine.engineType(),
                configHash: keccak256("slot-machine-auto"),
                developerRewardBps: 500,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        logStageAction("SlotMachine:RegisterBasePreset");
        uint256 basePresetId = slotEngine.registerPreset(SlotMachinePresets.basePreset(1));
        logStageAction("SlotMachine:RegisterFreePreset");
        uint256 freePresetId = slotEngine.registerPreset(SlotMachinePresets.freeSpinPreset(2));
        logStageAction("SlotMachine:RegisterPickPreset");
        uint256 pickPresetId = slotEngine.registerPreset(SlotMachinePresets.pickPreset(3));
        logStageAction("SlotMachine:RegisterHoldPreset");
        uint256 holdPresetId = slotEngine.registerPreset(SlotMachinePresets.holdPreset(4));

        logAddress("SlotMachineEngine", address(slotEngine));
        logAddress("SlotMachineController", address(slotController));
        logUint("SlotMachineModuleId", moduleId);
        logUint("SlotBasePresetId", basePresetId);
        logUint("SlotFreePresetId", freePresetId);
        logUint("SlotPickPresetId", pickPresetId);
        logUint("SlotHoldPresetId", holdPresetId);

        vm.stopBroadcast();
    }
}
