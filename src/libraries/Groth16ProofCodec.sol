// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

library Groth16ProofCodec {
    struct Groth16Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    function decode(bytes calldata proofData) internal pure returns (Groth16Proof memory proof) {
        return abi.decode(proofData, (Groth16Proof));
    }
}
