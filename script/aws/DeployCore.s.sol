// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {DeveloperExpressionRegistry} from "../../src/DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "../../src/DeveloperRewards.sol";
import {GameCatalog} from "../../src/GameCatalog.sol";
import {GameDeploymentFactory} from "../../src/GameDeploymentFactory.sol";
import {ProtocolSettlement} from "../../src/ProtocolSettlement.sol";
import {ScuroGovernor} from "../../src/ScuroGovernor.sol";
import {ScuroStakingToken} from "../../src/ScuroStakingToken.sol";
import {ScuroToken} from "../../src/ScuroToken.sol";
import {BlackjackModuleDeployer} from "../../src/factory/BlackjackModuleDeployer.sol";
import {CheminDeFerModuleDeployer} from "../../src/factory/CheminDeFerModuleDeployer.sol";
import {PokerModuleDeployer} from "../../src/factory/PokerModuleDeployer.sol";
import {SoloModuleDeployer} from "../../src/factory/SoloModuleDeployer.sol";
import {VRFCoordinatorMock} from "../../src/mocks/VRFCoordinatorMock.sol";
import {BetaDeployCommon} from "./BetaDeployCommon.s.sol";

contract DeployCore is BetaDeployCommon {
    function run() external {
        uint256 deployerPrivateKey = adminPrivateKey();
        address admin = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        logStage("DeployCore");
        logStageAction("Core:ScuroToken");
        ScuroToken token = new ScuroToken(admin);
        logStageAction("Core:ScuroStakingToken");
        ScuroStakingToken stakingToken = new ScuroStakingToken(address(token));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        logStageAction("Core:TimelockController");
        TimelockController timelock = new TimelockController(1, proposers, executors, admin);
        logStageAction("Core:ScuroGovernor");
        ScuroGovernor governor = new ScuroGovernor(stakingToken, timelock, 1, 45818, 1 ether);
        logStageAction("Core:GameCatalog");
        GameCatalog catalog = new GameCatalog(admin);
        logStageAction("Core:DeveloperExpressionRegistry");
        DeveloperExpressionRegistry expressionRegistry = new DeveloperExpressionRegistry(admin);
        logStageAction("Core:DeveloperRewards");
        DeveloperRewards developerRewards = new DeveloperRewards(admin, address(token), 7 days);
        logStageAction("Core:ProtocolSettlement");
        ProtocolSettlement settlement =
            new ProtocolSettlement(address(token), address(catalog), address(expressionRegistry), address(developerRewards));
        logStageAction("Core:SoloModuleDeployer");
        SoloModuleDeployer soloModuleDeployer = new SoloModuleDeployer();
        logStageAction("Core:BlackjackModuleDeployer");
        BlackjackModuleDeployer blackjackModuleDeployer = new BlackjackModuleDeployer();
        logStageAction("Core:PokerModuleDeployer");
        PokerModuleDeployer pokerModuleDeployer = new PokerModuleDeployer();
        logStageAction("Core:CheminDeFerModuleDeployer");
        CheminDeFerModuleDeployer cheminDeFerModuleDeployer = new CheminDeFerModuleDeployer();
        logStageAction("Core:GameDeploymentFactory");
        GameDeploymentFactory factory = new GameDeploymentFactory(
            admin,
            address(catalog),
            address(settlement),
            address(soloModuleDeployer),
            address(blackjackModuleDeployer),
            address(pokerModuleDeployer),
            address(cheminDeFerModuleDeployer)
        );
        logStageAction("Core:VRFCoordinatorMock");
        VRFCoordinatorMock vrfCoordinator = new VRFCoordinatorMock();

        logStageAction("Core:GrantMinterSettlement");
        token.grantRole(token.MINTER_ROLE(), address(settlement));
        logStageAction("Core:GrantMinterDeveloperRewards");
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        logStageAction("Core:GrantSettlementRole");
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));
        logStageAction("Core:GrantEpochManagerRole");
        developerRewards.grantRole(developerRewards.EPOCH_MANAGER_ROLE(), address(timelock));
        logStageAction("Core:GrantProposerRole");
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        logStageAction("Core:GrantExecutorRole");
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        logStageAction("Core:GrantCatalogRegistrarToFactory");
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(factory));

        logAddress("ScuroToken", address(token));
        logAddress("ScuroStakingToken", address(stakingToken));
        logAddress("TimelockController", address(timelock));
        logAddress("ScuroGovernor", address(governor));
        logAddress("GameCatalog", address(catalog));
        logAddress("GameDeploymentFactory", address(factory));
        logAddress("DeveloperExpressionRegistry", address(expressionRegistry));
        logAddress("DeveloperRewards", address(developerRewards));
        logAddress("ProtocolSettlement", address(settlement));
        logAddress("VRFCoordinatorMock", address(vrfCoordinator));

        vm.stopBroadcast();
    }
}
