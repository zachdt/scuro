// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { DeveloperRewards } from "../../../src/DeveloperRewards.sol";
import { GameCatalog } from "../../../src/GameCatalog.sol";
import { ScuroToken } from "../../../src/ScuroToken.sol";
import { SlotMachineEngine } from "../../../src/engines/SlotMachineEngine.sol";
import { ManualVRFCoordinatorMock } from "../../e2e/helpers/ManualVRFCoordinatorMock.sol";
import { SlotMachineControllerHarness } from "../../helpers/SlotMachineControllerHarness.sol";

contract SlotSpinHandler is Test {
    uint16 internal constant DEVELOPER_BPS = 500;
    uint256 internal constant MAX_TRACKED_SPINS = 32;

    ScuroToken internal immutable TOKEN;
    DeveloperRewards internal immutable DEVELOPER_REWARDS;
    GameCatalog internal immutable CATALOG;
    SlotMachineEngine internal immutable ENGINE;
    SlotMachineControllerHarness internal immutable CONTROLLER;
    ManualVRFCoordinatorMock internal immutable VRF;
    address internal immutable PLAYER;
    address internal immutable DEVELOPER;
    uint256 internal immutable EXPRESSION_TOKEN_ID;
    uint256 internal immutable MISMATCHED_EXPRESSION_TOKEN_ID;

    uint256 internal immutable STARTING_BALANCE;

    uint256 public totalBurned;
    uint256 public totalSettledPayout;
    uint256 public expectedDeveloperAccrual;
    bool public pendingSettleSucceeded;
    bool public doubleSettleSucceeded;
    bool public disabledSettleSucceeded;
    bool public mismatchFinalizeSucceeded;

    uint256[] internal trackedSpinIds;
    mapping(uint256 => bool) internal trackedSpin;
    mapping(uint256 => bool) internal settlementCounted;

    constructor(
        ScuroToken token_,
        DeveloperRewards developerRewards_,
        GameCatalog catalog_,
        SlotMachineEngine engine_,
        SlotMachineControllerHarness controller_,
        ManualVRFCoordinatorMock vrf_,
        address player_,
        address developer_,
        uint256 expressionTokenId_,
        uint256 mismatchedExpressionTokenId_
    ) {
        TOKEN = token_;
        DEVELOPER_REWARDS = developerRewards_;
        CATALOG = catalog_;
        ENGINE = engine_;
        CONTROLLER = controller_;
        VRF = vrf_;
        PLAYER = player_;
        DEVELOPER = developer_;
        EXPRESSION_TOKEN_ID = expressionTokenId_;
        MISMATCHED_EXPRESSION_TOKEN_ID = mismatchedExpressionTokenId_;
        STARTING_BALANCE = token_.balanceOf(player_);
    }

    function trackedSpinCount() external view returns (uint256) {
        return trackedSpinIds.length;
    }

    function trackedSpinIdAt(uint256 index) external view returns (uint256) {
        if (trackedSpinIds.length == 0) {
            return 0;
        }
        return trackedSpinIds[index % trackedSpinIds.length];
    }

    function startingBalance() external view returns (uint256) {
        return STARTING_BALANCE;
    }

    function launchSpin(uint96 rawStake, uint8 rawPreset) external {
        if (!CATALOG.isLaunchableController(address(CONTROLLER))) {
            return;
        }

        uint256 stake = bound(uint256(rawStake), 1 ether, 1_000 ether);
        uint256 presetId = bound(uint256(rawPreset), 1, 4);

        vm.prank(PLAYER);
        try CONTROLLER.spinWithoutFinalize(
            stake, presetId, keccak256(abi.encode("slot-spin", trackedSpinIds.length)), EXPRESSION_TOKEN_ID
        ) returns (
            uint256 spinId
        ) {
            totalBurned += stake;
            _trackSpin(spinId);
        } catch { }
    }

    function launchMismatchedSpin(uint96 rawStake, uint8 rawPreset) external {
        if (!CATALOG.isLaunchableController(address(CONTROLLER))) {
            return;
        }

        uint256 stake = bound(uint256(rawStake), 1 ether, 1_000 ether);
        uint256 presetId = bound(uint256(rawPreset), 1, 4);

        vm.prank(PLAYER);
        try CONTROLLER.spinWithoutFinalize(
            stake,
            presetId,
            keccak256(abi.encode("slot-mismatch", trackedSpinIds.length)),
            MISMATCHED_EXPRESSION_TOKEN_ID
        ) returns (
            uint256 spinId
        ) {
            totalBurned += stake;
            _trackSpin(spinId);
        } catch { }
    }

    function fulfillTrackedSpin(uint8 rawIndex, uint64 rawSeed) external {
        if (trackedSpinIds.length == 0) {
            return;
        }

        uint256 spinId = trackedSpinIds[uint256(rawIndex) % trackedSpinIds.length];
        SlotMachineEngine.Spin memory spin = ENGINE.getSpin(spinId);
        if (spin.resolved) {
            return;
        }

        uint256 seed = bound(uint256(rawSeed), 1, type(uint64).max);
        GameCatalog.ModuleStatus status = CATALOG.getModule(CATALOG.controllerModuleIds(address(CONTROLLER))).status;

        try VRF.fulfillRequestWithWord(spinId, seed) {
            if (status == GameCatalog.ModuleStatus.DISABLED) {
                disabledSettleSucceeded = true;
            }
        } catch { }
    }

    function finalizeTrackedSpin(uint8 rawIndex) external {
        if (trackedSpinIds.length == 0) {
            return;
        }

        uint256 spinId = trackedSpinIds[uint256(rawIndex) % trackedSpinIds.length];
        bool settled = CONTROLLER.spinSettled(spinId);
        GameCatalog.ModuleStatus status = CATALOG.getModule(CATALOG.controllerModuleIds(address(CONTROLLER))).status;

        if (settled) {
            try CONTROLLER.finalizeForTest(spinId) {
                doubleSettleSucceeded = true;
            } catch { }
            return;
        }

        bool resolved = ENGINE.getSpin(spinId).resolved;
        try CONTROLLER.finalizeForTest(spinId) {
            if (!resolved) {
                pendingSettleSucceeded = true;
            }
            if (status == GameCatalog.ModuleStatus.DISABLED) {
                disabledSettleSucceeded = true;
            }
            _recordSettlement(spinId);
        } catch { }
    }

    function recordExternalSettlement(uint256 spinId) external {
        if (!trackedSpin[spinId]) {
            return;
        }
        _recordSettlement(spinId);
    }

    function _trackSpin(uint256 spinId) internal {
        trackedSpin[spinId] = true;
        if (trackedSpinIds.length < MAX_TRACKED_SPINS) {
            trackedSpinIds.push(spinId);
        }
    }

    function _recordSettlement(uint256 spinId) internal {
        if (settlementCounted[spinId] || !CONTROLLER.spinSettled(spinId)) {
            return;
        }

        settlementCounted[spinId] = true;
        SlotMachineEngine.Spin memory spin = ENGINE.getSpin(spinId);
        totalSettledPayout += spin.finalPayout;

        uint256 expressionTokenId = CONTROLLER.spinExpressionTokenId(spinId);
        if (expressionTokenId == MISMATCHED_EXPRESSION_TOKEN_ID) {
            mismatchFinalizeSucceeded = true;
            return;
        }

        expectedDeveloperAccrual += (spin.stake * DEVELOPER_BPS) / 10_000;
    }

    function playerBalanceMatchesAccounting() external view returns (bool) {
        return TOKEN.balanceOf(PLAYER) == STARTING_BALANCE - totalBurned + totalSettledPayout;
    }

    function developerAccrualMatchesAccounting() external view returns (bool) {
        return DEVELOPER_REWARDS.epochAccrual(1, DEVELOPER) == expectedDeveloperAccrual;
    }
}
