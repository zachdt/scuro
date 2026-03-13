// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {NumberPickerAdapter} from "../../../src/controllers/NumberPickerAdapter.sol";

contract NumberPickerAdapterHarness is NumberPickerAdapter {
    constructor(address settlementAddress, address catalogAddress, address engineAddress)
        NumberPickerAdapter(settlementAddress, catalogAddress, engineAddress)
    {}

    function playWithoutFinalize(uint256 wager, uint256 selection, bytes32 playRef, uint256 expressionTokenId)
        external
        returns (uint256 requestId)
    {
        _requireLaunchable("NumberPickerAdapter: module inactive");
        _burnPlayerWager(msg.sender, wager);
        requestId = ENGINE.requestPlay(msg.sender, wager, selection, playRef);
        _recordExpressionTokenId(requestId, expressionTokenId);
    }

    function finalizeForTest(uint256 requestId) external {
        _finalize(requestId);
    }
}
