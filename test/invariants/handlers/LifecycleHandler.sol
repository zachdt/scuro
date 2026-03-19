// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { GameCatalog } from "../../../src/GameCatalog.sol";
import { SlotMachineEngine } from "../../../src/engines/SlotMachineEngine.sol";
import { ManualVRFCoordinatorMock } from "../../e2e/helpers/ManualVRFCoordinatorMock.sol";
import { SlotMachineControllerHarness } from "../../helpers/SlotMachineControllerHarness.sol";
import { SlotSpinHandler } from "./SlotSpinHandler.sol";

contract LifecycleHandler is Test {
    GameCatalog internal immutable CATALOG;
    SlotMachineEngine internal immutable ENGINE;
    SlotMachineControllerHarness internal immutable CONTROLLER;
    ManualVRFCoordinatorMock internal immutable VRF;
    SlotSpinHandler internal immutable SPIN_HANDLER;
    address internal immutable PLAYER;
    uint256 internal immutable MODULE_ID;
    uint256 internal immutable EXPRESSION_TOKEN_ID;

    bool public inactiveLaunchSucceeded;
    bool public disabledProgressSucceeded;
    bool public retiredSettlementFailed;

    constructor(
        GameCatalog catalog_,
        SlotMachineEngine engine_,
        SlotMachineControllerHarness controller_,
        ManualVRFCoordinatorMock vrf_,
        SlotSpinHandler spinHandler_,
        address player_,
        uint256 moduleId_,
        uint256 expressionTokenId_
    ) {
        CATALOG = catalog_;
        ENGINE = engine_;
        CONTROLLER = controller_;
        VRF = vrf_;
        SPIN_HANDLER = spinHandler_;
        PLAYER = player_;
        MODULE_ID = moduleId_;
        EXPRESSION_TOKEN_ID = expressionTokenId_;
    }

    function setStatus(uint8 rawStatus) external {
        CATALOG.setModuleStatus(MODULE_ID, GameCatalog.ModuleStatus(uint256(rawStatus) % 3));
    }

    function attemptLaunchWhenNotLive(uint96 rawStake, uint8 rawPreset) external {
        if (CATALOG.isLaunchableController(address(CONTROLLER))) {
            return;
        }

        uint256 stake = bound(uint256(rawStake), 1 ether, 1_000 ether);
        uint256 presetId = bound(uint256(rawPreset), 1, 4);
        vm.prank(PLAYER);
        try CONTROLLER.spinWithoutFinalize(
            stake, presetId, keccak256(abi.encode("lifecycle-launch", presetId, rawStake)), EXPRESSION_TOKEN_ID
        ) {
            inactiveLaunchSucceeded = true;
        } catch { }
    }

    function attemptDisabledProgress(uint8 rawIndex, uint64 rawSeed) external {
        if (CATALOG.getModule(MODULE_ID).status != GameCatalog.ModuleStatus.DISABLED) {
            return;
        }

        uint256 spinCount = SPIN_HANDLER.trackedSpinCount();
        if (spinCount == 0) {
            return;
        }

        uint256 spinId = SPIN_HANDLER.trackedSpinIdAt(uint256(rawIndex) % spinCount);
        SlotMachineEngine.Spin memory spin = ENGINE.getSpin(spinId);
        if (spin.resolved) {
            return;
        }

        uint256 seed = bound(uint256(rawSeed), 1, type(uint64).max);
        try VRF.fulfillRequestWithWord(spinId, seed) {
            disabledProgressSucceeded = true;
        } catch { }
    }

    function attemptRetiredSettlement(uint8 rawIndex, uint64 rawSeed) external {
        if (CATALOG.getModule(MODULE_ID).status != GameCatalog.ModuleStatus.RETIRED) {
            return;
        }

        uint256 spinCount = SPIN_HANDLER.trackedSpinCount();
        if (spinCount == 0) {
            return;
        }

        uint256 spinId = SPIN_HANDLER.trackedSpinIdAt(uint256(rawIndex) % spinCount);
        if (CONTROLLER.spinSettled(spinId)) {
            return;
        }

        SlotMachineEngine.Spin memory spin = ENGINE.getSpin(spinId);
        if (!spin.resolved) {
            uint256 seed = bound(uint256(rawSeed), 1, type(uint64).max);
            try VRF.fulfillRequestWithWord(spinId, seed) { } catch { }
            spin = ENGINE.getSpin(spinId);
        }

        if (!spin.resolved || CONTROLLER.spinExpressionTokenId(spinId) != EXPRESSION_TOKEN_ID) {
            return;
        }

        try CONTROLLER.finalizeForTest(spinId) {
            SPIN_HANDLER.recordExternalSettlement(spinId);
        } catch {
            retiredSettlementFailed = true;
        }
    }
}
