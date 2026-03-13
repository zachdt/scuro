// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Groth16ProofCodec } from "./Groth16ProofCodec.sol";

library ScuroGroth16VerifierPrecompile {
    error PrecompileVerificationError(bytes32 vkHash, uint32 status);

    address internal constant PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000800;
    address internal constant REGISTRY_ADDRESS = 0x0000000000000000000000000000000000000801;

    bytes4 internal constant VERIFY_GROTH16_SELECTOR = bytes4(keccak256("verifyGroth16(bytes32,uint256[8],uint256[])"));

    uint32 internal constant STATUS_VALID = 0;
    uint32 internal constant STATUS_INVALID_PROOF = 1;
    uint32 internal constant STATUS_UNKNOWN_VK = 2;
    uint32 internal constant STATUS_VK_INACTIVE = 3;
    uint32 internal constant STATUS_BAD_SIGNAL_LENGTH = 4;
    uint32 internal constant STATUS_INVALID_FIELD_ELEMENT = 5;
    uint32 internal constant STATUS_MALFORMED_CALLDATA = 6;
    uint32 internal constant STATUS_INTERNAL_ERROR = 7;
    uint32 internal constant STATUS_UNSUPPORTED_SELECTOR = 8;

    function flattenProof(Groth16ProofCodec.Groth16Proof memory proof) internal pure returns (uint256[8] memory flat) {
        flat[0] = proof.a[0];
        flat[1] = proof.a[1];
        flat[2] = proof.b[0][0];
        flat[3] = proof.b[0][1];
        flat[4] = proof.b[1][0];
        flat[5] = proof.b[1][1];
        flat[6] = proof.c[0];
        flat[7] = proof.c[1];
    }

    function verifyWithFallback(
        bytes32 vkHash,
        Groth16ProofCodec.Groth16Proof memory proof,
        uint256[] memory publicSignals
    ) internal view returns (bool handled, bool valid) {
        (bool success, bytes memory data) = PRECOMPILE_ADDRESS.staticcall(
            abi.encodeWithSelector(VERIFY_GROTH16_SELECTOR, vkHash, flattenProof(proof), publicSignals)
        );
        if (!success || data.length != 64) {
            return (false, false);
        }

        handled = true;
        (uint32 status,) = abi.decode(data, (uint32, bool));
        if (status == STATUS_VALID) {
            return (true, true);
        }
        if (status == STATUS_INVALID_PROOF) {
            return (true, false);
        }

        revert PrecompileVerificationError(vkHash, status);
    }
}
