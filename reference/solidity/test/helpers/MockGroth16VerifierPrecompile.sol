// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract MockGroth16VerifierPrecompile {
    uint32 internal constant STATUS_VALID = 0;
    uint32 internal constant STATUS_INVALID_PROOF = 1;
    uint32 internal constant STATUS_UNKNOWN_VK = 2;
    uint32 internal constant STATUS_VK_INACTIVE = 3;
    uint32 internal constant STATUS_BAD_SIGNAL_LENGTH = 4;
    uint32 internal constant STATUS_INVALID_FIELD_ELEMENT = 5;

    struct ExpectedCall {
        bool enabled;
        bytes32 vkHash;
        uint256[8] proof;
        uint256[] publicSignals;
    }

    mapping(bytes32 => address) public verifiers;
    mapping(bytes32 => bool) public forcedStatusSet;
    mapping(bytes32 => uint32) public forcedStatus;
    mapping(bytes32 => bool) public forcedValid;

    ExpectedCall private expectedCall;

    function setVerifier(bytes32 vkHash, address verifier) external {
        verifiers[vkHash] = verifier;
    }

    function setForcedStatus(bytes32 vkHash, uint32 status) external {
        forcedStatusSet[vkHash] = true;
        forcedStatus[vkHash] = status;
        forcedValid[vkHash] = status == STATUS_VALID;
    }

    function setForcedResponse(bytes32 vkHash, uint32 status, bool valid) external {
        forcedStatusSet[vkHash] = true;
        forcedStatus[vkHash] = status;
        forcedValid[vkHash] = valid;
    }

    function clearForcedStatus(bytes32 vkHash) external {
        forcedStatusSet[vkHash] = false;
        delete forcedStatus[vkHash];
        delete forcedValid[vkHash];
    }

    function setExpectedCall(bytes32 vkHash, uint256[8] calldata proof, uint256[] calldata publicSignals) external {
        expectedCall.enabled = true;
        expectedCall.vkHash = vkHash;
        expectedCall.proof = proof;
        expectedCall.publicSignals = publicSignals;
    }

    function clearExpectedCall() external {
        delete expectedCall;
    }

    function verifyGroth16(bytes32 vkHash, uint256[8] calldata proof, uint256[] calldata publicSignals)
        external
        view
        returns (uint32 status, bool valid)
    {
        if (forcedStatusSet[vkHash]) {
            status = forcedStatus[vkHash];
            return (status, forcedValid[vkHash]);
        }

        if (expectedCall.enabled) {
            if (!_matchesExpected(vkHash, proof, publicSignals)) {
                return (STATUS_BAD_SIGNAL_LENGTH, false);
            }
            return (STATUS_VALID, true);
        }

        address verifier = verifiers[vkHash];
        if (verifier == address(0)) {
            return (STATUS_UNKNOWN_VK, false);
        }

        if (!_allFieldElements(proof, publicSignals)) {
            return (STATUS_INVALID_FIELD_ELEMENT, false);
        }

        bool success = _verifyWithFallbackVerifier(verifier, proof, publicSignals);
        return (success ? STATUS_VALID : STATUS_INVALID_PROOF, success);
    }

    function _matchesExpected(bytes32 vkHash, uint256[8] calldata proof, uint256[] calldata publicSignals)
        internal
        view
        returns (bool)
    {
        if (vkHash != expectedCall.vkHash || publicSignals.length != expectedCall.publicSignals.length) {
            return false;
        }
        for (uint256 i = 0; i < proof.length; i++) {
            if (proof[i] != expectedCall.proof[i]) {
                return false;
            }
        }
        for (uint256 i = 0; i < publicSignals.length; i++) {
            if (publicSignals[i] != expectedCall.publicSignals[i]) {
                return false;
            }
        }
        return true;
    }

    function _allFieldElements(uint256[8] calldata proof, uint256[] calldata publicSignals)
        internal
        pure
        returns (bool)
    {
        uint256 r = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        for (uint256 i = 0; i < proof.length; i++) {
            if (proof[i] >= r) {
                return false;
            }
        }
        for (uint256 i = 0; i < publicSignals.length; i++) {
            if (publicSignals[i] >= r) {
                return false;
            }
        }
        return true;
    }

    function _verifyWithFallbackVerifier(address verifier, uint256[8] calldata proof, uint256[] calldata publicSignals)
        internal
        view
        returns (bool)
    {
        uint256[2] memory a = [proof[0], proof[1]];
        uint256[2][2] memory b = [[proof[2], proof[3]], [proof[4], proof[5]]];
        uint256[2] memory c = [proof[6], proof[7]];

        if (publicSignals.length == 7) {
            uint256[7] memory signals7;
            for (uint256 i = 0; i < 7; i++) {
                signals7[i] = publicSignals[i];
            }
            return _callVerifier7(verifier, a, b, c, signals7);
        }
        if (publicSignals.length == 10) {
            uint256[10] memory signals10;
            for (uint256 i = 0; i < 10; i++) {
                signals10[i] = publicSignals[i];
            }
            return _callVerifier10(verifier, a, b, c, signals10);
        }
        if (publicSignals.length == 11) {
            uint256[11] memory signals11;
            for (uint256 i = 0; i < 11; i++) {
                signals11[i] = publicSignals[i];
            }
            return _callVerifier11(verifier, a, b, c, signals11);
        }
        if (publicSignals.length == 12) {
            uint256[12] memory signals12;
            for (uint256 i = 0; i < 12; i++) {
                signals12[i] = publicSignals[i];
            }
            return _callVerifier12(verifier, a, b, c, signals12);
        }
        if (publicSignals.length == 26) {
            uint256[26] memory signals26;
            for (uint256 i = 0; i < 26; i++) {
                signals26[i] = publicSignals[i];
            }
            return _callVerifier26(verifier, a, b, c, signals26);
        }

        return false;
    }

    function _callVerifier7(
        address verifier,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[7] memory signals
    ) internal view returns (bool) {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[7])", a, b, c, signals)
        );
        return success && abi.decode(data, (bool));
    }

    function _callVerifier10(
        address verifier,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[10] memory signals
    ) internal view returns (bool) {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[10])", a, b, c, signals)
        );
        return success && abi.decode(data, (bool));
    }

    function _callVerifier11(
        address verifier,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[11] memory signals
    ) internal view returns (bool) {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[11])", a, b, c, signals)
        );
        return success && abi.decode(data, (bool));
    }

    function _callVerifier12(
        address verifier,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[12] memory signals
    ) internal view returns (bool) {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[12])", a, b, c, signals)
        );
        return success && abi.decode(data, (bool));
    }

    function _callVerifier26(
        address verifier,
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[26] memory signals
    ) internal view returns (bool) {
        (bool success, bytes memory data) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(uint256[2],uint256[2][2],uint256[2],uint256[26])", a, b, c, signals)
        );
        return success && abi.decode(data, (bool));
    }
}
