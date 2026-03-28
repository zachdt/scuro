// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameDeploymentFactory} from "../../src/GameDeploymentFactory.sol";
import {BetaDeployCommon} from "./BetaDeployCommon.s.sol";

contract DeployPokerPvPModule is BetaDeployCommon {
    function run() external {
        uint256 deployerPrivateKey = adminPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        logStage("DeployPokerPvPModule");
        GameDeploymentFactory factory = GameDeploymentFactory(envAddress("GameDeploymentFactory"));
        logStageAction("PvPPoker:DeployModule");
        (uint256 moduleId, address controller, address engine, address verifierBundle) = factory.deployPvPModule(
            uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7),
            abi.encode(
                GameDeploymentFactory.PokerDeployment({
                    coordinator: adminAddress(),
                    smallBlind: 10,
                    bigBlind: 20,
                    blindEscalationInterval: 180,
                    actionWindow: 60,
                    configHash: keccak256("single-draw-2-7-pvp"),
                    developerRewardBps: 1_000
                })
            )
        );

        logAddress("PvPController", controller);
        logAddress("PvPPokerEngine", engine);
        logAddress("PvPPokerVerifierBundle", verifierBundle);
        logUint("PvPPokerModuleId", moduleId);

        vm.stopBroadcast();
    }
}
