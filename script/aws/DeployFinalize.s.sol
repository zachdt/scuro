// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { DeveloperExpressionRegistry } from "../../src/DeveloperExpressionRegistry.sol";
import { GameCatalog } from "../../src/GameCatalog.sol";
import { ScuroToken } from "../../src/ScuroToken.sol";
import { NumberPickerEngine } from "../../src/engines/NumberPickerEngine.sol";
import { SlotMachineEngine } from "../../src/engines/SlotMachineEngine.sol";
import { BetaDeployCommon } from "./BetaDeployCommon.s.sol";

contract DeployFinalize is BetaDeployCommon {
    function run() external {
        uint256 deployerPrivateKey = adminPrivateKey();
        address admin = vm.addr(deployerPrivateKey);
        address player1 = player1Address();
        address player2 = player2Address();
        vm.startBroadcast(deployerPrivateKey);

        logStage("DeployFinalize");
        ScuroToken token = ScuroToken(envAddress("ScuroToken"));
        TimelockController timelock = TimelockController(payable(envAddress("TimelockController")));
        GameCatalog catalog = GameCatalog(envAddress("GameCatalog"));
        DeveloperExpressionRegistry expressionRegistry =
            DeveloperExpressionRegistry(envAddress("DeveloperExpressionRegistry"));
        NumberPickerEngine numberPickerEngine = NumberPickerEngine(envAddress("NumberPickerEngine"));
        SlotMachineEngine slotMachineEngine = SlotMachineEngine(envAddress("SlotMachineEngine"));

        logStageAction("Finalize:NumberPickerExpression");
        uint256 numberPickerExpressionTokenId = expressionRegistry.mintExpression(
            numberPickerEngine.engineType(), keccak256("number-picker-auto"), "ipfs://scuro/number-picker-auto"
        );
        logStageAction("Finalize:SlotMachineExpression");
        uint256 slotMachineExpressionTokenId = expressionRegistry.mintExpression(
            slotMachineEngine.engineType(), keccak256("slot-machine"), "ipfs://scuro/slot-machine"
        );

        logStageAction("Finalize:TransferNumberPickerExpression");
        expressionRegistry.transferFrom(admin, SOLO_DEVELOPER, numberPickerExpressionTokenId);
        logStageAction("Finalize:TransferSlotMachineExpression");
        expressionRegistry.transferFrom(admin, SOLO_DEVELOPER, slotMachineExpressionTokenId);

        logStageAction("Finalize:MintPlayer1");
        token.mint(player1, PLAYER_FUNDS);
        logStageAction("Finalize:MintPlayer2");
        token.mint(player2, PLAYER_FUNDS);
        logStageAction("Finalize:MintAdmin");
        token.mint(admin, PLAYER_FUNDS);
        logStageAction("Finalize:MintSoloDeveloper");
        token.mint(SOLO_DEVELOPER, DEVELOPER_FUNDS);

        logStageAction("Finalize:GrantCatalogAdminToTimelock");
        catalog.grantRole(catalog.DEFAULT_ADMIN_ROLE(), address(timelock));
        logStageAction("Finalize:GrantCatalogRegistrarToTimelock");
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(timelock));
        logStageAction("Finalize:RenounceCatalogAdmin");
        catalog.renounceRole(catalog.DEFAULT_ADMIN_ROLE(), admin);
        logStageAction("Finalize:RenounceCatalogRegistrar");
        catalog.renounceRole(catalog.REGISTRAR_ROLE(), admin);

        logAddress("Admin", admin);
        logAddress("Player1", player1);
        logAddress("Player2", player2);
        logAddress("SoloDeveloper", SOLO_DEVELOPER);
        logUint("NumberPickerExpressionTokenId", numberPickerExpressionTokenId);
        logUint("SlotMachineExpressionTokenId", slotMachineExpressionTokenId);

        vm.stopBroadcast();
    }
}
