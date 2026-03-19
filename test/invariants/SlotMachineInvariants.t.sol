// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";
import { DeveloperExpressionRegistry } from "../../src/DeveloperExpressionRegistry.sol";
import { DeveloperRewards } from "../../src/DeveloperRewards.sol";
import { GameCatalog } from "../../src/GameCatalog.sol";
import { ProtocolSettlement } from "../../src/ProtocolSettlement.sol";
import { ScuroToken } from "../../src/ScuroToken.sol";
import { SlotMachineEngine } from "../../src/engines/SlotMachineEngine.sol";
import { ManualVRFCoordinatorMock } from "../e2e/helpers/ManualVRFCoordinatorMock.sol";
import { SlotMachineControllerHarness } from "../helpers/SlotMachineControllerHarness.sol";
import { SlotMachinePresetFactory } from "../helpers/SlotMachinePresetFactory.sol";
import { LifecycleHandler } from "./handlers/LifecycleHandler.sol";
import { SlotPresetHandler } from "./handlers/SlotPresetHandler.sol";
import { SlotSpinHandler } from "./handlers/SlotSpinHandler.sol";

contract SlotMachineInvariantTest is StdInvariant, Test {
    uint16 internal constant DEVELOPER_BPS = 500;

    ScuroToken internal token;
    GameCatalog internal catalog;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    ManualVRFCoordinatorMock internal manualVrfCoordinator;
    SlotMachineEngine internal engine;
    SlotMachineControllerHarness internal controller;

    SlotSpinHandler internal spinHandler;
    SlotPresetHandler internal presetHandler;
    LifecycleHandler internal lifecycleHandler;

    address internal developer = address(0xBEEF);
    address internal presetDeveloper = address(0xCAFE);
    address internal player = address(0xA11CE);
    address internal presetPlayer = address(0xB0B);

    uint256 internal moduleId;
    uint256 internal expressionTokenId;
    uint256 internal mismatchedExpressionTokenId;
    uint256 internal presetExpressionTokenId;

    function setUp() public {
        token = new ScuroToken(address(this));
        catalog = new GameCatalog(address(this));
        expressionRegistry = new DeveloperExpressionRegistry(address(this));
        developerRewards = new DeveloperRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(
            address(token), address(catalog), address(expressionRegistry), address(developerRewards)
        );
        manualVrfCoordinator = new ManualVRFCoordinatorMock();
        engine = new SlotMachineEngine(address(this), address(catalog), address(manualVrfCoordinator));
        controller = new SlotMachineControllerHarness(address(settlement), address(catalog), address(engine));

        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));

        moduleId = catalog.registerModule(
            GameCatalog.Module({
                mode: GameCatalog.GameMode.Solo,
                controller: address(controller),
                engine: address(engine),
                engineType: engine.engineType(),
                verifier: address(0),
                configHash: keccak256("slot-invariant"),
                developerRewardBps: DEVELOPER_BPS,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        bytes32 engineType = engine.engineType();
        vm.prank(developer);
        expressionTokenId =
            expressionRegistry.mintExpression(engineType, keccak256("slot-invariant"), "ipfs://slot-main");
        vm.prank(developer);
        mismatchedExpressionTokenId = expressionRegistry.mintExpression(
            keccak256("WRONG_ENGINE"), keccak256("slot-mismatch"), "ipfs://slot-mismatch"
        );
        vm.prank(presetDeveloper);
        presetExpressionTokenId =
            expressionRegistry.mintExpression(engineType, keccak256("slot-preset"), "ipfs://slot-preset");

        token.mint(player, 250_000 ether);
        token.mint(presetPlayer, 250_000 ether);
        vm.prank(player);
        token.approve(address(settlement), type(uint256).max);
        vm.prank(presetPlayer);
        token.approve(address(settlement), type(uint256).max);

        engine.registerPreset(SlotMachinePresetFactory.basePreset(1));
        engine.registerPreset(SlotMachinePresetFactory.freeSpinPreset(2));
        engine.registerPreset(SlotMachinePresetFactory.pickPreset(3));
        engine.registerPreset(SlotMachinePresetFactory.holdPreset(4));

        spinHandler = new SlotSpinHandler(
            token,
            developerRewards,
            catalog,
            engine,
            controller,
            manualVrfCoordinator,
            player,
            developer,
            expressionTokenId,
            mismatchedExpressionTokenId
        );
        presetHandler =
            new SlotPresetHandler(engine, controller, manualVrfCoordinator, presetPlayer, presetExpressionTokenId);
        lifecycleHandler = new LifecycleHandler(
            catalog, engine, controller, manualVrfCoordinator, spinHandler, player, moduleId, expressionTokenId
        );

        engine.grantRole(engine.PRESET_MANAGER_ROLE(), address(presetHandler));
        catalog.grantRole(catalog.DEFAULT_ADMIN_ROLE(), address(lifecycleHandler));

        targetContract(address(spinHandler));
        targetContract(address(presetHandler));
        targetContract(address(lifecycleHandler));
    }

    function invariant_resolvedPayoutsStayWithinPresetCaps() public view {
        uint256 spinCount = spinHandler.trackedSpinCount();
        for (uint256 i = 0; i < spinCount; i++) {
            uint256 spinId = spinHandler.trackedSpinIdAt(i);
            if (spinId == 0) {
                continue;
            }

            SlotMachineEngine.Spin memory spin = engine.getSpin(spinId);
            if (!spin.resolved) {
                continue;
            }

            SlotMachineEngine.SpinResult memory result = engine.getSpinResult(spinId);
            SlotMachineEngine.PresetSummary memory summary = engine.getPresetSummary(spin.presetId);
            assertLe(result.totalPayout, (spin.stake * summary.maxPayoutMultiplierBps) / 10_000);
            assertLe(result.totalEventCount, summary.maxTotalEvents);
        }
    }

    function invariant_presetsRemainImmutableAndInactivePresetLaunchesFail() public view {
        assertFalse(presetHandler.presetMutationDetected());
        assertFalse(presetHandler.inactivePresetLaunchSucceeded());
        assertFalse(presetHandler.determinismMismatch());
    }

    function invariant_settlementRulesHold() public view {
        assertFalse(spinHandler.pendingSettleSucceeded());
        assertFalse(spinHandler.doubleSettleSucceeded());
        assertFalse(spinHandler.disabledSettleSucceeded());
        assertFalse(spinHandler.mismatchFinalizeSucceeded());
        assertTrue(spinHandler.playerBalanceMatchesAccounting());
        assertTrue(spinHandler.developerAccrualMatchesAccounting());
    }

    function invariant_lifecycleRulesHold() public view {
        assertFalse(lifecycleHandler.inactiveLaunchSucceeded());
        assertFalse(lifecycleHandler.disabledProgressSucceeded());
        assertFalse(lifecycleHandler.retiredSettlementFailed());
    }
}
