// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ITournamentGameEngine} from "./ITournamentGameEngine.sol";

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
        bool[2] drawDeclared;
        uint8[2] declaredDrawMasks;
        uint256 deadlineAt;
        uint8 expectedActor;
    }

    function submitInitialDealProof(
        uint256 gameId,
        bytes32 deckCommitment,
        bytes32 handNonce,
        bytes32[2] calldata handCommitments,
        bytes32[2] calldata encryptionKeyCommitments,
        bytes32[2] calldata ciphertextRefs,
        bytes calldata proof
    ) external;

    function declareDraw(uint256 gameId, uint8[] calldata cardIndices) external;

    function getHandState(uint256 gameId) external view returns (HandStateView memory);

    function getCurrentPhase(uint256 gameId) external view returns (uint8);
}
