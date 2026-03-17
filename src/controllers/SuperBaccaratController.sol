// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseSoloController} from "./BaseSoloController.sol";
import {BaccaratTypes} from "../libraries/BaccaratTypes.sol";
import {ISoloLifecycleEngine} from "../interfaces/ISoloLifecycleEngine.sol";
import {SuperBaccaratEngine} from "../engines/SuperBaccaratEngine.sol";

/// @title Super baccarat controller
/// @notice Starts solo baccarat picks and settles resolved outcomes through shared settlement.
contract SuperBaccaratController is BaseSoloController {
    SuperBaccaratEngine internal immutable ENGINE;

    event PlayStarted(
        uint256 indexed sessionId,
        address indexed player,
        uint256 indexed expressionTokenId,
        uint256 wager,
        BaccaratTypes.BaccaratSide side,
        bytes32 playRef
    );
    event SessionSettled(
        uint256 indexed sessionId,
        address indexed player,
        uint256 indexed expressionTokenId,
        uint256 payout,
        BaccaratTypes.BaccaratOutcome outcome
    );

    constructor(address settlementAddress, address catalogAddress, address engineAddress)
        BaseSoloController(settlementAddress, catalogAddress, engineAddress)
    {
        ENGINE = SuperBaccaratEngine(engineAddress);
    }

    function engine() public view returns (SuperBaccaratEngine) {
        return ENGINE;
    }

    function sessionSettled(uint256 sessionId) public view returns (bool) {
        return _isSettled(sessionId);
    }

    function sessionExpressionTokenId(uint256 sessionId) public view returns (uint256) {
        return _expressionTokenId(sessionId);
    }

    function play(uint256 wager, uint8 side, bytes32 playRef, uint256 expressionTokenId) external returns (uint256 sessionId) {
        _requireLaunchable("SuperBaccaratController: module inactive");
        _burnPlayerWager(msg.sender, wager);
        sessionId = ENGINE.requestPlay(msg.sender, wager, side, playRef);
        _recordExpressionTokenId(sessionId, expressionTokenId);
        emit PlayStarted(
            sessionId, msg.sender, expressionTokenId, wager, BaccaratTypes.BaccaratSide(side), playRef
        );
    }

    function settle(uint256 sessionId) external {
        _requireSettlable("SuperBaccaratController: module inactive");
        _markSettled(sessionId, "SuperBaccaratController: settled");

        (address player, uint256 totalBurned, uint256 payout, bool completed) =
            ISoloLifecycleEngine(address(ENGINE)).getSettlementOutcome(sessionId);
        require(completed, "SuperBaccaratController: pending");

        uint256 expressionTokenId = _expressionTokenId(sessionId);
        _mintAndAccrue(player, payout, totalBurned, expressionTokenId);

        (,,,,,,, BaccaratTypes.BaccaratOutcome outcome,,) = ENGINE.getRound(sessionId);
        emit SessionSettled(sessionId, player, expressionTokenId, payout, outcome);
    }
}
