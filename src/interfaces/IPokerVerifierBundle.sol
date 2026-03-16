// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title Poker verifier bundle interface
/// @notice Defines the ordered public-input shapes consumed by poker proof verifiers.
interface IPokerVerifierBundle {
    /// @notice Public inputs for the initial-deal proof.
    struct InitialDealPublicInputs {
        uint256 gameId;
        uint256 handNumber;
        uint256 handNonce;
        uint256 deckCommitment;
        uint256[2] handCommitments;
        uint256[2] encryptionKeyCommitments;
        uint256[2] ciphertextRefs;
    }

    /// @notice Public inputs for a draw-resolution proof.
    struct DrawPublicInputs {
        uint256 gameId;
        uint256 handNumber;
        uint256 handNonce;
        uint256 playerIndex;
        uint256 deckCommitment;
        uint256 oldCommitment;
        uint256 newCommitment;
        uint256 newEncryptionKeyCommitment;
        uint256 newCiphertextRef;
        uint256 discardMask;
        uint256 proofSequence;
    }

    /// @notice Public inputs for a showdown proof.
    struct ShowdownPublicInputs {
        uint256 gameId;
        uint256 handNumber;
        uint256 handNonce;
        uint256[2] handCommitments;
        uint256 winnerIndex;
        uint256 isTie;
    }

    /// @notice Verifies the initial-deal proof against the supplied public inputs.
    function verifyInitialDeal(bytes calldata proof, InitialDealPublicInputs calldata inputs) external view returns (bool);

    /// @notice Verifies a draw-resolution proof against the supplied public inputs.
    function verifyDraw(bytes calldata proof, DrawPublicInputs calldata inputs) external view returns (bool);

    /// @notice Verifies a showdown proof against the supplied public inputs.
    function verifyShowdown(bytes calldata proof, ShowdownPublicInputs calldata inputs) external view returns (bool);
}
