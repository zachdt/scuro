// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IPokerEngine} from "./IPokerEngine.sol";

interface IPokerZKEngine is IPokerEngine {
    function submitDrawProof(
        uint256 gameId,
        address player,
        bytes32 newCommitment,
        bytes32 newEncryptionKeyCommitment,
        bytes32 newCiphertextRef,
        bytes calldata proof
    ) external;

    function submitShowdownProof(
        uint256 gameId,
        address winnerAddr,
        bool isTie,
        bytes calldata proof
    ) external;

    function claimTimeout(uint256 gameId) external;

    function getProofDeadline(uint256 gameId) external view returns (uint256);
}
