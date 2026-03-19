// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { DeveloperExpressionRegistry } from "../src/DeveloperExpressionRegistry.sol";
import { DeveloperRewards } from "../src/DeveloperRewards.sol";
import { GameCatalog } from "../src/GameCatalog.sol";
import { GameDeploymentFactory } from "../src/GameDeploymentFactory.sol";
import { ProtocolSettlement } from "../src/ProtocolSettlement.sol";
import { ScuroToken } from "../src/ScuroToken.sol";
import { SlotMachineController } from "../src/controllers/SlotMachineController.sol";
import { SlotMachineEngine } from "../src/engines/SlotMachineEngine.sol";
import { VRFCoordinatorMock } from "../src/mocks/VRFCoordinatorMock.sol";
import { ManualVRFCoordinatorMock } from "./e2e/helpers/ManualVRFCoordinatorMock.sol";
import { SlotMachineControllerHarness } from "./helpers/SlotMachineControllerHarness.sol";
import { SlotMachinePresetFactory } from "./helpers/SlotMachinePresetFactory.sol";

contract SlotMachineControllerTest is Test {
    ScuroToken internal token;
    GameCatalog internal catalog;
    GameDeploymentFactory internal factory;
    DeveloperExpressionRegistry internal expressionRegistry;
    DeveloperRewards internal developerRewards;
    ProtocolSettlement internal settlement;
    VRFCoordinatorMock internal autoVrfCoordinator;
    ManualVRFCoordinatorMock internal manualVrfCoordinator;

    SlotMachineController internal autoController;
    SlotMachineEngine internal autoEngine;
    SlotMachineControllerHarness internal delayedController;
    SlotMachineEngine internal delayedEngine;
    uint256 internal delayedModuleId;
    uint256 internal expressionTokenId;

    address internal developer = address(0xBEEF);
    address internal player = address(0xA11CE);

    function setUp() public {
        token = new ScuroToken(address(this));
        catalog = new GameCatalog(address(this));
        expressionRegistry = new DeveloperExpressionRegistry(address(this));
        developerRewards = new DeveloperRewards(address(this), address(token), 7 days);
        settlement = new ProtocolSettlement(
            address(token), address(catalog), address(expressionRegistry), address(developerRewards)
        );
        factory = new GameDeploymentFactory(address(this), address(catalog), address(settlement));
        autoVrfCoordinator = new VRFCoordinatorMock();
        manualVrfCoordinator = new ManualVRFCoordinatorMock();

        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(factory));
        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));

        GameDeploymentFactory.SlotDeployment memory params = GameDeploymentFactory.SlotDeployment({
            vrfCoordinator: address(autoVrfCoordinator), configHash: keccak256("slot-auto"), developerRewardBps: 500
        });
        address controllerAddress;
        address engineAddress;
        (, controllerAddress, engineAddress,) =
            factory.deploySoloModule(uint8(GameDeploymentFactory.SoloFamily.SlotMachine), abi.encode(params));
        autoController = SlotMachineController(controllerAddress);
        autoEngine = SlotMachineEngine(engineAddress);

        delayedEngine = new SlotMachineEngine(address(this), address(catalog), address(manualVrfCoordinator));
        delayedController =
            new SlotMachineControllerHarness(address(settlement), address(catalog), address(delayedEngine));
        delayedModuleId = catalog.registerModule(
            GameCatalog.Module({
                mode: GameCatalog.GameMode.Solo,
                controller: address(delayedController),
                engine: address(delayedEngine),
                engineType: delayedEngine.engineType(),
                verifier: address(0),
                configHash: keccak256("slot-manual"),
                developerRewardBps: 500,
                status: GameCatalog.ModuleStatus.LIVE
            })
        );

        bytes32 engineType = autoEngine.engineType();
        vm.prank(developer);
        expressionTokenId = expressionRegistry.mintExpression(engineType, keccak256("slot"), "ipfs://slot");

        token.mint(player, 10_000 ether);
        vm.prank(player);
        token.approve(address(settlement), type(uint256).max);

        _registerPresets(autoEngine);
        _registerPresets(delayedEngine);
    }

    function test_RegisterPresetRejectsMalformedConfigAndPreservesImmutableReadback() public {
        SlotMachineEngine.PresetConfig memory malformed = SlotMachinePresetFactory.basePreset(1);
        malformed.reelWeightOffsets = new uint16[](2);
        malformed.reelWeightOffsets[0] = 1;
        malformed.reelWeightOffsets[1] = 4;

        vm.expectRevert("SlotMachine: bad offsets");
        autoEngine.registerPreset(malformed);

        SlotMachineEngine.PresetConfig memory preset = autoEngine.getPreset(1);
        assertEq(preset.volatilityTier, 1);
        assertEq(preset.configHash, keccak256("base"));
        assertTrue(autoEngine.presetActive(1));
    }

    function test_AutoSpinSettlesImmediatelyAndAccruesDeveloperRewards() public {
        vm.prank(player);
        uint256 spinId = autoController.spin(100 ether, 1, keccak256("base-auto"), expressionTokenId);

        SlotMachineEngine.Spin memory spinData = autoEngine.getSpin(spinId);
        SlotMachineEngine.SpinResult memory result = autoEngine.getSpinResult(spinId);
        assertTrue(spinData.resolved);
        assertEq(result.totalPayout, spinData.finalPayout);
        assertTrue(autoController.spinSettled(spinId));
        assertEq(autoController.spinExpressionTokenId(spinId), expressionTokenId);
        assertEq(token.balanceOf(player), 10_000 ether - 100 ether + result.totalPayout);
        assertEq(developerRewards.epochAccrual(1, developer), 5 ether);
    }

    function test_DelayedSettleSupportsBonusFamiliesAndDuplicateSettlementGuards() public {
        vm.startPrank(player);
        uint256 freeSpinId = delayedController.spinWithoutFinalize(100 ether, 2, keccak256("free"), expressionTokenId);
        uint256 pickId = delayedController.spinWithoutFinalize(100 ether, 3, keccak256("pick"), expressionTokenId);
        uint256 holdId = delayedController.spinWithoutFinalize(100 ether, 4, keccak256("hold"), expressionTokenId);
        vm.stopPrank();

        vm.expectRevert("SlotMachineController: pending");
        delayedController.finalizeForTest(freeSpinId);

        manualVrfCoordinator.fulfillRequestWithWord(freeSpinId, 1);
        manualVrfCoordinator.fulfillRequestWithWord(pickId, 2);
        manualVrfCoordinator.fulfillRequestWithWord(holdId, 3);

        delayedController.finalizeForTest(freeSpinId);
        delayedController.finalizeForTest(pickId);
        delayedController.finalizeForTest(holdId);

        SlotMachineEngine.SpinResult memory freeResult = delayedEngine.getSpinResult(freeSpinId);
        SlotMachineEngine.SpinResult memory pickResult = delayedEngine.getSpinResult(pickId);
        SlotMachineEngine.SpinResult memory holdResult = delayedEngine.getSpinResult(holdId);

        assertTrue(freeResult.triggeredFreeSpins);
        assertGt(freeResult.freeSpinPayout, 0);
        assertGt(freeResult.freeSpinCount, 0);
        assertLe(freeResult.totalEventCount, delayedEngine.getPresetSummary(2).maxTotalEvents);
        assertTrue(pickResult.triggeredPickBonus);
        assertGt(pickResult.pickBonusPayout, 0);
        assertGt(pickResult.pickRevealCount, 0);
        assertTrue(holdResult.triggeredHoldAndSpin);
        assertGt(holdResult.holdAndSpinPayout, 0);
        assertGt(holdResult.holdRespinsUsed, 0);

        vm.expectRevert("SlotMachineController: settled");
        delayedController.finalizeForTest(freeSpinId);
    }

    function testFuzz_DeterministicReplayMatchesForSameSeed(uint64 rawSeed) public {
        uint256 seed = bound(uint256(rawSeed), 1, type(uint64).max);

        vm.startPrank(player);
        uint256 spinIdA = delayedController.spinWithoutFinalize(100 ether, 4, keccak256("fuzz-a"), expressionTokenId);
        uint256 spinIdB = delayedController.spinWithoutFinalize(100 ether, 4, keccak256("fuzz-b"), expressionTokenId);
        vm.stopPrank();

        manualVrfCoordinator.fulfillRequestWithWord(spinIdA, seed);
        manualVrfCoordinator.fulfillRequestWithWord(spinIdB, seed);
        delayedController.finalizeForTest(spinIdA);
        delayedController.finalizeForTest(spinIdB);

        SlotMachineEngine.SpinResult memory resultA = delayedEngine.getSpinResult(spinIdA);
        SlotMachineEngine.SpinResult memory resultB = delayedEngine.getSpinResult(spinIdB);
        assertEq(resultA.totalPayout, resultB.totalPayout);
        assertEq(resultA.jackpotPayout, resultB.jackpotPayout);
        assertEq(resultA.totalEventCount, resultB.totalEventCount);
    }

    function testFuzz_SpinRejectsStakeOutsidePresetBounds(uint96 rawStake) public {
        uint256 stake = bound(uint256(rawStake), 0, 10_000 ether);

        vm.startPrank(player);
        if (stake < 1 ether) {
            vm.expectRevert("SlotMachine: stake too small");
            delayedController.spinWithoutFinalize(stake, 1, keccak256("too-small"), expressionTokenId);
        } else if (stake > 1_000 ether) {
            vm.expectRevert("SlotMachine: stake too large");
            delayedController.spinWithoutFinalize(stake, 1, keccak256("too-large"), expressionTokenId);
        } else {
            uint256 spinId = delayedController.spinWithoutFinalize(stake, 1, keccak256("bounded"), expressionTokenId);
            assertEq(delayedEngine.getSpin(spinId).stake, stake);
        }
        vm.stopPrank();
    }

    function test_DeterministicReplayWithManualSeedProducesStableResults() public {
        vm.startPrank(player);
        uint256 spinIdA = delayedController.spinWithoutFinalize(100 ether, 3, keccak256("seed-a"), expressionTokenId);
        uint256 spinIdB = delayedController.spinWithoutFinalize(100 ether, 3, keccak256("seed-b"), expressionTokenId);
        vm.stopPrank();

        manualVrfCoordinator.fulfillRequestWithWord(spinIdA, 42);
        manualVrfCoordinator.fulfillRequestWithWord(spinIdB, 42);
        delayedController.finalizeForTest(spinIdA);
        delayedController.finalizeForTest(spinIdB);

        SlotMachineEngine.SpinResult memory resultA = delayedEngine.getSpinResult(spinIdA);
        SlotMachineEngine.SpinResult memory resultB = delayedEngine.getSpinResult(spinIdB);
        assertEq(resultA.totalPayout, resultB.totalPayout);
        assertEq(resultA.pickBonusPayout, resultB.pickBonusPayout);
        assertEq(resultA.totalEventCount, resultB.totalEventCount);
    }

    function test_PayoutCapRevertsOverCapResolution() public {
        delayedEngine.registerPreset(SlotMachinePresetFactory.lowCapPreset());

        vm.prank(player);
        uint256 spinId = delayedController.spinWithoutFinalize(100 ether, 5, keccak256("low-cap"), expressionTokenId);
        vm.expectRevert("ManualVRF: callback failed");
        manualVrfCoordinator.fulfillRequestWithWord(spinId, 1);
    }

    function test_EventCapRevertsOverCapResolution() public {
        delayedEngine.registerPreset(SlotMachinePresetFactory.lowEventCapPreset());

        vm.prank(player);
        uint256 spinId = delayedController.spinWithoutFinalize(100 ether, 5, keccak256("low-events"), expressionTokenId);
        vm.expectRevert("ManualVRF: callback failed");
        manualVrfCoordinator.fulfillRequestWithWord(spinId, 1);
    }

    function test_GasBaseSpinNoWin() public {
        vm.prank(player);
        autoController.spin(100 ether, 1, keccak256("gas-base"), expressionTokenId);
    }

    function test_GasFreeSpinPath() public {
        vm.prank(player);
        uint256 spinId = delayedController.spinWithoutFinalize(100 ether, 2, keccak256("gas-free"), expressionTokenId);
        manualVrfCoordinator.fulfillRequestWithWord(spinId, 1);
        delayedController.finalizeForTest(spinId);
    }

    function test_GasPickBonusPath() public {
        vm.prank(player);
        uint256 spinId = delayedController.spinWithoutFinalize(100 ether, 3, keccak256("gas-pick"), expressionTokenId);
        manualVrfCoordinator.fulfillRequestWithWord(spinId, 2);
        delayedController.finalizeForTest(spinId);
    }

    function test_GasHoldAndSpinPath() public {
        vm.prank(player);
        uint256 spinId = delayedController.spinWithoutFinalize(100 ether, 4, keccak256("gas-hold"), expressionTokenId);
        manualVrfCoordinator.fulfillRequestWithWord(spinId, 3);
        delayedController.finalizeForTest(spinId);
    }

    function test_GasDelayedFinalizePath() public {
        vm.prank(player);
        uint256 spinId =
            delayedController.spinWithoutFinalize(100 ether, 1, keccak256("gas-delayed"), expressionTokenId);
        manualVrfCoordinator.fulfillRequestWithWord(spinId, 4);
        delayedController.finalizeForTest(spinId);
    }

    function test_InactivePresetAndLifecycleGatesRevert() public {
        delayedEngine.setPresetActive(1, false);

        vm.prank(player);
        vm.expectRevert("SlotMachine: inactive preset");
        delayedController.spinWithoutFinalize(100 ether, 1, keccak256("inactive-preset"), expressionTokenId);

        delayedEngine.setPresetActive(1, true);

        catalog.setModuleStatus(delayedModuleId, GameCatalog.ModuleStatus.RETIRED);
        vm.prank(player);
        vm.expectRevert("SlotMachineController: module inactive");
        delayedController.spinWithoutFinalize(100 ether, 1, keccak256("retired"), expressionTokenId);

        catalog.setModuleStatus(delayedModuleId, GameCatalog.ModuleStatus.LIVE);
        vm.prank(player);
        uint256 spinId = delayedController.spinWithoutFinalize(100 ether, 1, keccak256("disabled"), expressionTokenId);
        manualVrfCoordinator.fulfillRequestWithWord(spinId, 4);

        catalog.setModuleStatus(delayedModuleId, GameCatalog.ModuleStatus.DISABLED);
        vm.expectRevert("SlotMachineController: module inactive");
        delayedController.finalizeForTest(spinId);
    }

    function _registerPresets(SlotMachineEngine engine) internal {
        engine.registerPreset(SlotMachinePresetFactory.basePreset(1));
        engine.registerPreset(SlotMachinePresetFactory.freeSpinPreset(2));
        engine.registerPreset(SlotMachinePresetFactory.pickPreset(3));
        engine.registerPreset(SlotMachinePresetFactory.holdPreset(4));
    }
}
