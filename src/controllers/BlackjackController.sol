// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseSoloController} from "./BaseSoloController.sol";
import {BlackjackEngine} from "../engines/BlackjackEngine.sol";
import {ISoloLifecycleEngine} from "../interfaces/ISoloLifecycleEngine.sol";

/// @title Blackjack controller
/// @notice Opens blackjack sessions, forwards player actions, and settles completed sessions.
contract BlackjackController is BaseSoloController {
    BlackjackEngine internal immutable ENGINE;

    /// @notice Emitted when a new blackjack session is created.
    event HandStarted(
        uint256 indexed sessionId,
        address indexed player,
        uint256 indexed expressionTokenId,
        uint256 wager,
        bytes32 playRef
    );
    /// @notice Emitted when a completed blackjack session is settled through the controller.
    event SessionSettled(
        uint256 indexed sessionId,
        address indexed player,
        uint256 indexed expressionTokenId,
        uint256 payout,
        uint256 totalBurned
    );

    /// @notice Initializes the controller with settlement, catalog, and engine addresses.
    constructor(address settlementAddress, address catalogAddress, address engineAddress)
        BaseSoloController(settlementAddress, catalogAddress, engineAddress)
    {
        ENGINE = BlackjackEngine(engineAddress);
    }

    /// @notice Returns the concrete blackjack engine.
    function engine() public view returns (BlackjackEngine) {
        return ENGINE;
    }

    /// @notice Returns whether the session has already been settled.
    function sessionSettled(uint256 sessionId) public view returns (bool) {
        return _isSettled(sessionId);
    }

    /// @notice Returns the expression token id associated with the session.
    function sessionExpressionTokenId(uint256 sessionId) public view returns (uint256) {
        return _expressionTokenId(sessionId);
    }

    /// @notice Opens a blackjack session for the caller.
    function startHand(uint256 wager, bytes32 playRef, bytes32 playerKeyCommitment, uint256 expressionTokenId)
        external
        returns (uint256 sessionId)
    {
        _requireLaunchable("BlackjackController: module inactive");
        _burnPlayerWager(msg.sender, wager);
        sessionId = ENGINE.openSession(msg.sender, wager, playRef, playerKeyCommitment);
        _recordExpressionTokenId(sessionId, expressionTokenId);
        emit HandStarted(sessionId, msg.sender, expressionTokenId, wager, playRef);
    }

    /// @notice Declares a hit action for the caller.
    function hit(uint256 sessionId) external {
        _declareAction(msg.sender, sessionId, ENGINE.ACTION_HIT());
    }

    /// @notice Declares a stand action for the caller.
    function stand(uint256 sessionId) external {
        _declareAction(msg.sender, sessionId, ENGINE.ACTION_STAND());
    }

    /// @notice Declares a double-down action for the caller.
    function doubleDown(uint256 sessionId) external {
        _declareAction(msg.sender, sessionId, ENGINE.ACTION_DOUBLE());
    }

    /// @notice Declares a split action for the caller.
    function split(uint256 sessionId) external {
        _declareAction(msg.sender, sessionId, ENGINE.ACTION_SPLIT());
    }

    /// @notice Buys insurance during the Ace-upcard window.
    function insurance(uint256 sessionId, uint256 amount) external {
        _requireSettlable("BlackjackController: module inactive");
        _burnPlayerWager(msg.sender, amount);
        ENGINE.declareInsurance(sessionId, msg.sender, amount);
    }

    /// @notice Accepts surrender when the current session window allows it.
    function surrender(uint256 sessionId) external {
        _requireSettlable("BlackjackController: module inactive");
        ENGINE.surrender(sessionId, msg.sender);
    }

    /// @notice Explicitly declines optional pre-play decisions and advances the session.
    function continuePlay(uint256 sessionId) external {
        _requireSettlable("BlackjackController: module inactive");
        ENGINE.continuePlay(sessionId, msg.sender);
    }

    /// @notice Forces a stand after the player action window has expired.
    function claimPlayerTimeout(uint256 sessionId) external {
        _requireSettlable("BlackjackController: module inactive");
        ENGINE.claimPlayerTimeout(sessionId);
    }

    /// @notice Settles a completed blackjack session.
    function settle(uint256 sessionId) external {
        _requireSettlable("BlackjackController: module inactive");
        _markSettled(sessionId, "BlackjackController: settled");

        (address player, uint256 totalBurned, uint256 payout, bool completed) =
            ISoloLifecycleEngine(address(ENGINE)).getSettlementOutcome(sessionId);
        require(completed, "BlackjackController: active");

        uint256 expressionTokenId = _expressionTokenId(sessionId);
        _mintAndAccrue(player, payout, totalBurned, expressionTokenId);
        emit SessionSettled(sessionId, player, expressionTokenId, payout, totalBurned);
    }

    function _declareAction(address player, uint256 sessionId, uint8 action) internal {
        _requireSettlable("BlackjackController: module inactive");
        uint256 additionalBurn = ENGINE.requiredAdditionalBurn(sessionId, action);
        _burnPlayerWager(player, additionalBurn);
        ENGINE.declareAction(sessionId, player, action, additionalBurn);
    }
}
