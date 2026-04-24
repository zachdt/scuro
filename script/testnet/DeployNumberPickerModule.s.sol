// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { GameCatalog } from "../../src/GameCatalog.sol";
import { NumberPickerAdapter } from "../../src/controllers/NumberPickerAdapter.sol";
import { NumberPickerEngine } from "../../src/engines/NumberPickerEngine.sol";
import { TestnetDeployCommon } from "./TestnetDeployCommon.s.sol";

contract DeployNumberPickerModule is TestnetDeployCommon {
    function run() external {
        uint256 deployerPrivateKey = adminPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        logStage("DeployNumberPickerModule");
        GameCatalog catalog = GameCatalog(envAddress("GameCatalog"));
        address settlement = envAddress("ProtocolSettlement");
        address vrfCoordinator = envAddress("VRFCoordinatorMock");

        logStageAction("NumberPicker:Engine");
        NumberPickerEngine numberPickerEngine = new NumberPickerEngine(address(catalog), vrfCoordinator);
        logStageAction("NumberPicker:Adapter");
        NumberPickerAdapter numberPickerAdapter =
            new NumberPickerAdapter(settlement, address(catalog), address(numberPickerEngine));
        logStageAction("NumberPicker:RegisterModule");
        uint256 moduleId = catalog.registerModule(
            GameCatalog.Module({
                controller: address(numberPickerAdapter),
                engine: address(numberPickerEngine),
                engineType: numberPickerEngine.engineType(),
                configHash: keccak256("number-picker-auto"),
                developerRewardBps: 500,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        logAddress("NumberPickerEngine", address(numberPickerEngine));
        logAddress("NumberPickerAdapter", address(numberPickerAdapter));
        logUint("NumberPickerModuleId", moduleId);

        vm.stopBroadcast();
    }
}
