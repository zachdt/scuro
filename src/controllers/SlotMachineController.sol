// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseSoloController} from "./BaseSoloController.sol";
import {ISoloLifecycleEngine} from "../interfaces/ISoloLifecycleEngine.sol";
import {SlotMachineEngine} from "../engines/SlotMachineEngine.sol";

/// @title Slot machine controller
/// @notice Burns the player stake, launches a governed slot preset, and settles the resolved payout.
contract SlotMachineController is BaseSoloController {
    SlotMachineEngine internal immutable ENGINE;

    event SpinFinalized(
        uint256 indexed spinId,
        address indexed player,
        uint256 indexed expressionTokenId,
        uint256 presetId,
        uint256 stake,
        uint256 payout
    );

    constructor(address settlementAddress, address catalogAddress, address engineAddress)
        BaseSoloController(settlementAddress, catalogAddress, engineAddress)
    {
        ENGINE = SlotMachineEngine(engineAddress);
    }

    function engine() public view returns (SlotMachineEngine) {
        return ENGINE;
    }

    function spinSettled(uint256 spinId) public view returns (bool) {
        return _isSettled(spinId);
    }

    function spinExpressionTokenId(uint256 spinId) public view returns (uint256) {
        return _expressionTokenId(spinId);
    }

    function spin(uint256 stake, uint256 presetId, bytes32 playRef, uint256 expressionTokenId)
        external
        returns (uint256 spinId)
    {
        _requireLaunchable("SlotMachineController: module inactive");
        _burnPlayerWager(msg.sender, stake);
        spinId = ENGINE.requestSpin(msg.sender, stake, presetId, playRef);
        _recordExpressionTokenId(spinId, expressionTokenId);
        _finalize(spinId);
    }

    function settle(uint256 spinId) external {
        _finalize(spinId);
    }

    function _finalize(uint256 spinId) internal {
        _requireSettlable("SlotMachineController: module inactive");
        _markSettled(spinId, "SlotMachineController: settled");

        (address player, uint256 totalBurned, uint256 payout, bool completed) =
            ISoloLifecycleEngine(address(ENGINE)).getSettlementOutcome(spinId);
        require(completed, "SlotMachineController: pending");

        uint256 expressionTokenId = _expressionTokenId(spinId);
        _mintAndAccrue(player, payout, totalBurned, expressionTokenId);

        SlotMachineEngine.Spin memory spinData = ENGINE.getSpin(spinId);
        emit SpinFinalized(spinId, player, expressionTokenId, spinData.presetId, totalBurned, payout);
    }
}
