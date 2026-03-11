// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import { IBlackjackVerifierBundle } from "../interfaces/IBlackjackVerifierBundle.sol";
import { Groth16ProofCodec } from "../libraries/Groth16ProofCodec.sol";
import { ScuroGroth16VerifierPrecompile } from "../libraries/ScuroGroth16VerifierPrecompile.sol";

contract BlackjackVerifierBundle is AccessControl, IBlackjackVerifierBundle {
    using Groth16ProofCodec for bytes;

    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    bytes32 public initialDealVkHash;
    bytes32 public actionVkHash;
    bytes32 public showdownVkHash;
    address public initialDealVerifier;
    address public actionVerifier;
    address public showdownVerifier;

    constructor(
        address admin,
        bytes32 initialDealVkHash_,
        bytes32 actionVkHash_,
        bytes32 showdownVkHash_,
        address initialDealVerifierAddress,
        address actionVerifierAddress,
        address showdownVerifierAddress
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);
        initialDealVkHash = initialDealVkHash_;
        actionVkHash = actionVkHash_;
        showdownVkHash = showdownVkHash_;
        initialDealVerifier = initialDealVerifierAddress;
        actionVerifier = actionVerifierAddress;
        showdownVerifier = showdownVerifierAddress;
    }

    function setVkHashes(bytes32 initialDealVkHash_, bytes32 actionVkHash_, bytes32 showdownVkHash_)
        external
        onlyRole(CONFIG_ROLE)
    {
        initialDealVkHash = initialDealVkHash_;
        actionVkHash = actionVkHash_;
        showdownVkHash = showdownVkHash_;
    }

    function setVerifiers(
        address initialDealVerifierAddress,
        address actionVerifierAddress,
        address showdownVerifierAddress
    ) external onlyRole(CONFIG_ROLE) {
        initialDealVerifier = initialDealVerifierAddress;
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
        uint256[26] memory signals = [
            inputs.sessionId,
            inputs.handNonce,
            inputs.deckCommitment,
            inputs.playerStateCommitment,
            inputs.dealerStateCommitment,
            inputs.playerKeyCommitment,
            inputs.playerCiphertextRef,
            inputs.dealerCiphertextRef,
            inputs.dealerUpValue,
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
            inputs.allowedActionMasks[3]
        ];
        return _verify26(initialDealVkHash, initialDealVerifier, proof, signals);
    }

    function verifyAction(bytes calldata proofData, ActionPublicInputs calldata inputs)
        external
        view
        override
        returns (bool)
    {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[26] memory signals = [
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
            inputs.allowedActionMasks[3]
        ];
        return _verify26(actionVkHash, actionVerifier, proof, signals);
    }

    function verifyShowdown(bytes calldata proofData, ShowdownPublicInputs calldata inputs)
        external
        view
        override
        returns (bool)
    {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[12] memory signals = [
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
            inputs.handStatuses[3]
        ];
        return _verify12(showdownVkHash, showdownVerifier, proof, signals);
    }

    function _verify26(
        bytes32 vkHash,
        address verifier,
        Groth16ProofCodec.Groth16Proof memory proof,
        uint256[26] memory signals
    ) internal view returns (bool) {
        uint256[] memory dynamicSignals = _toDynamic(signals);
        (bool handled, bool valid) = ScuroGroth16VerifierPrecompile.verifyWithFallback(vkHash, proof, dynamicSignals);
        if (handled) {
            return valid;
        }
        if (verifier == address(0)) {
            return false;
        }
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature(
                "verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[26])", proof.a, proof.b, proof.c, signals
            )
        );
        return success && abi.decode(data, (bool));
    }

    function _verify12(
        bytes32 vkHash,
        address verifier,
        Groth16ProofCodec.Groth16Proof memory proof,
        uint256[12] memory signals
    ) internal view returns (bool) {
        uint256[] memory dynamicSignals = _toDynamic(signals);
        (bool handled, bool valid) = ScuroGroth16VerifierPrecompile.verifyWithFallback(vkHash, proof, dynamicSignals);
        if (handled) {
            return valid;
        }
        if (verifier == address(0)) {
            return false;
        }
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature(
                "verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[12])", proof.a, proof.b, proof.c, signals
            )
        );
        return success && abi.decode(data, (bool));
    }

    function _toDynamic(uint256[26] memory signals) private pure returns (uint256[] memory out) {
        out = new uint256[](26);
        for (uint256 i = 0; i < 26; i++) {
            out[i] = signals[i];
        }
    }

    function _toDynamic(uint256[12] memory signals) private pure returns (uint256[] memory out) {
        out = new uint256[](12);
        for (uint256 i = 0; i < 12; i++) {
            out[i] = signals[i];
        }
    }
}
