// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {CheminDeFerController} from "../controllers/CheminDeFerController.sol";
import {CheminDeFerEngine} from "../engines/CheminDeFerEngine.sol";
import {ICheminDeFerModuleDeployer} from "./IModuleDeployers.sol";

contract CheminDeFerModuleDeployer is ICheminDeFerModuleDeployer {
    function deployCheminDeFerModule(
        address catalogAddress,
        address settlementAddress,
        address vrfCoordinator,
        uint256 joinWindow
    ) external returns (address controller, address engine, address verifier, bytes32 engineType) {
        CheminDeFerEngine baccaratEngine = new CheminDeFerEngine(catalogAddress, vrfCoordinator);
        CheminDeFerController baccaratController =
            new CheminDeFerController(settlementAddress, catalogAddress, address(baccaratEngine), joinWindow);

        controller = address(baccaratController);
        engine = address(baccaratEngine);
        verifier = address(0);
        engineType = baccaratEngine.engineType();
    }
}
