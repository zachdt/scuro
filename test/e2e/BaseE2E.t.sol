// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { TimelockController } from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { DeveloperExpressionRegistry } from "../../src/DeveloperExpressionRegistry.sol";
import { DeveloperRewards } from "../../src/DeveloperRewards.sol";
import { GameCatalog } from "../../src/GameCatalog.sol";
import { ProtocolSettlement } from "../../src/ProtocolSettlement.sol";
import { ScuroGovernor } from "../../src/ScuroGovernor.sol";
import { ScuroStakingToken } from "../../src/ScuroStakingToken.sol";
import { ScuroToken } from "../../src/ScuroToken.sol";
import { NumberPickerAdapter } from "../../src/controllers/NumberPickerAdapter.sol";
import { SlotMachineController } from "../../src/controllers/SlotMachineController.sol";
import { NumberPickerEngine } from "../../src/engines/NumberPickerEngine.sol";
import { SlotMachineEngine } from "../../src/engines/SlotMachineEngine.sol";
import { VRFCoordinatorMock } from "../../src/mocks/VRFCoordinatorMock.sol";
import { ManualVRFCoordinatorMock } from "./helpers/ManualVRFCoordinatorMock.sol";
import { NumberPickerAdapterHarness } from "./helpers/NumberPickerAdapterHarness.sol";
import { SlotMachineControllerHarness } from "../helpers/SlotMachineControllerHarness.sol";
import { SlotMachinePresetFactory } from "../helpers/SlotMachinePresetFactory.sol";

