// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {GameDeploymentFactory} from "../../src/GameDeploymentFactory.sol";
import {BetaDeployCommon} from "./BetaDeployCommon.s.sol";

contract DeployPokerTournamentModule is BetaDeployCommon {
    function run() external {
        uint256 deployerPrivateKey = adminPrivateKey();
        vm.startBroadcast(deployerPrivateKey);

        logStage("DeployPokerTournamentModule");
        GameDeploymentFactory factory = GameDeploymentFactory(envAddress("GameDeploymentFactory"));
        logStageAction("TournamentPoker:DeployModule");
        (uint256 moduleId, address controller, address engine, address verifierBundle) = factory.deployTournamentModule(
            uint8(GameDeploymentFactory.MatchFamily.PokerSingleDraw2To7),
            abi.encode(
                GameDeploymentFactory.PokerDeployment({
                    coordinator: adminAddress(),
                    smallBlind: 10,
                    bigBlind: 20,
                    blindEscalationInterval: 180,
                    actionWindow: 60,
                    configHash: keccak256("single-draw-2-7-tournament"),
                    developerRewardBps: 1_000
                })
            )
        );

        logAddress("TournamentController", controller);
        logAddress("TournamentPokerEngine", engine);
        logAddress("TournamentPokerVerifierBundle", verifierBundle);
        logUint("TournamentPokerModuleId", moduleId);

        vm.stopBroadcast();
    }
}
