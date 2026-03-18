// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeveloperExpressionRegistry} from "../src/DeveloperExpressionRegistry.sol";
import {DeveloperRewards} from "../src/DeveloperRewards.sol";
import {GameCatalog} from "../src/GameCatalog.sol";
import {GameDeploymentFactory} from "../src/GameDeploymentFactory.sol";
import {ProtocolSettlement} from "../src/ProtocolSettlement.sol";
import {ScuroToken} from "../src/ScuroToken.sol";
import {SlotMachineController} from "../src/controllers/SlotMachineController.sol";
import {SlotMachineEngine} from "../src/engines/SlotMachineEngine.sol";
import {VRFCoordinatorMock} from "../src/mocks/VRFCoordinatorMock.sol";
import {ManualVRFCoordinatorMock} from "./e2e/helpers/ManualVRFCoordinatorMock.sol";
import {SlotMachineControllerHarness} from "./helpers/SlotMachineControllerHarness.sol";

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
        settlement = new ProtocolSettlement(address(token), address(catalog), address(expressionRegistry), address(developerRewards));
        factory = new GameDeploymentFactory(address(this), address(catalog), address(settlement));
        autoVrfCoordinator = new VRFCoordinatorMock();
        manualVrfCoordinator = new ManualVRFCoordinatorMock();

        catalog.grantRole(catalog.REGISTRAR_ROLE(), address(factory));
        token.grantRole(token.MINTER_ROLE(), address(settlement));
        token.grantRole(token.MINTER_ROLE(), address(developerRewards));
        developerRewards.grantRole(developerRewards.SETTLEMENT_ROLE(), address(settlement));

        GameDeploymentFactory.SlotDeployment memory params = GameDeploymentFactory.SlotDeployment({
            vrfCoordinator: address(autoVrfCoordinator),
            configHash: keccak256("slot-auto"),
            developerRewardBps: 500
        });
        address controllerAddress;
        address engineAddress;
        (, controllerAddress, engineAddress, ) =
            factory.deploySoloModule(uint8(GameDeploymentFactory.SoloFamily.SlotMachine), abi.encode(params));
        autoController = SlotMachineController(controllerAddress);
        autoEngine = SlotMachineEngine(engineAddress);

        delayedEngine = new SlotMachineEngine(address(this), address(catalog), address(manualVrfCoordinator));
        delayedController = new SlotMachineControllerHarness(address(settlement), address(catalog), address(delayedEngine));
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
        SlotMachineEngine.PresetConfig memory malformed = _basePresetConfig(1);
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
        assertTrue(pickResult.triggeredPickBonus);
        assertGt(pickResult.pickBonusPayout, 0);
        assertTrue(holdResult.triggeredHoldAndSpin);
        assertGt(holdResult.holdAndSpinPayout, 0);

        vm.expectRevert("SlotMachineController: settled");
        delayedController.finalizeForTest(freeSpinId);
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
        engine.registerPreset(_basePresetConfig(1));
        engine.registerPreset(_freeSpinPresetConfig(2));
        engine.registerPreset(_pickPresetConfig(3));
        engine.registerPreset(_holdPresetConfig(4));
    }

    function _basePresetConfig(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config.volatilityTier = volatility;
        config.configHash = keccak256("base");
        config.reelCount = 5;
        config.rowCount = 3;
        config.waysMode = 1;
        config.minStake = 1 ether;
        config.maxStake = 1_000 ether;
        config.maxPayoutMultiplierBps = 10_000_000;
        config.symbolIds = new uint16[](4);
        config.symbolIds[0] = 1;
        config.symbolIds[1] = 2;
        config.symbolIds[2] = 3;
        config.symbolIds[3] = 4;
        config.wildSymbolId = 0;
        config.scatterSymbolId = 2;
        config.bonusSymbolId = 3;
        config.jackpotSymbolId = 4;
        config.reelWeightOffsets = new uint16[](6);
        config.reelSymbolIds = new uint16[](5);
        config.reelSymbolWeights = new uint16[](5);
        for (uint256 i = 0; i < 5; i++) {
            // forge-lint: disable-next-line(unsafe-typecast)
            config.reelWeightOffsets[i] = uint16(i);
            config.reelSymbolIds[i] = 1;
            config.reelSymbolWeights[i] = 100;
        }
        config.reelWeightOffsets[5] = 5;
        config.paytableSymbolIds = new uint16[](1);
        config.paytableSymbolIds[0] = 1;
        config.paytableMatchCounts = new uint8[](1);
        config.paytableMatchCounts[0] = 3;
        config.paytableMultiplierBps = new uint32[](1);
        config.paytableMultiplierBps[0] = 1_000;
        config.freeSpinTriggerCount = 3;
        config.freeSpinAwardCounts = new uint8[](2);
        config.freeSpinAwardCounts[0] = 3;
        config.freeSpinAwardCounts[1] = 5;
        config.maxFreeSpins = 8;
        config.maxRetriggers = 2;
        config.freeSpinMultiplierBps = 10_000;
        config.pickTriggerCount = 20;
        config.maxPickReveals = 3;
        config.pickAwardMultiplierBps = new uint32[](2);
        config.pickAwardMultiplierBps[0] = 500;
        config.pickAwardMultiplierBps[1] = 1_500;
        config.holdTriggerCount = 20;
        config.holdBoardSize = 20;
        config.initialRespins = 3;
        config.maxRespins = 6;
        config.holdValueMultiplierBps = new uint32[](1);
        config.holdValueMultiplierBps[0] = 500;
        config.jackpotTierIds = new uint8[](1);
        config.jackpotTierIds[0] = 1;
        config.jackpotAwardMultiplierBps = new uint32[](1);
        config.jackpotAwardMultiplierBps[0] = 5_000;
        config.jackpotTierWeights = new uint16[](1);
        config.jackpotTierWeights[0] = 1;
        config.maxTotalEvents = 24;
    }

    function _freeSpinPresetConfig(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = _basePresetConfig(volatility);
        config.configHash = keccak256("free");
        for (uint256 i = 0; i < config.reelSymbolIds.length; i++) {
            config.reelSymbolIds[i] = 2;
        }
        config.paytableSymbolIds[0] = 2;
        config.paytableMatchCounts[0] = 5;
        config.paytableMultiplierBps[0] = 2_000;
        config.freeSpinMultiplierBps = 15_000;
        config.maxFreeSpins = 6;
        config.maxRetriggers = 1;
        config.maxTotalEvents = 16;
    }

    function _pickPresetConfig(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = _basePresetConfig(volatility);
        config.configHash = keccak256("pick");
        for (uint256 i = 0; i < config.reelSymbolIds.length; i++) {
            config.reelSymbolIds[i] = 3;
        }
        config.pickTriggerCount = 1;
        config.maxPickReveals = 4;
        config.pickAwardMultiplierBps = new uint32[](2);
        config.pickAwardMultiplierBps[0] = 1_000;
        config.pickAwardMultiplierBps[1] = 2_000;
        config.holdTriggerCount = 20;
        config.maxTotalEvents = 16;
    }

    function _holdPresetConfig(uint8 volatility) internal pure returns (SlotMachineEngine.PresetConfig memory config) {
        config = _basePresetConfig(volatility);
        config.configHash = keccak256("hold");
        for (uint256 i = 0; i < config.reelSymbolIds.length; i++) {
            config.reelSymbolIds[i] = 3;
        }
        config.pickTriggerCount = 20;
        config.holdTriggerCount = 1;
        config.holdBoardSize = 20;
        config.initialRespins = 3;
        config.maxRespins = 5;
        config.holdValueMultiplierBps = new uint32[](1);
        config.holdValueMultiplierBps[0] = 2_500;
        config.jackpotTierIds = new uint8[](1);
        config.jackpotTierIds[0] = 1;
        config.jackpotAwardMultiplierBps = new uint32[](1);
        config.jackpotAwardMultiplierBps[0] = 7_500;
        config.jackpotTierWeights = new uint16[](1);
        config.jackpotTierWeights[0] = 60_000;
        config.maxTotalEvents = 20;
    }
}
