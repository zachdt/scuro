// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface ISoloModuleDeployer {
    function deployNumberPickerModule(address catalogAddress, address settlementAddress, address vrfCoordinator)
        external
        returns (address controller, address engine, bytes32 engineType);

    function deploySlotMachineModule(address catalogAddress, address settlementAddress, address vrfCoordinator, address admin)
        external
        returns (address controller, address engine, bytes32 engineType);
}
