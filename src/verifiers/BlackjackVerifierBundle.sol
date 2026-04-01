// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IBlackjackVerifierBundle} from "../interfaces/IBlackjackVerifierBundle.sol";
import {Groth16ProofCodec} from "../libraries/Groth16ProofCodec.sol";

/// @title Blackjack verifier bundle
/// @notice Decodes blackjack proof blobs and dispatches them to generated verifier contracts.
contract BlackjackVerifierBundle is AccessControl, IBlackjackVerifierBundle {
    using Groth16ProofCodec for bytes;

    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    address public initialDealVerifier;
    address public actionVerifier;
    address public showdownVerifier;

    /// @notice Initializes the bundle and grants verifier-config rights to the admin.
    constructor(address admin, address initialDealVerifierAddress, address actionVerifierAddress, address showdownVerifierAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);
        initialDealVerifier = initialDealVerifierAddress;
        actionVerifier = actionVerifierAddress;
        showdownVerifier = showdownVerifierAddress;
    }

    /// @notice Rotates the generated verifier contract addresses used by the bundle.
    function setVerifiers(address initialDealVerifierAddress, address actionVerifierAddress, address showdownVerifierAddress)
        external
        onlyRole(CONFIG_ROLE)
    {
        initialDealVerifier = initialDealVerifierAddress;
        actionVerifier = actionVerifierAddress;
        showdownVerifier = showdownVerifierAddress;
    }

    /// @notice Verifies a blackjack initial-deal proof.
    function verifyInitialDeal(bytes calldata proofData, InitialDealPublicInputs calldata inputs)
        external
        view
        override
        returns (bool)
    {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[48] memory signals = [
            inputs.sessionId,
            inputs.handNonce,
            inputs.deckCommitment,
            inputs.playerStateCommitment,
            inputs.dealerStateCommitment,
            inputs.playerKeyCommitment,
            inputs.playerCiphertextRef,
            inputs.dealerCiphertextRef,
            inputs.dealerUpValue,
            inputs.baseWager,
            inputs.handCount,
            inputs.activeHandIndex,
            inputs.payout,
            inputs.immediateResultCode,
            inputs.handValues[0],
            inputs.handValues[1],
            inputs.handValues[2],
            inputs.handValues[3],
            inputs.softMask,
            inputs.handStatuses[0],
            inputs.handStatuses[1],
            inputs.handStatuses[2],
            inputs.handStatuses[3],
            inputs.allowedActionMasks[0],
            inputs.allowedActionMasks[1],
            inputs.allowedActionMasks[2],
            inputs.allowedActionMasks[3],
            inputs.handCardCounts[0],
            inputs.handCardCounts[1],
            inputs.handCardCounts[2],
            inputs.handCardCounts[3],
            inputs.handPayoutKinds[0],
            inputs.handPayoutKinds[1],
            inputs.handPayoutKinds[2],
            inputs.handPayoutKinds[3],
            inputs.playerCards[0],
            inputs.playerCards[1],
            inputs.playerCards[2],
            inputs.playerCards[3],
            inputs.playerCards[4],
            inputs.playerCards[5],
            inputs.playerCards[6],
            inputs.playerCards[7],
            inputs.dealerCards[0],
            inputs.dealerCards[1],
            inputs.dealerCards[2],
            inputs.dealerCards[3],
            inputs.dealerRevealMask
        ];
        return _verify48(initialDealVerifier, proof, signals);
    }

    /// @notice Verifies a blackjack action-resolution proof.
    function verifyAction(bytes calldata proofData, ActionPublicInputs calldata inputs) external view override returns (bool) {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[47] memory signals = [
            inputs.sessionId,
            inputs.proofSequence,
            inputs.pendingAction,
            inputs.oldPlayerStateCommitment,
            inputs.newPlayerStateCommitment,
            inputs.dealerStateCommitment,
            inputs.playerKeyCommitment,
            inputs.playerCiphertextRef,
            inputs.dealerCiphertextRef,
            inputs.dealerUpValue,
            inputs.handCount,
            inputs.activeHandIndex,
            inputs.nextPhase,
            inputs.handValues[0],
            inputs.handValues[1],
            inputs.handValues[2],
            inputs.handValues[3],
            inputs.softMask,
            inputs.handStatuses[0],
            inputs.handStatuses[1],
            inputs.handStatuses[2],
            inputs.handStatuses[3],
            inputs.allowedActionMasks[0],
            inputs.allowedActionMasks[1],
            inputs.allowedActionMasks[2],
            inputs.allowedActionMasks[3],
            inputs.handCardCounts[0],
            inputs.handCardCounts[1],
            inputs.handCardCounts[2],
            inputs.handCardCounts[3],
            inputs.handPayoutKinds[0],
            inputs.handPayoutKinds[1],
            inputs.handPayoutKinds[2],
            inputs.handPayoutKinds[3],
            inputs.playerCards[0],
            inputs.playerCards[1],
            inputs.playerCards[2],
            inputs.playerCards[3],
            inputs.playerCards[4],
            inputs.playerCards[5],
            inputs.playerCards[6],
            inputs.playerCards[7],
            inputs.dealerCards[0],
            inputs.dealerCards[1],
            inputs.dealerCards[2],
            inputs.dealerCards[3],
            inputs.dealerRevealMask
        ];
        return _verify47(actionVerifier, proof, signals);
    }

    /// @notice Verifies a blackjack showdown proof.
    function verifyShowdown(bytes calldata proofData, ShowdownPublicInputs calldata inputs)
        external
        view
        override
        returns (bool)
    {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[41] memory signals = [
            inputs.sessionId,
            inputs.proofSequence,
            inputs.playerStateCommitment,
            inputs.dealerStateCommitment,
            inputs.payout,
            inputs.dealerFinalValue,
            inputs.handCount,
            inputs.activeHandIndex,
            inputs.handStatuses[0],
            inputs.handStatuses[1],
            inputs.handStatuses[2],
            inputs.handStatuses[3],
            inputs.handValues[0],
            inputs.handValues[1],
            inputs.handValues[2],
            inputs.handValues[3],
            inputs.handWagers[0],
            inputs.handWagers[1],
            inputs.handWagers[2],
            inputs.handWagers[3],
            inputs.handCardCounts[0],
            inputs.handCardCounts[1],
            inputs.handCardCounts[2],
            inputs.handCardCounts[3],
            inputs.handPayoutKinds[0],
            inputs.handPayoutKinds[1],
            inputs.handPayoutKinds[2],
            inputs.handPayoutKinds[3],
            inputs.playerCards[0],
            inputs.playerCards[1],
            inputs.playerCards[2],
            inputs.playerCards[3],
            inputs.playerCards[4],
            inputs.playerCards[5],
            inputs.playerCards[6],
            inputs.playerCards[7],
            inputs.dealerCards[0],
            inputs.dealerCards[1],
            inputs.dealerCards[2],
            inputs.dealerCards[3],
            inputs.dealerRevealMask
        ];
        return _verify41(showdownVerifier, proof, signals);
    }

    function _verify48(address verifier, Groth16ProofCodec.Groth16Proof memory proof, uint256[48] memory signals)
        internal
        view
        returns (bool)
    {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[48])", proof.a, proof.b, proof.c, signals)
        );
        return success && abi.decode(data, (bool));
    }

    function _verify47(address verifier, Groth16ProofCodec.Groth16Proof memory proof, uint256[47] memory signals)
        internal
        view
        returns (bool)
    {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[47])", proof.a, proof.b, proof.c, signals)
        );
        return success && abi.decode(data, (bool));
    }

    function _verify41(address verifier, Groth16ProofCodec.Groth16Proof memory proof, uint256[41] memory signals)
        internal
        view
        returns (bool)
    {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[41])", proof.a, proof.b, proof.c, signals)
        );
        return success && abi.decode(data, (bool));
    }
}