abstract contract BaseE2ETest is Test {
    struct Actor {
        address addr;
        uint256 key;
    }

    uint256 internal constant PLAYER_FUNDS = 10_000 ether;
    uint256 internal constant STAKE_AMOUNT = 100 ether;
    uint16 internal constant SOLO_DEVELOPER_BPS = 500;

    Actor internal player1;
    Actor internal player2;
    Actor internal soloDeveloper;
    Actor internal outsider;

    ScuroToken internal token;
    ScuroStakingToken internal stakingToken;
    TimelockController internal timelock;
    ScuroGovernor internal governor;
    GameCatalog internal catalog;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    VRFCoordinatorMock internal autoVrfCoordinator;
    ManualVRFCoordinatorMock internal manualVrfCoordinator;
    NumberPickerEngine internal numberPickerEngine;
    NumberPickerEngine internal delayedNumberPickerEngine;
    NumberPickerAdapter internal numberPickerAdapter;
    NumberPickerAdapterHarness internal delayedNumberPickerAdapter;
    SlotMachineEngine internal slotMachineEngine;
    SlotMachineEngine internal delayedSlotMachineEngine;
    SlotMachineController internal slotMachineController;
    SlotMachineControllerHarness internal delayedSlotMachineController;

    uint256 internal numberPickerModuleId;
    uint256 internal delayedNumberPickerModuleId;
    uint256 internal slotMachineModuleId;
    uint256 internal delayedSlotMachineModuleId;

    uint256 internal numberPickerExpressionTokenId;
    uint256 internal delayedNumberPickerExpressionTokenId;
    uint256 internal slotMachineExpressionTokenId;
    uint256 internal delayedSlotMachineExpressionTokenId;

    function setUp() public virtual {
        player1 = _makeActor("player-1");
        player2 = _makeActor("player-2");
        soloDeveloper = _makeActor("solo-developer");
        outsider = _makeActor("outsider");

        _deployCore();
        _wireRoles();
        _deployModules();
        _mintExpressions();
        _seedActors();
    }

    function _makeActor(string memory label) internal returns (Actor memory actor) {
        (actor.addr, actor.key) = makeAddrAndKey(label);
    }

    function _deployCore() internal {
        token = new ScuroToken(address(this));
        stakingToken = new ScuroStakingToken(address(token));

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(1, proposers, executors, address(this));
        governor = new ScuroGovernor(stakingToken, timelock, 1, 5, 1 ether);

        catalog = new GameCatalog(address(this));
        expressionRegistry = new DeveloperExpressionRegistry(address(this));
        developerRewards = new DeveloperRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(
            address(token), address(catalog), address(expressionRegistry), address(developerRewards)
        );

        autoVrfCoordinator = new VRFCoordinatorMock();
        manualVrfCoordinator = new ManualVRFCoordinatorMock();
    }

    function _wireRoles() internal {
        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));
        developerRewards.grantRole(developerRewards.EPOCH_MANAGER_ROLE(), address(timelock));
        catalog.grantRole(catalog.DEFAULT_ADMIN_ROLE(), address(timelock));
        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(timelock));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
    }

    function _deployModules() internal {
        numberPickerEngine = new NumberPickerEngine(address(catalog), address(autoVrfCoordinator));
        numberPickerAdapter =
            new NumberPickerAdapter(address(settlement), address(catalog), address(numberPickerEngine));
        numberPickerModuleId = catalog.registerModule(
            GameCatalog.Module({
                controller: address(numberPickerAdapter),
                engine: address(numberPickerEngine),
                engineType: numberPickerEngine.engineType(),
                configHash: keccak256("number-picker-auto"),
                developerRewardBps: SOLO_DEVELOPER_BPS,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        delayedNumberPickerEngine = new NumberPickerEngine(address(catalog), address(manualVrfCoordinator));
        delayedNumberPickerAdapter =
            new NumberPickerAdapterHarness(address(settlement), address(catalog), address(delayedNumberPickerEngine));
        delayedNumberPickerModuleId = catalog.registerModule(
            GameCatalog.Module({
                controller: address(delayedNumberPickerAdapter),
                engine: address(delayedNumberPickerEngine),
                engineType: delayedNumberPickerEngine.engineType(),
                configHash: keccak256("number-picker-manual"),
                developerRewardBps: SOLO_DEVELOPER_BPS,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        slotMachineEngine = new SlotMachineEngine(address(this), address(catalog), address(autoVrfCoordinator));
        slotMachineController =
            new SlotMachineController(address(settlement), address(catalog), address(slotMachineEngine));
        slotMachineModuleId = catalog.registerModule(
            GameCatalog.Module({
                controller: address(slotMachineController),
                engine: address(slotMachineEngine),
                engineType: slotMachineEngine.engineType(),
                configHash: keccak256("slot-machine-auto"),
                developerRewardBps: SOLO_DEVELOPER_BPS,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );
        _registerSlotPresets(slotMachineEngine);

        delayedSlotMachineEngine = new SlotMachineEngine(address(this), address(catalog), address(manualVrfCoordinator));
        delayedSlotMachineController =
            new SlotMachineControllerHarness(address(settlement), address(catalog), address(delayedSlotMachineEngine));
        delayedSlotMachineModuleId = catalog.registerModule(
            GameCatalog.Module({
                controller: address(delayedSlotMachineController),
                engine: address(delayedSlotMachineEngine),
                engineType: delayedSlotMachineEngine.engineType(),
                configHash: keccak256("slot-machine-manual"),
                developerRewardBps: SOLO_DEVELOPER_BPS,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );
        _registerSlotPresets(delayedSlotMachineEngine);
    }

    function _mintExpressions() internal {
        bytes32 numberPickerEngineType = numberPickerEngine.engineType();
        bytes32 delayedNumberPickerEngineType = delayedNumberPickerEngine.engineType();
        bytes32 slotMachineEngineType = slotMachineEngine.engineType();
        bytes32 delayedSlotMachineEngineType = delayedSlotMachineEngine.engineType();

        vm.startPrank(soloDeveloper.addr);
        numberPickerExpressionTokenId = expressionRegistry.mintExpression(
            numberPickerEngineType, keccak256("number-picker-auto"), "ipfs://scuro/number-picker-auto"
        );

        delayedNumberPickerExpressionTokenId = expressionRegistry.mintExpression(
            delayedNumberPickerEngineType, keccak256("number-picker-manual"), "ipfs://scuro/number-picker-manual"
        );

        slotMachineExpressionTokenId = expressionRegistry.mintExpression(
            slotMachineEngineType, keccak256("slot-machine"), "ipfs://scuro/slot-machine"
        );

        delayedSlotMachineExpressionTokenId = expressionRegistry.mintExpression(
            delayedSlotMachineEngineType, keccak256("slot-machine-manual"), "ipfs://scuro/slot-machine-manual"
        );
        vm.stopPrank();
    }

    function _seedActors() internal {
        token.mint(player1.addr, PLAYER_FUNDS);
        token.mint(player2.addr, PLAYER_FUNDS);
        token.mint(soloDeveloper.addr, PLAYER_FUNDS / 10);
    }

    function _approveSettlement(Actor memory actor, uint256 amount) internal {
        vm.prank(actor.addr);
        token.approve(address(settlement), amount);
    }

    function _approveStaking(Actor memory actor, uint256 amount) internal {
        vm.prank(actor.addr);
        token.approve(address(stakingToken), amount);
    }

    function _stakeAndDelegate(Actor memory actor, uint256 amount) internal {
        _approveStaking(actor, amount);
        vm.startPrank(actor.addr);
        stakingToken.stake(amount);
        stakingToken.delegate(actor.addr);
        vm.stopPrank();
    }

    function _registerSlotPresets(SlotMachineEngine engine) internal {
        engine.registerPreset(SlotMachinePresetFactory.basePreset(1));
        engine.registerPreset(SlotMachinePresetFactory.freeSpinPreset(2));
        engine.registerPreset(SlotMachinePresetFactory.pickPreset(3));
        engine.registerPreset(SlotMachinePresetFactory.holdPreset(4));
    }

    function _closeEpoch() internal returns (uint256 closedEpoch) {
        vm.warp(block.timestamp + developerRewards.epochDuration() + 1);
        closedEpoch = developerRewards.closeCurrentEpoch();
    }

    function _executeGovernanceProposal(address target, bytes memory data, string memory description) internal {
        _stakeAndDelegate(player1, STAKE_AMOUNT);
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        targets[0] = target;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = data;

        vm.prank(player1.addr);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(player1.addr);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        vm.warp(block.timestamp + 2);
        governor.execute(targets, values, calldatas, descriptionHash);
    }

    function _assertPlayerBalances(uint256 player1Balance, uint256 player2Balance) internal view {
        assertEq(token.balanceOf(player1.addr), player1Balance, "player1 balance");
        assertEq(token.balanceOf(player2.addr), player2Balance, "player2 balance");
    }

    function _assertDeveloperAccrual(address developer, uint256 epoch, uint256 amount) internal view {
        assertEq(developerRewards.epochAccrual(epoch, developer), amount, "developer accrual");
    }
}
