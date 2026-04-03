// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Groth16ProofCodec} from "../libraries/Groth16ProofCodec.sol";
import {IBlackjackVerifierBundle} from "../interfaces/IBlackjackVerifierBundle.sol";

/// @title Blackjack verifier bundle
/// @notice Decodes blackjack proof blobs and dispatches them to the generated verifier contracts.
contract BlackjackVerifierBundle is AccessControl, IBlackjackVerifierBundle {
    using Groth16ProofCodec for bytes;

    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");
    uint256 internal constant MAX_PLAYER_CARDS = 32;
    uint256 internal constant MAX_DEALER_CARDS = 12;

    address public initialDealVerifier;
    address public peekVerifier;
    address public actionVerifier;
    address public showdownVerifier;

    constructor(
        address admin,
        address initialDealVerifierAddress,
        address peekVerifierAddress,
        address actionVerifierAddress,
        address showdownVerifierAddress
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);
        initialDealVerifier = initialDealVerifierAddress;
        peekVerifier = peekVerifierAddress;
        actionVerifier = actionVerifierAddress;
        showdownVerifier = showdownVerifierAddress;
    }

    function setVerifiers(
        address initialDealVerifierAddress,
        address peekVerifierAddress,
        address actionVerifierAddress,
        address showdownVerifierAddress
    ) external onlyRole(CONFIG_ROLE) {
        initialDealVerifier = initialDealVerifierAddress;
        peekVerifier = peekVerifierAddress;
        actionVerifier = actionVerifierAddress;
        showdownVerifier = showdownVerifierAddress;
    }

    function verifyInitialDeal(bytes calldata proofData, InitialDealPublicInputs calldata inputs)
        external
        view
        override
        returns (bool)
    {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[97] memory signals = _initialSignals(inputs);
        return _verify97(initialDealVerifier, proof, signals);
    }

    function verifyPeek(bytes calldata proofData, PeekPublicInputs calldata inputs)
        external
        view
        override
        returns (bool)
    {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[97] memory signals = _peekSignals(inputs);
        return _verify97(peekVerifier, proof, signals);
    }

    function verifyAction(bytes calldata proofData, ActionPublicInputs calldata inputs)
        external
        view
        override
        returns (bool)
    {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[99] memory signals = _actionSignals(inputs);
        return _verify99(actionVerifier, proof, signals);
    }

    function verifyShowdown(bytes calldata proofData, ShowdownPublicInputs calldata inputs)
        external
        view
        override
        returns (bool)
    {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[95] memory signals = _showdownSignals(inputs);
        return _verify95(showdownVerifier, proof, signals);
    }

    function _initialSignals(InitialDealPublicInputs calldata inputs) internal pure returns (uint256[97] memory signals) {
        uint256 index;
        signals[index++] = inputs.sessionId;
        signals[index++] = inputs.handNonce;
        signals[index++] = inputs.deckCommitment;
        signals[index++] = inputs.playerStateCommitment;
        signals[index++] = inputs.dealerStateCommitment;
        signals[index++] = inputs.playerKeyCommitment;
        signals[index++] = inputs.playerCiphertextRef;
        signals[index++] = inputs.dealerCiphertextRef;
        index = _writeSharedScalars(
            signals,
            index,
            inputs.phase,
            inputs.decisionType,
            inputs.dealerUpValue,
            inputs.dealerFinalValue,
            inputs.payout,
            inputs.insuranceStake,
            inputs.insurancePayout,
            inputs.dealerRevealMask,
            inputs.handCount,
            inputs.activeHandIndex,
            inputs.peekAvailable,
            inputs.peekResolved,
            inputs.dealerHasBlackjack,
            inputs.insuranceAvailable,
            inputs.insuranceStatus,
            inputs.surrenderAvailable,
            inputs.surrenderStatus
        );
        _writeSharedArrays(
            signals,
            index,
            inputs.handWagers,
            inputs.handValues,
            inputs.handStatuses,
            inputs.allowedActionMasks,
            inputs.handCardCounts,
            inputs.handCardStartIndices,
            inputs.handPayoutKinds,
            inputs.playerCards,
            inputs.dealerCards
        );
    }

    function _peekSignals(PeekPublicInputs calldata inputs) internal pure returns (uint256[97] memory signals) {
        uint256 index;
        signals[index++] = inputs.sessionId;
        signals[index++] = inputs.proofSequence;
        signals[index++] = inputs.deckCommitment;
        signals[index++] = inputs.playerStateCommitment;
        signals[index++] = inputs.dealerStateCommitment;
        signals[index++] = inputs.playerKeyCommitment;
        signals[index++] = inputs.playerCiphertextRef;
        signals[index++] = inputs.dealerCiphertextRef;
        index = _writeSharedScalars(
            signals,
            index,
            inputs.phase,
            inputs.decisionType,
            inputs.dealerUpValue,
            inputs.dealerFinalValue,
            inputs.payout,
            inputs.insuranceStake,
            inputs.insurancePayout,
            inputs.dealerRevealMask,
            inputs.handCount,
            inputs.activeHandIndex,
            inputs.peekAvailable,
            inputs.peekResolved,
            inputs.dealerHasBlackjack,
            inputs.insuranceAvailable,
            inputs.insuranceStatus,
            inputs.surrenderAvailable,
            inputs.surrenderStatus
        );
        _writeSharedArrays(
            signals,
            index,
            inputs.handWagers,
            inputs.handValues,
            inputs.handStatuses,
            inputs.allowedActionMasks,
            inputs.handCardCounts,
            inputs.handCardStartIndices,
            inputs.handPayoutKinds,
            inputs.playerCards,
            inputs.dealerCards
        );
    }

    function _actionSignals(ActionPublicInputs calldata inputs) internal pure returns (uint256[99] memory signals) {
        uint256 index;
        signals[index++] = inputs.sessionId;
        signals[index++] = inputs.proofSequence;
        signals[index++] = inputs.pendingAction;
        signals[index++] = inputs.deckCommitment;
        signals[index++] = inputs.oldPlayerStateCommitment;
        signals[index++] = inputs.newPlayerStateCommitment;
        signals[index++] = inputs.dealerStateCommitment;
        signals[index++] = inputs.playerKeyCommitment;
        signals[index++] = inputs.playerCiphertextRef;
        signals[index++] = inputs.dealerCiphertextRef;
        index = _writeSharedScalars(
            signals,
            index,
            inputs.phase,
            inputs.decisionType,
            inputs.dealerUpValue,
            inputs.dealerFinalValue,
            inputs.payout,
            inputs.insuranceStake,
            inputs.insurancePayout,
            inputs.dealerRevealMask,
            inputs.handCount,
            inputs.activeHandIndex,
            inputs.peekAvailable,
            inputs.peekResolved,
            inputs.dealerHasBlackjack,
            inputs.insuranceAvailable,
            inputs.insuranceStatus,
            inputs.surrenderAvailable,
            inputs.surrenderStatus
        );
        _writeSharedArrays(
            signals,
            index,
            inputs.handWagers,
            inputs.handValues,
            inputs.handStatuses,
            inputs.allowedActionMasks,
            inputs.handCardCounts,
            inputs.handCardStartIndices,
            inputs.handPayoutKinds,
            inputs.playerCards,
            inputs.dealerCards
        );
    }

    function _showdownSignals(ShowdownPublicInputs calldata inputs) internal pure returns (uint256[95] memory signals) {
        uint256 index;
        signals[index++] = inputs.sessionId;
        signals[index++] = inputs.proofSequence;
        signals[index++] = inputs.deckCommitment;
        signals[index++] = inputs.playerStateCommitment;
        signals[index++] = inputs.dealerStateCommitment;
        signals[index++] = inputs.playerKeyCommitment;
        index = _writeSharedScalars(
            signals,
            index,
            inputs.phase,
            inputs.decisionType,
            inputs.dealerUpValue,
            inputs.dealerFinalValue,
            inputs.payout,
            inputs.insuranceStake,
            inputs.insurancePayout,
            inputs.dealerRevealMask,
            inputs.handCount,
            inputs.activeHandIndex,
            inputs.peekAvailable,
            inputs.peekResolved,
            inputs.dealerHasBlackjack,
            inputs.insuranceAvailable,
            inputs.insuranceStatus,
            inputs.surrenderAvailable,
            inputs.surrenderStatus
        );
        _writeSharedArrays(
            signals,
            index,
            inputs.handWagers,
            inputs.handValues,
            inputs.handStatuses,
            inputs.allowedActionMasks,
            inputs.handCardCounts,
            inputs.handCardStartIndices,
            inputs.handPayoutKinds,
            inputs.playerCards,
            inputs.dealerCards
        );
    }

    function _writeSharedScalars(
        uint256[97] memory signals,
        uint256 index,
        uint256 phase,
        uint256 decisionType,
        uint256 dealerUpValue,
        uint256 dealerFinalValue,
        uint256 payout,
        uint256 insuranceStake,
        uint256 insurancePayout,
        uint256 dealerRevealMask,
        uint256 handCount,
        uint256 activeHandIndex,
        uint256 peekAvailable,
        uint256 peekResolved,
        uint256 dealerHasBlackjack,
        uint256 insuranceAvailable,
        uint256 insuranceStatus,
        uint256 surrenderAvailable,
        uint256 surrenderStatus
    ) internal pure returns (uint256) {
        signals[index++] = phase;
        signals[index++] = decisionType;
        signals[index++] = dealerUpValue;
        signals[index++] = dealerFinalValue;
        signals[index++] = payout;
        signals[index++] = insuranceStake;
        signals[index++] = insurancePayout;
        signals[index++] = dealerRevealMask;
        signals[index++] = handCount;
        signals[index++] = activeHandIndex;
        signals[index++] = peekAvailable;
        signals[index++] = peekResolved;
        signals[index++] = dealerHasBlackjack;
        signals[index++] = insuranceAvailable;
        signals[index++] = insuranceStatus;
        signals[index++] = surrenderAvailable;
        signals[index++] = surrenderStatus;
        return index;
    }

    function _writeSharedScalars(
        uint256[99] memory signals,
        uint256 index,
        uint256 phase,
        uint256 decisionType,
        uint256 dealerUpValue,
        uint256 dealerFinalValue,
        uint256 payout,
        uint256 insuranceStake,
        uint256 insurancePayout,
        uint256 dealerRevealMask,
        uint256 handCount,
        uint256 activeHandIndex,
        uint256 peekAvailable,
        uint256 peekResolved,
        uint256 dealerHasBlackjack,
        uint256 insuranceAvailable,
        uint256 insuranceStatus,
        uint256 surrenderAvailable,
        uint256 surrenderStatus
    ) internal pure returns (uint256) {
        signals[index++] = phase;
        signals[index++] = decisionType;
        signals[index++] = dealerUpValue;
        signals[index++] = dealerFinalValue;
        signals[index++] = payout;
        signals[index++] = insuranceStake;
        signals[index++] = insurancePayout;
        signals[index++] = dealerRevealMask;
        signals[index++] = handCount;
        signals[index++] = activeHandIndex;
        signals[index++] = peekAvailable;
        signals[index++] = peekResolved;
        signals[index++] = dealerHasBlackjack;
        signals[index++] = insuranceAvailable;
        signals[index++] = insuranceStatus;
        signals[index++] = surrenderAvailable;
        signals[index++] = surrenderStatus;
        return index;
    }

    function _writeSharedScalars(
        uint256[95] memory signals,
        uint256 index,
        uint256 phase,
        uint256 decisionType,
        uint256 dealerUpValue,
        uint256 dealerFinalValue,
        uint256 payout,
        uint256 insuranceStake,
        uint256 insurancePayout,
        uint256 dealerRevealMask,
        uint256 handCount,
        uint256 activeHandIndex,
        uint256 peekAvailable,
        uint256 peekResolved,
        uint256 dealerHasBlackjack,
        uint256 insuranceAvailable,
        uint256 insuranceStatus,
        uint256 surrenderAvailable,
        uint256 surrenderStatus
    ) internal pure returns (uint256) {
        signals[index++] = phase;
        signals[index++] = decisionType;
        signals[index++] = dealerUpValue;
        signals[index++] = dealerFinalValue;
        signals[index++] = payout;
        signals[index++] = insuranceStake;
        signals[index++] = insurancePayout;
        signals[index++] = dealerRevealMask;
        signals[index++] = handCount;
        signals[index++] = activeHandIndex;
        signals[index++] = peekAvailable;
        signals[index++] = peekResolved;
        signals[index++] = dealerHasBlackjack;
        signals[index++] = insuranceAvailable;
        signals[index++] = insuranceStatus;
        signals[index++] = surrenderAvailable;
        signals[index++] = surrenderStatus;
        return index;
    }

    function _writeSharedArrays(
        uint256[97] memory signals,
        uint256 index,
        uint256[4] calldata handWagers,
        uint256[4] calldata handValues,
        uint256[4] calldata handStatuses,
        uint256[4] calldata allowedActionMasks,
        uint256[4] calldata handCardCounts,
        uint256[4] calldata handCardStartIndices,
        uint256[4] calldata handPayoutKinds,
        uint256[MAX_PLAYER_CARDS] calldata playerCards,
        uint256[MAX_DEALER_CARDS] calldata dealerCards
    ) internal pure {
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handWagers[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handValues[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handStatuses[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = allowedActionMasks[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handCardCounts[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handCardStartIndices[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handPayoutKinds[i];
        }
        for (uint256 i = 0; i < MAX_PLAYER_CARDS; i++) {
            signals[index++] = playerCards[i];
        }
        for (uint256 i = 0; i < MAX_DEALER_CARDS; i++) {
            signals[index++] = dealerCards[i];
        }
    }

    function _writeSharedArrays(
        uint256[99] memory signals,
        uint256 index,
        uint256[4] calldata handWagers,
        uint256[4] calldata handValues,
        uint256[4] calldata handStatuses,
        uint256[4] calldata allowedActionMasks,
        uint256[4] calldata handCardCounts,
        uint256[4] calldata handCardStartIndices,
        uint256[4] calldata handPayoutKinds,
        uint256[MAX_PLAYER_CARDS] calldata playerCards,
        uint256[MAX_DEALER_CARDS] calldata dealerCards
    ) internal pure {
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handWagers[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handValues[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handStatuses[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = allowedActionMasks[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handCardCounts[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handCardStartIndices[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handPayoutKinds[i];
        }
        for (uint256 i = 0; i < MAX_PLAYER_CARDS; i++) {
            signals[index++] = playerCards[i];
        }
        for (uint256 i = 0; i < MAX_DEALER_CARDS; i++) {
            signals[index++] = dealerCards[i];
        }
    }

    function _writeSharedArrays(
        uint256[95] memory signals,
        uint256 index,
        uint256[4] calldata handWagers,
        uint256[4] calldata handValues,
        uint256[4] calldata handStatuses,
        uint256[4] calldata allowedActionMasks,
        uint256[4] calldata handCardCounts,
        uint256[4] calldata handCardStartIndices,
        uint256[4] calldata handPayoutKinds,
        uint256[MAX_PLAYER_CARDS] calldata playerCards,
        uint256[MAX_DEALER_CARDS] calldata dealerCards
    ) internal pure {
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handWagers[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handValues[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handStatuses[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = allowedActionMasks[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handCardCounts[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handCardStartIndices[i];
        }
        for (uint256 i = 0; i < 4; i++) {
            signals[index++] = handPayoutKinds[i];
        }
        for (uint256 i = 0; i < MAX_PLAYER_CARDS; i++) {
            signals[index++] = playerCards[i];
        }
        for (uint256 i = 0; i < MAX_DEALER_CARDS; i++) {
            signals[index++] = dealerCards[i];
        }
    }

    function _verify97(address verifier, Groth16ProofCodec.Groth16Proof memory proof, uint256[97] memory signals)
        internal
        view
        returns (bool)
    {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[97])", proof.a, proof.b, proof.c, signals)
        );
        return success && abi.decode(data, (bool));
    }

    function _verify99(address verifier, Groth16ProofCodec.Groth16Proof memory proof, uint256[99] memory signals)
        internal
        view
        returns (bool)
    {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[99])", proof.a, proof.b, proof.c, signals)
        );
        return success && abi.decode(data, (bool));
    }

    function _verify95(address verifier, Groth16ProofCodec.Groth16Proof memory proof, uint256[95] memory signals)
        internal
        view
        returns (bool)
    {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[95])", proof.a, proof.b, proof.c, signals)
        );
        return success && abi.decode(data, (bool));
    }
}
