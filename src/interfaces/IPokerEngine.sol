// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./ITournamentGameEngine.sol";

interface IPokerEngine is ITournamentGameEngine {
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
        uint256 deadlineAt;
        uint8 expectedActor;
    }

    function initializeHandState(
        uint256 gameId,
        bytes32 deckCommitment,
        bytes32 handNonce,
        bytes32[2] calldata handCommitments,
        bytes32[2] calldata encryptionKeyCommitments,
        bytes32[2] calldata ciphertextRefs
    ) external;

    function getHandState(uint256 gameId) external view returns (HandStateView memory);

    function getCurrentPhase(uint256 gameId) external view returns (uint8);
}
