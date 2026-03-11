// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { LaunchVerificationKeyHashes } from "../src/verifiers/LaunchVerificationKeyHashes.sol";
import { ScuroVerifierRegistry } from "../src/verifiers/ScuroVerifierRegistry.sol";

contract ScuroVerifierRegistryTest is Test {
    using stdJson for string;

    ScuroVerifierRegistry internal registry;

    function setUp() public {
        registry = new ScuroVerifierRegistry(address(this));
    }

    function test_UpsertStoresMetadataAndAllowsDeactivation() public {
        ScuroVerifierRegistry.VerificationKey memory vk = _sampleKey();
        bytes32 vkHash = registry.upsertVerificationKey(vk, 123_456);

        (bool active, uint16 publicSignalCount, uint16 icPointCount, uint64 verifyGas) =
            registry.getVerificationKeyMeta(vkHash);
        assertTrue(active);
        assertEq(publicSignalCount, 2);
        assertEq(icPointCount, 3);
        assertEq(verifyGas, 123_456);

        registry.setVerificationKeyActive(vkHash, false);
        (active, publicSignalCount, icPointCount, verifyGas) = registry.getVerificationKeyMeta(vkHash);
        assertFalse(active);
        assertEq(publicSignalCount, 2);
        assertEq(icPointCount, 3);
        assertEq(verifyGas, 123_456);
    }

    function test_UpsertRejectsInvalidIcLength() public {
        ScuroVerifierRegistry.VerificationKey memory vk = _sampleKey();
        vk.ic = new uint256[](5);

        vm.expectRevert("VerifierRegistry: invalid ic");
        registry.upsertVerificationKey(vk, 1);
    }

    function test_UpsertRejectsIcSignalMismatch() public {
        ScuroVerifierRegistry.VerificationKey memory vk = _sampleKey();
        vk.ic = new uint256[](8);

        vm.expectRevert("VerifierRegistry: ic mismatch");
        registry.upsertVerificationKey(vk, 1);
    }

    function test_ComputeVkHashMatchesLaunchArtifacts() public {
        _assertLaunchKey(
            "poker_initial_deal.vkey.json", LaunchVerificationKeyHashes.POKER_INITIAL_DEAL_VK_HASH, 10, 350_000
        );
        _assertLaunchKey("poker_draw_resolve.vkey.json", LaunchVerificationKeyHashes.POKER_DRAW_VK_HASH, 11, 355_000);
        _assertLaunchKey("poker_showdown.vkey.json", LaunchVerificationKeyHashes.POKER_SHOWDOWN_VK_HASH, 7, 335_000);
        _assertLaunchKey(
            "blackjack_initial_deal.vkey.json", LaunchVerificationKeyHashes.BLACKJACK_INITIAL_DEAL_VK_HASH, 26, 430_000
        );
        _assertLaunchKey(
            "blackjack_action_resolve.vkey.json", LaunchVerificationKeyHashes.BLACKJACK_ACTION_VK_HASH, 26, 430_000
        );
        _assertLaunchKey(
            "blackjack_showdown.vkey.json", LaunchVerificationKeyHashes.BLACKJACK_SHOWDOWN_VK_HASH, 12, 360_000
        );
    }

    function _sampleKey() private pure returns (ScuroVerifierRegistry.VerificationKey memory vk) {
        vk.publicSignalCount = 2;
        vk.alphaX = 1;
        vk.alphaY = 2;
        vk.betaX1 = 3;
        vk.betaX2 = 4;
        vk.betaY1 = 5;
        vk.betaY2 = 6;
        vk.gammaX1 = 7;
        vk.gammaX2 = 8;
        vk.gammaY1 = 9;
        vk.gammaY2 = 10;
        vk.deltaX1 = 11;
        vk.deltaX2 = 12;
        vk.deltaY1 = 13;
        vk.deltaY2 = 14;
        vk.ic = new uint256[](6);
        vk.ic[0] = 15;
        vk.ic[1] = 16;
        vk.ic[2] = 17;
        vk.ic[3] = 18;
        vk.ic[4] = 19;
        vk.ic[5] = 20;
    }

    function _assertLaunchKey(string memory fileName, bytes32 expectedHash, uint16 expectedSignals, uint64 verifyGas)
        private
    {
        ScuroVerifierRegistry.VerificationKey memory vk = _loadKey(fileName);
        assertEq(vk.publicSignalCount, expectedSignals);

        bytes32 computedHash = registry.computeVkHash(vk);
        assertEq(computedHash, expectedHash);

        bytes32 storedHash = registry.upsertVerificationKey(vk, verifyGas);
        assertEq(storedHash, expectedHash);

        (bool active, uint16 publicSignalCount, uint16 icPointCount, uint64 storedGas) =
            registry.getVerificationKeyMeta(storedHash);
        assertTrue(active);
        assertEq(publicSignalCount, expectedSignals);
        assertEq(icPointCount, expectedSignals + 1);
        assertEq(storedGas, verifyGas);
    }

    function _loadKey(string memory fileName) private view returns (ScuroVerifierRegistry.VerificationKey memory vk) {
        string memory json = vm.readFile(string.concat(vm.projectRoot(), "/zk/vkeys/", fileName));
        uint256 publicSignalCount = json.readUint(".nPublic");

        vk.publicSignalCount = uint16(publicSignalCount);
        vk.alphaX = _readStringUint(json, ".vk_alpha_1[0]");
        vk.alphaY = _readStringUint(json, ".vk_alpha_1[1]");
        vk.betaX1 = _readStringUint(json, ".vk_beta_2[0][1]");
        vk.betaX2 = _readStringUint(json, ".vk_beta_2[0][0]");
        vk.betaY1 = _readStringUint(json, ".vk_beta_2[1][1]");
        vk.betaY2 = _readStringUint(json, ".vk_beta_2[1][0]");
        vk.gammaX1 = _readStringUint(json, ".vk_gamma_2[0][1]");
        vk.gammaX2 = _readStringUint(json, ".vk_gamma_2[0][0]");
        vk.gammaY1 = _readStringUint(json, ".vk_gamma_2[1][1]");
        vk.gammaY2 = _readStringUint(json, ".vk_gamma_2[1][0]");
        vk.deltaX1 = _readStringUint(json, ".vk_delta_2[0][1]");
        vk.deltaX2 = _readStringUint(json, ".vk_delta_2[0][0]");
        vk.deltaY1 = _readStringUint(json, ".vk_delta_2[1][1]");
        vk.deltaY2 = _readStringUint(json, ".vk_delta_2[1][0]");

        uint256 icPointCount = publicSignalCount + 1;
        vk.ic = new uint256[](icPointCount * 2);
        for (uint256 i = 0; i < icPointCount; i++) {
            string memory index = vm.toString(i);
            vk.ic[i * 2] = _readStringUint(json, string.concat(".IC[", index, "][0]"));
            vk.ic[i * 2 + 1] = _readStringUint(json, string.concat(".IC[", index, "][1]"));
        }
    }

    function _readStringUint(string memory json, string memory key) private pure returns (uint256) {
        return vm.parseUint(json.readString(key));
    }
}
