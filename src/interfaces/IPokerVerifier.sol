// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPokerVerifier {
    function verify(bytes calldata proof, bytes32 statementHash) external view returns (bool);
}
