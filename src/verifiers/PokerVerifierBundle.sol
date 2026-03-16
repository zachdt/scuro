// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IPokerVerifierBundle} from "../interfaces/IPokerVerifierBundle.sol";
import {Groth16ProofCodec} from "../libraries/Groth16ProofCodec.sol";

/// @title Poker verifier bundle
/// @notice Decodes poker proof blobs and dispatches them to generated verifier contracts.
contract PokerVerifierBundle is AccessControl, IPokerVerifierBundle {
    using Groth16ProofCodec for bytes;

    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    address public initialDealVerifier;
    address public drawVerifier;
    address public showdownVerifier;

    /// @notice Initializes the bundle and grants verifier-config rights to the admin.
    constructor(address admin, address initialDealVerifierAddress, address drawVerifierAddress, address showdownVerifierAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);
        initialDealVerifier = initialDealVerifierAddress;
        drawVerifier = drawVerifierAddress;
        showdownVerifier = showdownVerifierAddress;
    }

    /// @notice Rotates the generated verifier contract addresses used by the bundle.
    function setVerifiers(address initialDealVerifierAddress, address drawVerifierAddress, address showdownVerifierAddress)
        external
        onlyRole(CONFIG_ROLE)
    {
        initialDealVerifier = initialDealVerifierAddress;
        drawVerifier = drawVerifierAddress;
        showdownVerifier = showdownVerifierAddress;
    }

    /// @notice Verifies a poker initial-deal proof.
    function verifyInitialDeal(bytes calldata proofData, InitialDealPublicInputs calldata inputs)
        external
        view
        override
        returns (bool)
    {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[10] memory signals = [
            inputs.gameId,
            inputs.handNumber,
            inputs.handNonce,
            inputs.deckCommitment,
            inputs.handCommitments[0],
            inputs.handCommitments[1],
            inputs.encryptionKeyCommitments[0],
            inputs.encryptionKeyCommitments[1],
            inputs.ciphertextRefs[0],
            inputs.ciphertextRefs[1]
        ];
        return _verify10(initialDealVerifier, proof, signals);
    }

    /// @notice Verifies a poker draw-resolution proof.
    function verifyDraw(bytes calldata proofData, DrawPublicInputs calldata inputs) external view override returns (bool) {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[11] memory signals = [
            inputs.gameId,
            inputs.handNumber,
            inputs.handNonce,
            inputs.playerIndex,
            inputs.deckCommitment,
            inputs.oldCommitment,
            inputs.newCommitment,
            inputs.newEncryptionKeyCommitment,
            inputs.newCiphertextRef,
            inputs.discardMask,
            inputs.proofSequence
        ];
        return _verify11(drawVerifier, proof, signals);
    }

    /// @notice Verifies a poker showdown proof.
    function verifyShowdown(bytes calldata proofData, ShowdownPublicInputs calldata inputs)
        external
        view
        override
        returns (bool)
    {
        Groth16ProofCodec.Groth16Proof memory proof = proofData.decode();
        uint256[7] memory signals = [
            inputs.gameId,
            inputs.handNumber,
            inputs.handNonce,
            inputs.handCommitments[0],
            inputs.handCommitments[1],
            inputs.winnerIndex,
            inputs.isTie
        ];
        return _verify7(showdownVerifier, proof, signals);
    }

    function _verify10(address verifier, Groth16ProofCodec.Groth16Proof memory proof, uint256[10] memory signals)
        internal
        view
        returns (bool)
    {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[10])", proof.a, proof.b, proof.c, signals)
        );
        return success && abi.decode(data, (bool));
    }

    function _verify11(address verifier, Groth16ProofCodec.Groth16Proof memory proof, uint256[11] memory signals)
        internal
        view
        returns (bool)
    {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[11])", proof.a, proof.b, proof.c, signals)
        );
        return success && abi.decode(data, (bool));
    }

    function _verify7(address verifier, Groth16ProofCodec.Groth16Proof memory proof, uint256[7] memory signals)
        internal
        view
        returns (bool)
    {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[7])", proof.a, proof.b, proof.c, signals)
        );
        return success && abi.decode(data, (bool));
    }
}
