// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title Blackjack verifier bundle interface
/// @notice Defines the ordered public-input shapes consumed by canonical blackjack proof verifiers.
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
        uint256 phase;
        uint256 decisionType;
        uint256 dealerUpValue;
        uint256 dealerFinalValue;
        uint256 payout;
        uint256 insuranceStake;
        uint256 insurancePayout;
        uint256 dealerRevealMask;
        uint256 handCount;
        uint256 activeHandIndex;
        uint256 peekAvailable;
        uint256 peekResolved;
        uint256 dealerHasBlackjack;
        uint256 insuranceAvailable;
        uint256 insuranceStatus;
        uint256 surrenderAvailable;
        uint256 surrenderStatus;
        uint256[4] handWagers;
        uint256[4] handValues;
        uint256[4] handStatuses;
        uint256[4] allowedActionMasks;
        uint256[4] handCardCounts;
        uint256[4] handCardStartIndices;
        uint256[4] handPayoutKinds;
        uint256[32] playerCards;
        uint256[12] dealerCards;
    }

    struct PeekPublicInputs {
        uint256 sessionId;
        uint256 proofSequence;
        uint256 deckCommitment;
        uint256 playerStateCommitment;
        uint256 dealerStateCommitment;
        uint256 playerKeyCommitment;
        uint256 playerCiphertextRef;
        uint256 dealerCiphertextRef;
        uint256 phase;
        uint256 decisionType;
        uint256 dealerUpValue;
        uint256 dealerFinalValue;
        uint256 payout;
        uint256 insuranceStake;
        uint256 insurancePayout;
        uint256 dealerRevealMask;
        uint256 handCount;
        uint256 activeHandIndex;
        uint256 peekAvailable;
        uint256 peekResolved;
        uint256 dealerHasBlackjack;
        uint256 insuranceAvailable;
        uint256 insuranceStatus;
        uint256 surrenderAvailable;
        uint256 surrenderStatus;
        uint256[4] handWagers;
        uint256[4] handValues;
        uint256[4] handStatuses;
        uint256[4] allowedActionMasks;
        uint256[4] handCardCounts;
        uint256[4] handCardStartIndices;
        uint256[4] handPayoutKinds;
        uint256[32] playerCards;
        uint256[12] dealerCards;
    }

    struct ActionPublicInputs {
        uint256 sessionId;
        uint256 proofSequence;
        uint256 pendingAction;
        uint256 deckCommitment;
        uint256 oldPlayerStateCommitment;
        uint256 newPlayerStateCommitment;
        uint256 dealerStateCommitment;
        uint256 playerKeyCommitment;
        uint256 playerCiphertextRef;
        uint256 dealerCiphertextRef;
        uint256 phase;
        uint256 decisionType;
        uint256 dealerUpValue;
        uint256 dealerFinalValue;
        uint256 payout;
        uint256 insuranceStake;
        uint256 insurancePayout;
        uint256 dealerRevealMask;
        uint256 handCount;
        uint256 activeHandIndex;
        uint256 peekAvailable;
        uint256 peekResolved;
        uint256 dealerHasBlackjack;
        uint256 insuranceAvailable;
        uint256 insuranceStatus;
        uint256 surrenderAvailable;
        uint256 surrenderStatus;
        uint256[4] handWagers;
        uint256[4] handValues;
        uint256[4] handStatuses;
        uint256[4] allowedActionMasks;
        uint256[4] handCardCounts;
        uint256[4] handCardStartIndices;
        uint256[4] handPayoutKinds;
        uint256[32] playerCards;
        uint256[12] dealerCards;
    }

    struct ShowdownPublicInputs {
        uint256 sessionId;
        uint256 proofSequence;
        uint256 deckCommitment;
        uint256 playerStateCommitment;
        uint256 dealerStateCommitment;
        uint256 playerKeyCommitment;
        uint256 phase;
        uint256 decisionType;
        uint256 dealerUpValue;
        uint256 dealerFinalValue;
        uint256 payout;
        uint256 insuranceStake;
        uint256 insurancePayout;
        uint256 dealerRevealMask;
        uint256 handCount;
        uint256 activeHandIndex;
        uint256 peekAvailable;
        uint256 peekResolved;
        uint256 dealerHasBlackjack;
        uint256 insuranceAvailable;
        uint256 insuranceStatus;
        uint256 surrenderAvailable;
        uint256 surrenderStatus;
        uint256[4] handWagers;
        uint256[4] handValues;
        uint256[4] handStatuses;
        uint256[4] allowedActionMasks;
        uint256[4] handCardCounts;
        uint256[4] handCardStartIndices;
        uint256[4] handPayoutKinds;
        uint256[32] playerCards;
        uint256[12] dealerCards;
    }

    function verifyInitialDeal(bytes calldata proof, InitialDealPublicInputs calldata inputs) external view returns (bool);

    function verifyPeek(bytes calldata proof, PeekPublicInputs calldata inputs) external view returns (bool);

    function verifyAction(bytes calldata proof, ActionPublicInputs calldata inputs) external view returns (bool);

    function verifyShowdown(bytes calldata proof, ShowdownPublicInputs calldata inputs) external view returns (bool);
}
