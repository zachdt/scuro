// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract ScuroVerifierRegistry is AccessControl {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    string internal constant HASH_DOMAIN = "SCURO_GROTH16_BN254_V1";

    struct VerificationKey {
        uint16 publicSignalCount;
        uint256 alphaX;
        uint256 alphaY;
        uint256 betaX1;
        uint256 betaX2;
        uint256 betaY1;
        uint256 betaY2;
        uint256 gammaX1;
        uint256 gammaX2;
        uint256 gammaY1;
        uint256 gammaY2;
        uint256 deltaX1;
        uint256 deltaX2;
        uint256 deltaY1;
        uint256 deltaY2;
        uint256[] ic;
    }

    struct StoredVerificationKey {
        bool active;
        uint16 publicSignalCount;
        uint16 icPointCount;
        uint64 verifyGas;
        uint256 alphaX;
        uint256 alphaY;
        uint256 betaX1;
        uint256 betaX2;
        uint256 betaY1;
        uint256 betaY2;
        uint256 gammaX1;
        uint256 gammaX2;
        uint256 gammaY1;
        uint256 gammaY2;
        uint256 deltaX1;
        uint256 deltaX2;
        uint256 deltaY1;
        uint256 deltaY2;
        uint256[] ic;
    }

    mapping(bytes32 => StoredVerificationKey) private verificationKeys;

    event VerificationKeyUpserted(
        bytes32 indexed vkHash, uint16 publicSignalCount, uint16 icPointCount, uint64 verifyGas, bool active
    );
    event VerificationKeyActiveSet(bytes32 indexed vkHash, bool active);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REGISTRAR_ROLE, admin);
    }

    function upsertVerificationKey(VerificationKey calldata vk, uint64 verifyGas)
        external
        onlyRole(REGISTRAR_ROLE)
        returns (bytes32 vkHash)
    {
        _validateVerificationKey(vk, verifyGas);
        vkHash = computeVkHash(vk);

        StoredVerificationKey storage stored = verificationKeys[vkHash];
        stored.active = true;
        stored.publicSignalCount = vk.publicSignalCount;
        stored.icPointCount = uint16(vk.ic.length / 2);
        stored.verifyGas = verifyGas;
        stored.alphaX = vk.alphaX;
        stored.alphaY = vk.alphaY;
        stored.betaX1 = vk.betaX1;
        stored.betaX2 = vk.betaX2;
        stored.betaY1 = vk.betaY1;
        stored.betaY2 = vk.betaY2;
        stored.gammaX1 = vk.gammaX1;
        stored.gammaX2 = vk.gammaX2;
        stored.gammaY1 = vk.gammaY1;
        stored.gammaY2 = vk.gammaY2;
        stored.deltaX1 = vk.deltaX1;
        stored.deltaX2 = vk.deltaX2;
        stored.deltaY1 = vk.deltaY1;
        stored.deltaY2 = vk.deltaY2;
        stored.ic = vk.ic;

        emit VerificationKeyUpserted(vkHash, stored.publicSignalCount, stored.icPointCount, verifyGas, true);
    }

    function setVerificationKeyActive(bytes32 vkHash, bool active) external onlyRole(REGISTRAR_ROLE) {
        StoredVerificationKey storage stored = verificationKeys[vkHash];
        require(stored.icPointCount != 0, "VerifierRegistry: unknown key");
        stored.active = active;
        emit VerificationKeyActiveSet(vkHash, active);
    }

    function getVerificationKeyMeta(bytes32 vkHash)
        external
        view
        returns (bool active, uint16 publicSignalCount, uint16 icPointCount, uint64 verifyGas)
    {
        StoredVerificationKey storage stored = verificationKeys[vkHash];
        require(stored.icPointCount != 0, "VerifierRegistry: unknown key");
        return (stored.active, stored.publicSignalCount, stored.icPointCount, stored.verifyGas);
    }

    function computeVkHash(VerificationKey calldata vk) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                HASH_DOMAIN,
                uint256(vk.publicSignalCount),
                vk.alphaX,
                vk.alphaY,
                vk.betaX1,
                vk.betaX2,
                vk.betaY1,
                vk.betaY2,
                vk.gammaX1,
                vk.gammaX2,
                vk.gammaY1,
                vk.gammaY2,
                vk.deltaX1,
                vk.deltaX2,
                vk.deltaY1,
                vk.deltaY2,
                vk.ic
            )
        );
    }

    function _validateVerificationKey(VerificationKey calldata vk, uint64 verifyGas) internal pure {
        require(vk.publicSignalCount > 0, "VerifierRegistry: zero signals");
        require(verifyGas > 0, "VerifierRegistry: zero gas");
        require(vk.ic.length > 0 && vk.ic.length % 2 == 0, "VerifierRegistry: invalid ic");
        require(vk.ic.length == (uint256(vk.publicSignalCount) + 1) * 2, "VerifierRegistry: ic mismatch");
    }
}
