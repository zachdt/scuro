// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IScuroGameEngine} from "./IScuroGameEngine.sol";
import {BaccaratTypes} from "../libraries/BaccaratTypes.sol";

/// @title Automated chemin de fer engine interface
/// @notice Exposes one-shot baccarat round resolution for player-banked PvP tables.
interface ICheminDeFerEngine is IScuroGameEngine {
    function requestResolution(uint256 tableId, bytes32 playRef) external returns (uint256 requestId);

    function isResolved(uint256 tableId) external view returns (bool resolved);

    function getRound(uint256 tableId)
        external
        view
        returns (
            uint8[3] memory playerCards,
            uint8[3] memory bankerCards,
            uint8 playerCardCount,
            uint8 bankerCardCount,
            uint8 playerTotal,
            uint8 bankerTotal,
            bool natural,
            BaccaratTypes.BaccaratOutcome outcome,
            uint256 randomWord,
            bool resolved,
            bytes32 playRef,
            uint256 requestId
        );
}
