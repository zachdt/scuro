// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ITournamentGameEngine} from "./ITournamentGameEngine.sol";

/// @title Poker engine interface
/// @notice Extends the competitive engine interface with poker-specific proof and hand-state reads.
interface IPokerEngine is ITournamentGameEngine {
    /// @notice Snapshot of the current poker hand state for a game.
    struct HandStateView {
        uint256 handNumber;
        uint8 handPhase;
        bytes32 deckCommitment;
        bytes32 handNonce;
        bytes32[2] handCommitments;
        bytes32[2] encryptionKeyCommitments;
        bytes32[2] ciphertextRefs;
        uint256[2] proofSequences;
        bool[2] drawResolved;
        bool[2] drawDeclared;
        uint8[2] declaredDrawMasks;
        uint256 deadlineAt;
        uint8 expectedActor;
    }

    /// @notice Submits the initial-deal proof and encrypted hand metadata for a hand.
    function submitInitialDealProof(
        uint256 gameId,
        bytes32 deckCommitment,
        bytes32 handNonce,
        bytes32[2] calldata handCommitments,
        bytes32[2] calldata encryptionKeyCommitments,
        bytes32[2] calldata ciphertextRefs,
        bytes calldata proof
    ) external;

    /// @notice Declares the cards a player wants to discard during the draw phase.
    function declareDraw(uint256 gameId, uint8[] calldata cardIndices) external;

    /// @notice Returns the current hand-state snapshot for a game.
    function getHandState(uint256 gameId) external view returns (HandStateView memory);

    /// @notice Returns the current hand phase as a raw enum-backed value.
    function getCurrentPhase(uint256 gameId) external view returns (uint8);
}
