// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IScuroGameEngine} from "./IScuroGameEngine.sol";

interface ITournamentGameEngine is IScuroGameEngine {
    function initializeGame(
        uint256 gameId,
        address[] calldata players,
        uint256[] calldata startingStacks,
        uint256 buyIn,
        uint256 reward
    ) external;

    function handleTimeout(uint256 gameId, address player) external;

    function isGameOver(uint256 gameId) external view returns (bool isOver);

    function getOutcomes(uint256 gameId) external view returns (address[] memory winners, uint256[] memory payouts);
}
