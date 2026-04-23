// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {NumberPickerAdapter} from "../controllers/NumberPickerAdapter.sol";
import {SlotMachineController} from "../controllers/SlotMachineController.sol";
import {NumberPickerEngine} from "../engines/NumberPickerEngine.sol";
import {SlotMachineEngine} from "../engines/SlotMachineEngine.sol";
import {ISoloModuleDeployer} from "./IModuleDeployers.sol";

contract SoloModuleDeployer is ISoloModuleDeployer {
    function deployNumberPickerModule(address catalogAddress, address settlementAddress, address vrfCoordinator)
        external
        returns (address controller, address engine, bytes32 engineType)
    {
        NumberPickerEngine numberPickerEngine = new NumberPickerEngine(catalogAddress, vrfCoordinator);
        NumberPickerAdapter numberPickerAdapter =
            new NumberPickerAdapter(settlementAddress, catalogAddress, address(numberPickerEngine));

        controller = address(numberPickerAdapter);
        engine = address(numberPickerEngine);
        engineType = numberPickerEngine.engineType();
    }

    function deploySlotMachineModule(address catalogAddress, address settlementAddress, address vrfCoordinator, address admin)
        external
        returns (address controller, address engine, bytes32 engineType)
    {
        SlotMachineEngine slotEngine = new SlotMachineEngine(admin, catalogAddress, vrfCoordinator);
        SlotMachineController slotController = new SlotMachineController(settlementAddress, catalogAddress, address(slotEngine));

        controller = address(slotController);
        engine = address(slotEngine);
        engineType = slotEngine.engineType();
    }
}
