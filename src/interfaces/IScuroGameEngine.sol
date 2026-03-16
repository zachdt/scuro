// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title Scuro base engine interface
/// @notice Exposes the engine-type tag used for module registration and expression compatibility.
interface IScuroGameEngine {
    /// @notice Returns the canonical engine type tag for this engine family.
    function engineType() external pure returns (bytes32);
}
