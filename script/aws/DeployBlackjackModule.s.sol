// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameDeploymentFactory} from "../../src/GameDeploymentFactory.sol";
import {BetaDeployCommon} from "./BetaDeployCommon.s.sol";

contract DeployBlackjackModule is BetaDeployCommon {
    function run() external {
        uint256 deployerPrivateKey = adminPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        logStage("DeployBlackjackModule");
        GameDeploymentFactory factory = GameDeploymentFactory(envAddress("GameDeploymentFactory"));
        logStageAction("Blackjack:DeployModule");
        (uint256 moduleId, address controller, address engine, address verifierBundle) = factory.deploySoloModule(
            uint8(GameDeploymentFactory.SoloFamily.Blackjack),
            abi.encode(
                GameDeploymentFactory.BlackjackDeployment({
                    coordinator: adminAddress(),
                    defaultActionWindow: 60,
                    configHash: keccak256("single-deck-blackjack-zk-v2"),
                    developerRewardBps: 500
                })
            )
        );

        logAddress("BlackjackVerifierBundle", verifierBundle);
        logAddress("SingleDeckBlackjackEngine", engine);
        logAddress("BlackjackController", controller);
        logUint("BlackjackModuleId", moduleId);

        vm.stopBroadcast();
    }
}
