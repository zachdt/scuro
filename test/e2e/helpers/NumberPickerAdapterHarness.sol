// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NumberPickerAdapter} from "../../../src/controllers/NumberPickerAdapter.sol";

contract NumberPickerAdapterHarness is NumberPickerAdapter {
    constructor(address admin, address settlementAddress, address registryAddress, address engineAddress)
        NumberPickerAdapter(admin, settlementAddress, registryAddress, engineAddress)
    {}

    function playWithoutFinalize(uint256 wager, uint256 selection, bytes32 playRef) external returns (uint256 requestId) {
        require(REGISTRY.isRegisteredForSolo(address(ENGINE)), "NumberPickerAdapter: engine inactive");
        SETTLEMENT.burnPlayerWager(msg.sender, wager);
        requestId = ENGINE.requestPlay(msg.sender, wager, selection, playRef);
    }

    function finalizeForTest(uint256 requestId) external {
        _finalize(requestId);
    }
}
