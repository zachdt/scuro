// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IPokerEngine} from "./IPokerEngine.sol";

/// @title ZK-enabled poker engine interface
/// @notice Adds draw, showdown, timeout, and deadline operations to the base poker engine interface.
interface IPokerZKEngine is IPokerEngine {
    /// @notice Submits a draw-resolution proof for one player.
    function submitDrawProof(
        uint256 gameId,
        address player,
        bytes32 newCommitment,
        bytes32 newEncryptionKeyCommitment,
        bytes32 newCiphertextRef,
        bytes calldata proof
    ) external;

    /// @notice Submits a showdown proof and the resulting winner metadata.
    function submitShowdownProof(
        uint256 gameId,
        address winnerAddr,
        bool isTie,
        bytes calldata proof
    ) external;

    /// @notice Claims a timeout during a player-clock phase.
    function claimTimeout(uint256 gameId) external;

    /// @notice Returns the current player deadline for the active hand phase.
    function getProofDeadline(uint256 gameId) external view returns (uint256);
}
