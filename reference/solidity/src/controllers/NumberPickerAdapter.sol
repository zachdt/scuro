// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseSoloController} from "./BaseSoloController.sol";
import {NumberPickerEngine} from "../engines/NumberPickerEngine.sol";
import {ISoloLifecycleEngine} from "../interfaces/ISoloLifecycleEngine.sol";

contract NumberPickerAdapter is BaseSoloController {
    NumberPickerEngine internal immutable ENGINE;

    event PlayFinalized(
        uint256 indexed requestId,
        address indexed player,
        uint256 indexed expressionTokenId,
        uint256 wager,
        uint256 payout,
        bool isWin
    );

    constructor(address settlementAddress, address catalogAddress, address engineAddress)
        BaseSoloController(settlementAddress, catalogAddress, engineAddress)
    {
        ENGINE = NumberPickerEngine(engineAddress);
    }

    function engine() public view returns (NumberPickerEngine) {
        return ENGINE;
    }

    function requestSettled(uint256 requestId) public view returns (bool) {
        return _isSettled(requestId);
    }

    function requestExpressionTokenId(uint256 requestId) public view returns (uint256) {
        return _expressionTokenId(requestId);
    }

    function play(uint256 wager, uint256 selection, bytes32 playRef, uint256 expressionTokenId)
        external
        returns (uint256 requestId)
    {
        _requireLaunchable("NumberPickerAdapter: module inactive");
        _burnPlayerWager(msg.sender, wager);
        requestId = ENGINE.requestPlay(msg.sender, wager, selection, playRef);
        _recordExpressionTokenId(requestId, expressionTokenId);
        _finalize(requestId);
    }

    function finalize(uint256 requestId) external {
        _finalize(requestId);
    }

    function _finalize(uint256 requestId) internal {
        _requireSettlable("NumberPickerAdapter: module inactive");
        _markSettled(requestId, "NumberPickerAdapter: settled");

        (address player, uint256 wager, uint256 payout, bool completed) =
            ISoloLifecycleEngine(address(ENGINE)).getSettlementOutcome(requestId);
        require(completed, "NumberPickerAdapter: pending");

        (, , , , uint256 enginePayout, bool isWin, ) = ENGINE.getOutcome(requestId);
        if (enginePayout != payout) {
            revert("NumberPickerAdapter: payout mismatch");
        }

        uint256 expressionTokenId = _expressionTokenId(requestId);
        _mintAndAccrue(player, payout, wager, expressionTokenId);
        emit PlayFinalized(requestId, player, expressionTokenId, wager, payout, isWin);
    }
}
