// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBlackjackVerifierBundle {
    struct InitialDealPublicInputs {
        uint256 sessionId;
        uint256 handNonce;
        uint256 deckCommitment;
        uint256 playerStateCommitment;
        uint256 dealerStateCommitment;
        uint256 playerKeyCommitment;
        uint256 playerCiphertextRef;
        uint256 dealerCiphertextRef;
        uint256 dealerUpValue;
        uint256 handCount;
        uint256 activeHandIndex;
        uint256 payout;
        uint256 immediateResultCode;
        uint256[4] handValues;
        uint256 softMask;
        uint256[4] handStatuses;
        uint256[4] allowedActionMasks;
    }

    struct ActionPublicInputs {
        uint256 sessionId;
        uint256 proofSequence;
        uint256 pendingAction;
        uint256 oldPlayerStateCommitment;
        uint256 newPlayerStateCommitment;
        uint256 dealerStateCommitment;
        uint256 playerKeyCommitment;
        uint256 playerCiphertextRef;
        uint256 dealerCiphertextRef;
        uint256 dealerUpValue;
        uint256 handCount;
        uint256 activeHandIndex;
        uint256 nextPhase;
        uint256[4] handValues;
        uint256 softMask;
        uint256[4] handStatuses;
        uint256[4] allowedActionMasks;
    }

    struct ShowdownPublicInputs {
        uint256 sessionId;
        uint256 proofSequence;
        uint256 playerStateCommitment;
        uint256 dealerStateCommitment;
        uint256 payout;
        uint256 dealerFinalValue;
        uint256 handCount;
        uint256 activeHandIndex;
        uint256[4] handStatuses;
    }

    function verifyInitialDeal(bytes calldata proof, InitialDealPublicInputs calldata inputs) external view returns (bool);

    function verifyAction(bytes calldata proof, ActionPublicInputs calldata inputs) external view returns (bool);

    function verifyShowdown(bytes calldata proof, ShowdownPublicInputs calldata inputs) external view returns (bool);
}
