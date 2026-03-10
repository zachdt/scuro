// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

library PokerZKStatements {
    function hashDrawStatement(
        bytes32 engineTypeId,
        uint256 gameId,
        uint256 handNumber,
        address player,
        bytes32 oldCommitment,
        bytes32 newCommitment,
        bytes32 deckCommitment,
        bytes32 handNonce,
        bytes32 nullifier,
        uint256 proofSequence
    ) internal pure returns (bytes32 statementHash) {
        bytes memory encoded = abi.encode(
            engineTypeId,
            gameId,
            handNumber,
            player,
            oldCommitment,
            newCommitment,
            deckCommitment,
            handNonce,
            nullifier,
            proofSequence
        );
        assembly ("memory-safe") {
            statementHash := keccak256(add(encoded, 0x20), mload(encoded))
        }
    }

    function hashShowdownStatement(
        bytes32 engineTypeId,
        uint256 gameId,
        uint256 handNumber,
        bytes32[2] memory commitments,
        address winnerAddr,
        bool isTie,
        bytes32 handNonce
    ) internal pure returns (bytes32 statementHash) {
        bytes memory encoded = abi.encode(engineTypeId, gameId, handNumber, commitments, winnerAddr, isTie, handNonce);
        assembly ("memory-safe") {
            statementHash := keccak256(add(encoded, 0x20), mload(encoded))
        }
    }
}
