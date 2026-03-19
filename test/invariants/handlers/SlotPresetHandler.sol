// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { SlotMachineEngine } from "../../../src/engines/SlotMachineEngine.sol";
import { ManualVRFCoordinatorMock } from "../../e2e/helpers/ManualVRFCoordinatorMock.sol";
import { SlotMachineControllerHarness } from "../../helpers/SlotMachineControllerHarness.sol";
import { SlotMachinePresetFactory } from "../../helpers/SlotMachinePresetFactory.sol";

contract SlotPresetHandler is Test {
    uint256 internal constant MAX_REGISTERED_PRESETS = 12;

    SlotMachineEngine internal immutable ENGINE;
    SlotMachineControllerHarness internal immutable CONTROLLER;
    ManualVRFCoordinatorMock internal immutable VRF;
    address internal immutable PLAYER;
    uint256 internal immutable EXPRESSION_TOKEN_ID;

    bool public inactivePresetLaunchSucceeded;
    bool public presetMutationDetected;
    bool public determinismMismatch;

    uint256[] internal registeredPresetIds;
    mapping(uint256 => bytes32) internal registeredConfigHashes;

    constructor(
        SlotMachineEngine engine_,
        SlotMachineControllerHarness controller_,
        ManualVRFCoordinatorMock vrf_,
        address player_,
        uint256 expressionTokenId_
    ) {
        ENGINE = engine_;
        CONTROLLER = controller_;
        VRF = vrf_;
        PLAYER = player_;
        EXPRESSION_TOKEN_ID = expressionTokenId_;
    }

    function togglePreset(uint8 rawPreset, bool active) external {
        uint256 presetId = bound(uint256(rawPreset), 1, 4);
        ENGINE.setPresetActive(presetId, active);
    }

    function attemptLaunchWhenInactive(uint96 rawStake, uint8 rawPreset) external {
        uint256 presetId = bound(uint256(rawPreset), 1, 4);
        if (ENGINE.presetActive(presetId)) {
            return;
        }

        uint256 stake = bound(uint256(rawStake), 1 ether, 1_000 ether);
        vm.prank(PLAYER);
        try CONTROLLER.spinWithoutFinalize(
            stake, presetId, keccak256(abi.encode("inactive-preset", presetId, rawStake)), EXPRESSION_TOKEN_ID
        ) {
            inactivePresetLaunchSucceeded = true;
        } catch { }
    }

    function registerKnownPreset(uint8 rawChoice) external {
        if (registeredPresetIds.length >= MAX_REGISTERED_PRESETS) {
            return;
        }

        SlotMachineEngine.PresetConfig memory config;
        uint256 choice = uint256(rawChoice) % 4;
        if (choice == 0) {
            config = SlotMachinePresetFactory.basePreset(1);
        } else if (choice == 1) {
            config = SlotMachinePresetFactory.freeSpinPreset(2);
        } else if (choice == 2) {
            config = SlotMachinePresetFactory.pickPreset(3);
        } else {
            config = SlotMachinePresetFactory.holdPreset(4);
        }

        uint256 presetId = ENGINE.registerPreset(config);
        registeredPresetIds.push(presetId);
        registeredConfigHashes[presetId] = config.configHash;
    }

    function checkRegisteredPresetSnapshot(uint8 rawIndex) external {
        if (registeredPresetIds.length == 0) {
            return;
        }

        uint256 presetId = registeredPresetIds[uint256(rawIndex) % registeredPresetIds.length];
        SlotMachineEngine.PresetConfig memory config = ENGINE.getPreset(presetId);
        if (config.configHash != registeredConfigHashes[presetId]) {
            presetMutationDetected = true;
        }
    }

    function replayDeterministicSeed(uint64 rawSeed) external {
        if (!CONTROLLER.catalog().isLaunchableController(address(CONTROLLER)) || !ENGINE.presetActive(3)) {
            return;
        }

        uint256 seed = bound(uint256(rawSeed), 1, type(uint64).max);

        vm.startPrank(PLAYER);
        uint256 spinIdA =
            CONTROLLER.spinWithoutFinalize(100 ether, 3, keccak256("deterministic-a"), EXPRESSION_TOKEN_ID);
        uint256 spinIdB =
            CONTROLLER.spinWithoutFinalize(100 ether, 3, keccak256("deterministic-b"), EXPRESSION_TOKEN_ID);
        vm.stopPrank();

        VRF.fulfillRequestWithWord(spinIdA, seed);
        VRF.fulfillRequestWithWord(spinIdB, seed);
        CONTROLLER.finalizeForTest(spinIdA);
        CONTROLLER.finalizeForTest(spinIdB);

        SlotMachineEngine.SpinResult memory resultA = ENGINE.getSpinResult(spinIdA);
        SlotMachineEngine.SpinResult memory resultB = ENGINE.getSpinResult(spinIdB);
        if (
            resultA.totalPayout != resultB.totalPayout || resultA.totalEventCount != resultB.totalEventCount
                || resultA.jackpotPayout != resultB.jackpotPayout
        ) {
            determinismMismatch = true;
        }
    }
}
