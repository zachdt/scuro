// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameDeploymentFactory} from "../../src/GameDeploymentFactory.sol";
import {BetaDeployCommon} from "./BetaDeployCommon.s.sol";

contract DeployNumberPickerModule is BetaDeployCommon {
    function run() external {
        uint256 deployerPrivateKey = adminPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        logStage("DeployNumberPickerModule");
        GameDeploymentFactory factory = GameDeploymentFactory(envAddress("GameDeploymentFactory"));
        logStageAction("NumberPicker:DeployModule");
        (uint256 moduleId, address controller, address engine) = factory.deploySoloModule(
            uint8(GameDeploymentFactory.SoloFamily.NumberPicker),
            abi.encode(
                GameDeploymentFactory.NumberPickerDeployment({
                    vrfCoordinator: envAddress("VRFCoordinatorMock"),
                    configHash: keccak256("number-picker-auto"),
                    developerRewardBps: 500
                })
            )
        );

        logAddress("NumberPickerEngine", engine);
        logAddress("NumberPickerAdapter", controller);
        logUint("NumberPickerModuleId", moduleId);

        vm.stopBroadcast();
    }
}
