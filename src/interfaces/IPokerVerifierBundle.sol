// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPokerVerifierBundle {
    struct InitialDealPublicInputs {
        uint256 gameId;
        uint256 handNumber;
        uint256 handNonce;
        uint256 deckCommitment;
        uint256[2] handCommitments;
        uint256[2] encryptionKeyCommitments;
        uint256[2] ciphertextRefs;
    }

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

    struct ShowdownPublicInputs {
        uint256 gameId;
        uint256 handNumber;
        uint256 handNonce;
        uint256[2] handCommitments;
        uint256 winnerIndex;
        uint256 isTie;
    }

    function verifyInitialDeal(bytes calldata proof, InitialDealPublicInputs calldata inputs) external view returns (bool);

    function verifyDraw(bytes calldata proof, DrawPublicInputs calldata inputs) external view returns (bool);

    function verifyShowdown(bytes calldata proof, ShowdownPublicInputs calldata inputs) external view returns (bool);
}
