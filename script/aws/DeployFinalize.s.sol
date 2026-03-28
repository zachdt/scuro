// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {DeveloperExpressionRegistry} from "../../src/DeveloperExpressionRegistry.sol";
import {GameCatalog} from "../../src/GameCatalog.sol";
import {GameDeploymentFactory} from "../../src/GameDeploymentFactory.sol";
import {ScuroToken} from "../../src/ScuroToken.sol";
import {NumberPickerEngine} from "../../src/engines/NumberPickerEngine.sol";
import {SingleDeckBlackjackEngine} from "../../src/engines/SingleDeckBlackjackEngine.sol";
import {SingleDraw2To7Engine} from "../../src/engines/SingleDraw2To7Engine.sol";
import {BetaDeployCommon} from "./BetaDeployCommon.s.sol";

contract DeployFinalize is BetaDeployCommon {
    function run() external {
        uint256 deployerPrivateKey = adminPrivateKey();
        address admin = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        logStage("DeployFinalize");
        ScuroToken token = ScuroToken(envAddress("ScuroToken"));
        TimelockController timelock = TimelockController(payable(envAddress("TimelockController")));
        GameCatalog catalog = GameCatalog(envAddress("GameCatalog"));
        GameDeploymentFactory factory = GameDeploymentFactory(envAddress("GameDeploymentFactory"));
        DeveloperExpressionRegistry expressionRegistry = DeveloperExpressionRegistry(envAddress("DeveloperExpressionRegistry"));
        NumberPickerEngine numberPickerEngine = NumberPickerEngine(envAddress("NumberPickerEngine"));
        SingleDraw2To7Engine tournamentPokerEngine = SingleDraw2To7Engine(envAddress("TournamentPokerEngine"));
        SingleDeckBlackjackEngine blackjackEngine = SingleDeckBlackjackEngine(envAddress("SingleDeckBlackjackEngine"));

        logStageAction("Finalize:NumberPickerExpression");
        uint256 numberPickerExpressionTokenId = expressionRegistry.mintExpression(
            numberPickerEngine.engineType(), keccak256("number-picker-auto"), "ipfs://scuro/number-picker-auto"
        );
        logStageAction("Finalize:BlackjackExpression");
        uint256 blackjackExpressionTokenId = expressionRegistry.mintExpression(
            blackjackEngine.engineType(), keccak256("single-deck-blackjack-zk"), "ipfs://scuro/single-deck-blackjack-zk"
        );
        logStageAction("Finalize:PokerExpression");
        uint256 pokerExpressionTokenId = expressionRegistry.mintExpression(
            tournamentPokerEngine.engineType(), keccak256("single-draw-2-7"), "ipfs://scuro/single-draw-2-7"
        );

        logStageAction("Finalize:TransferNumberPickerExpression");
        expressionRegistry.transferFrom(admin, SOLO_DEVELOPER, numberPickerExpressionTokenId);
        logStageAction("Finalize:TransferBlackjackExpression");
        expressionRegistry.transferFrom(admin, SOLO_DEVELOPER, blackjackExpressionTokenId);
        logStageAction("Finalize:TransferPokerExpression");
        expressionRegistry.transferFrom(admin, POKER_DEVELOPER, pokerExpressionTokenId);

        logStageAction("Finalize:MintPlayer1");
        token.mint(PLAYER1, PLAYER_FUNDS);
        logStageAction("Finalize:MintPlayer2");
        token.mint(PLAYER2, PLAYER_FUNDS);
        logStageAction("Finalize:MintAdmin");
        token.mint(admin, PLAYER_FUNDS);
        logStageAction("Finalize:MintSoloDeveloper");
        token.mint(SOLO_DEVELOPER, DEVELOPER_FUNDS);
        logStageAction("Finalize:MintPokerDeveloper");
        token.mint(POKER_DEVELOPER, DEVELOPER_FUNDS);

        logStageAction("Finalize:GrantCatalogAdminToTimelock");
        catalog.grantRole(catalog.DEFAULT_ADMIN_ROLE(), address(timelock));
        logStageAction("Finalize:GrantCatalogRegistrarToTimelock");
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(timelock));
        logStageAction("Finalize:RenounceCatalogAdmin");
        catalog.renounceRole(catalog.DEFAULT_ADMIN_ROLE(), admin);
        logStageAction("Finalize:RenounceCatalogRegistrar");
        catalog.renounceRole(catalog.REGISTRAR_ROLE(), admin);
        logStageAction("Finalize:GrantFactoryAdminToTimelock");
        factory.grantRole(factory.DEFAULT_ADMIN_ROLE(), address(timelock));
        logStageAction("Finalize:GrantFactoryDeployerToTimelock");
        factory.grantRole(factory.DEPLOYER_ROLE(), address(timelock));
        logStageAction("Finalize:RenounceFactoryAdmin");
        factory.renounceRole(factory.DEFAULT_ADMIN_ROLE(), admin);
        logStageAction("Finalize:RenounceFactoryDeployer");
        factory.renounceRole(factory.DEPLOYER_ROLE(), admin);

        logAddress("GameDeploymentFactory", address(factory));
        logAddress("Admin", admin);
        logAddress("Player1", PLAYER1);
        logAddress("Player2", PLAYER2);
        logAddress("SoloDeveloper", SOLO_DEVELOPER);
        logAddress("PokerDeveloper", POKER_DEVELOPER);
        logUint("NumberPickerExpressionTokenId", numberPickerExpressionTokenId);
        logUint("PokerExpressionTokenId", pokerExpressionTokenId);
        logUint("BlackjackExpressionTokenId", blackjackExpressionTokenId);

        vm.stopBroadcast();
    }
}
