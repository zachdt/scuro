// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {NumberPickerAdapter} from "../controllers/NumberPickerAdapter.sol";
import {SlotMachineController} from "../controllers/SlotMachineController.sol";
import {SuperBaccaratController} from "../controllers/SuperBaccaratController.sol";
import {NumberPickerEngine} from "../engines/NumberPickerEngine.sol";
import {SlotMachineEngine} from "../engines/SlotMachineEngine.sol";
import {SuperBaccaratEngine} from "../engines/SuperBaccaratEngine.sol";
import {ISoloModuleDeployer} from "./IModuleDeployers.sol";

contract SoloModuleDeployer is ISoloModuleDeployer {
    function deployNumberPickerModule(address catalogAddress, address settlementAddress, address vrfCoordinator)
        external
        returns (address controller, address engine, address verifier, bytes32 engineType)
    {
        NumberPickerEngine numberPickerEngine = new NumberPickerEngine(catalogAddress, vrfCoordinator);
        NumberPickerAdapter numberPickerAdapter =
            new NumberPickerAdapter(settlementAddress, catalogAddress, address(numberPickerEngine));

        controller = address(numberPickerAdapter);
        engine = address(numberPickerEngine);
        verifier = address(0);
        engineType = numberPickerEngine.engineType();
    }

    function deploySuperBaccaratModule(address catalogAddress, address settlementAddress, address vrfCoordinator)
        external
        returns (address controller, address engine, address verifier, bytes32 engineType)
    {
        SuperBaccaratEngine baccaratEngine = new SuperBaccaratEngine(catalogAddress, vrfCoordinator);
        SuperBaccaratController baccaratController =
            new SuperBaccaratController(settlementAddress, catalogAddress, address(baccaratEngine));

        controller = address(baccaratController);
        engine = address(baccaratEngine);
        verifier = address(0);
        engineType = baccaratEngine.engineType();
    }

    function deploySlotMachineModule(address catalogAddress, address settlementAddress, address vrfCoordinator, address admin)
        external
        returns (address controller, address engine, address verifier, bytes32 engineType)
    {
        SlotMachineEngine slotEngine = new SlotMachineEngine(admin, catalogAddress, vrfCoordinator);
        SlotMachineController slotController = new SlotMachineController(settlementAddress, catalogAddress, address(slotEngine));

        controller = address(slotController);
        engine = address(slotEngine);
        verifier = address(0);
        engineType = slotEngine.engineType();
    }
}
