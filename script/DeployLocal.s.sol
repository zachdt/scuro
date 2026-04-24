// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { DeveloperExpressionRegistry } from "../src/DeveloperExpressionRegistry.sol";
import { DeveloperRewards } from "../src/DeveloperRewards.sol";
import { GameCatalog } from "../src/GameCatalog.sol";
import { ProtocolSettlement } from "../src/ProtocolSettlement.sol";
import { ScuroGovernor } from "../src/ScuroGovernor.sol";
import { ScuroStakingToken } from "../src/ScuroStakingToken.sol";
import { ScuroToken } from "../src/ScuroToken.sol";
import { NumberPickerAdapter } from "../src/controllers/NumberPickerAdapter.sol";
import { SlotMachineController } from "../src/controllers/SlotMachineController.sol";
import { NumberPickerEngine } from "../src/engines/NumberPickerEngine.sol";
import { SlotMachineEngine } from "../src/engines/SlotMachineEngine.sol";
import { SlotMachinePresets } from "../src/libraries/SlotMachinePresets.sol";
import { VRFCoordinatorMock } from "../src/mocks/VRFCoordinatorMock.sol";

contract DeployLocal is Script {
    uint256 internal constant DEFAULT_PLAYER1_PRIVATE_KEY =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 internal constant DEFAULT_PLAYER2_PRIVATE_KEY =
        0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    address internal constant SOLO_DEVELOPER = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    uint256 internal constant PLAYER_FUNDS = 10_000 ether;
    uint256 internal constant DEVELOPER_FUNDS = 1_000 ether;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerPrivateKey);
        address player1 = vm.addr(vm.envOr("PLAYER1_PRIVATE_KEY", DEFAULT_PLAYER1_PRIVATE_KEY));
        address player2 = vm.addr(vm.envOr("PLAYER2_PRIVATE_KEY", DEFAULT_PLAYER2_PRIVATE_KEY));

        vm.startBroadcast(deployerPrivateKey);

        console.log("StageAction", "Core:ScuroToken");
        ScuroToken token = new ScuroToken(admin);
        ScuroStakingToken stakingToken = new ScuroStakingToken(address(token));
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        TimelockController timelock = new TimelockController(1, proposers, executors, admin);
        ScuroGovernor governor = new ScuroGovernor(stakingToken, timelock, 1, 45818, 1 ether);
        GameCatalog catalog = new GameCatalog(admin);
        DeveloperExpressionRegistry expressionRegistry = new DeveloperExpressionRegistry(admin);
        DeveloperRewards developerRewards = new DeveloperRewards(admin, address(token), 7 days);
        ProtocolSettlement settlement = new ProtocolSettlement(
            address(token), address(catalog), address(expressionRegistry), address(developerRewards)
        );
        VRFCoordinatorMock vrfCoordinator = new VRFCoordinatorMock();

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));
        developerRewards.grantRole(developerRewards.EPOCH_MANAGER_ROLE(), address(timelock));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        NumberPickerEngine numberPickerEngine = new NumberPickerEngine(address(catalog), address(vrfCoordinator));
        NumberPickerAdapter numberPickerAdapter =
            new NumberPickerAdapter(address(settlement), address(catalog), address(numberPickerEngine));
        uint256 numberPickerModuleId = catalog.registerModule(
            GameCatalog.Module({
                controller: address(numberPickerAdapter),
                engine: address(numberPickerEngine),
                engineType: numberPickerEngine.engineType(),
                configHash: keccak256("number-picker-auto"),
                developerRewardBps: 500,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        SlotMachineEngine slotMachineEngine = new SlotMachineEngine(admin, address(catalog), address(vrfCoordinator));
        SlotMachineController slotMachineController =
            new SlotMachineController(address(settlement), address(catalog), address(slotMachineEngine));
        uint256 slotMachineModuleId = catalog.registerModule(
            GameCatalog.Module({
                controller: address(slotMachineController),
                engine: address(slotMachineEngine),
                engineType: slotMachineEngine.engineType(),
                configHash: keccak256("slot-machine-auto"),
                developerRewardBps: 500,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );
        uint256 basePresetId = slotMachineEngine.registerPreset(SlotMachinePresets.basePreset(1));
        uint256 freePresetId = slotMachineEngine.registerPreset(SlotMachinePresets.freeSpinPreset(2));
        uint256 pickPresetId = slotMachineEngine.registerPreset(SlotMachinePresets.pickPreset(3));
        uint256 holdPresetId = slotMachineEngine.registerPreset(SlotMachinePresets.holdPreset(4));

        uint256 numberPickerExpressionTokenId = expressionRegistry.mintExpression(
            numberPickerEngine.engineType(), keccak256("number-picker-auto"), "ipfs://scuro/number-picker-auto"
        );
        uint256 slotMachineExpressionTokenId = expressionRegistry.mintExpression(
            slotMachineEngine.engineType(), keccak256("slot-machine"), "ipfs://scuro/slot-machine"
        );
        expressionRegistry.transferFrom(admin, SOLO_DEVELOPER, numberPickerExpressionTokenId);
        expressionRegistry.transferFrom(admin, SOLO_DEVELOPER, slotMachineExpressionTokenId);

        token.mint(player1, PLAYER_FUNDS);
        token.mint(player2, PLAYER_FUNDS);
        token.mint(admin, PLAYER_FUNDS);
        token.mint(SOLO_DEVELOPER, DEVELOPER_FUNDS);

        catalog.grantRole(catalog.DEFAULT_ADMIN_ROLE(), address(timelock));
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(timelock));
        catalog.renounceRole(catalog.DEFAULT_ADMIN_ROLE(), admin);
        catalog.renounceRole(catalog.REGISTRAR_ROLE(), admin);

        console.log("ScuroToken", address(token));
        console.log("ScuroStakingToken", address(stakingToken));
        console.log("TimelockController", address(timelock));
        console.log("ScuroGovernor", address(governor));
        console.log("GameCatalog", address(catalog));
        console.log("DeveloperExpressionRegistry", address(expressionRegistry));
        console.log("DeveloperRewards", address(developerRewards));
        console.log("ProtocolSettlement", address(settlement));
        console.log("VRFCoordinatorMock", address(vrfCoordinator));
        console.log("NumberPickerEngine", address(numberPickerEngine));
        console.log("NumberPickerAdapter", address(numberPickerAdapter));
        console.log("SlotMachineEngine", address(slotMachineEngine));
        console.log("SlotMachineController", address(slotMachineController));
        console.log("NumberPickerModuleId", numberPickerModuleId);
        console.log("SlotMachineModuleId", slotMachineModuleId);
        console.log("SlotBasePresetId", basePresetId);
        console.log("SlotFreePresetId", freePresetId);
        console.log("SlotPickPresetId", pickPresetId);
        console.log("SlotHoldPresetId", holdPresetId);
        console.log("Admin", admin);
        console.log("Player1", player1);
        console.log("Player2", player2);
        console.log("SoloDeveloper", SOLO_DEVELOPER);
        console.log("NumberPickerExpressionTokenId", numberPickerExpressionTokenId);
        console.log("SlotMachineExpressionTokenId", slotMachineExpressionTokenId);

        vm.stopBroadcast();
    }
}
