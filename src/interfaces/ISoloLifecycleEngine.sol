// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IScuroGameEngine} from "./IScuroGameEngine.sol";

/// @title Scuro solo lifecycle engine interface
/// @notice Standardizes the settlement tuple returned by solo engines.
interface ISoloLifecycleEngine is IScuroGameEngine {
    /// @notice Returns the settlement outcome for a solo session identifier.
    /// @dev Controllers use this to gate final payout and developer accrual.
    function getSettlementOutcome(uint256 sessionId)
        external
        view
        returns (address player, uint256 totalBurned, uint256 payout, bool completed);
}
