// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SlotMachineController} from "../../src/controllers/SlotMachineController.sol";

contract SlotMachineControllerHarness is SlotMachineController {
    constructor(address settlementAddress, address catalogAddress, address engineAddress)
        SlotMachineController(settlementAddress, catalogAddress, engineAddress)
    {}

    function spinWithoutFinalize(uint256 stake, uint256 presetId, bytes32 playRef, uint256 expressionTokenId)
        external
        returns (uint256 spinId)
    {
        _requireLaunchable("SlotMachineController: module inactive");
        _burnPlayerWager(msg.sender, stake);
        spinId = ENGINE.requestSpin(msg.sender, stake, presetId, playRef);
        _recordExpressionTokenId(spinId, expressionTokenId);
    }

    function finalizeForTest(uint256 spinId) external {
        _finalize(spinId);
    }
}
