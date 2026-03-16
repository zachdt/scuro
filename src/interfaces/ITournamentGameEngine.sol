// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IScuroGameEngine} from "./IScuroGameEngine.sol";

/// @title Scuro competitive engine interface
/// @notice Shared interface for tournament and PvP engines that settle winners and payouts externally.
interface ITournamentGameEngine is IScuroGameEngine {
    /// @notice Initializes a new competitive game instance.
    function initializeGame(
        uint256 gameId,
        address[] calldata players,
        uint256[] calldata startingStacks,
        uint256 buyIn,
        uint256 reward
    ) external;

    /// @notice Resolves an expired player-clock action through the controller.
    function handleTimeout(uint256 gameId, address player) external;

    /// @notice Returns whether the game can be settled by its controller.
    function isGameOver(uint256 gameId) external view returns (bool isOver);

    /// @notice Returns winners and payout amounts for a completed game.
    function getOutcomes(uint256 gameId) external view returns (address[] memory winners, uint256[] memory payouts);
}
